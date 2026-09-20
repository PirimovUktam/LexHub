// Guards unsafe Stage 1 history classification and empty/bootstrap-drift passes.
// Measured 2026-09-20. Synthetic offline metadata; NOT live DDL/deployment proof.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { CANDIDATES, KNOWN_GAPS, readRepository, validateRepository, validateHistory } from './validate_stage1_history.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const repository = readRepository(root);
const files = repository.migrations.map(({ file }) => file);
const bootstrap = readFileSync(resolve(root, 'supabase/bootstrap/rebuild.sql'), 'utf8');
const all = repository.migrations.map(({ version, name }) => ({ version, name }));
const envelope = (migrations) => ({ complete: true, row_count: migrations.length, migrations });
const categories = (result) => result.findings.map(({ category }) => category);

test('actual Stage 1 bootstrap has 40 migrations and prerequisites immediately after base', () => {
  assert.equal(repository.status, 'PASS');
  assert.equal(repository.migrations.length, 40);
  assert.equal(Object.keys(KNOWN_GAPS).length, 7);
  assert.deepEqual(CANDIDATES, ['20260919001000', '20260919002000',
    '20260920100000', '20260921002000', '20260921003000', '20260921004000']);
});

test('synthetic historical 27 classify seven gaps and six candidates, never ready', () => {
  const rows = all.filter(({ version }) => !KNOWN_GAPS[version] && !CANDIDATES.includes(version));
  assert.equal(rows.length, 27);
  const result = validateHistory(repository, envelope(rows));
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.productionReady, false);
  assert.equal(result.findings.length, 13);
  assert.deepEqual(Object.fromEntries(result.findings.map(({ version, category }) => [version, category])), {
    ...KNOWN_GAPS, ...Object.fromEntries(CANDIDATES.map((version) => [version, 'PENDING_CANDIDATE'])),
  });
  assert.equal(result.findings.find(({ version }) => version === '20260830090000').category, 'FORWARD_CORRECTION_REQUIRED');
});

test('matching metadata is not DDL or release readiness and never gives apply advice', () => {
  const result = validateHistory(repository, envelope(all));
  assert.equal(result.status, 'MATCHED_METADATA_ONLY');
  assert.equal(result.productionReady, false);
  assert.deepEqual(result.findings, []);
  assert.doesNotMatch(JSON.stringify(result), /db push|migration repair|READY/);
});

test('incomplete, paginated and empty metadata fail closed', () => {
  for (const value of [undefined, null, [], envelope([]), { migrations: all },
    { ...envelope(all), complete: false }, { ...envelope(all), row_count: 35 },
    { ...envelope(all), row_count: '36' }]) {
    const result = validateHistory(repository, value);
    assert.equal(result.status, 'BLOCKED');
    assert.deepEqual(categories(result), ['INCOMPLETE_HISTORY_EXPORT']);
  }
  const truncated = validateHistory(repository, envelope(all.slice(1)));
  assert.ok(categories(truncated).includes('UNEXPECTED_HISTORY_GAP'));
});

test('unknown live version, duplicate and mismatching names fail closed', () => {
  for (const [rows, expected] of [
    [[...all, { version: '20260920000100', name: 'synthetic_future_change' }], 'UNKNOWN_HISTORY_VERSION'],
    [[...all, all[0]], 'DUPLICATE_HISTORY_VERSION'],
    [[{ ...all[0], name: 'synthetic_wrong_name' }, ...all.slice(1)], 'HISTORY_NAME_MISMATCH'],
  ]) {
    const result = validateHistory(repository, envelope(rows));
    assert.equal(result.status, 'BLOCKED');
    assert.ok(categories(result).includes(expected));
  }
});

test('invalid history row values are never reflected into diagnostics', () => {
  const marker = 'synthetic-sensitive-value-not-a-real-credential';
  for (const row of [null, { version: marker, name: marker }, { version: 20260819, name: marker },
    { version: '20269919999999', name: marker }, { version: '20260931000000', name: marker },
    { version: all[0].version, name: marker }, { version: all[0].version, name: { marker } }]) {
    const result = validateHistory(repository, envelope([...all, row]));
    assert.equal(result.status, 'BLOCKED');
    assert.ok(result.findings.length > 0);
    assert.ok(!JSON.stringify(result).includes(marker));
  }
});

test('second candidate without first candidate is not an acceptable history order', () => {
  const result = validateHistory(repository, envelope(all.filter(({ version }) => version !== CANDIDATES[0])));
  assert.equal(result.status, 'BLOCKED');
  assert.ok(categories(result).includes('CANDIDATE_ORDER_VIOLATION'));
});

test('missing, duplicate, reordered and unexpected bootstrap includes are rejected', () => {
  const first = `\\ir ../migrations/${files[0]}`;
  const second = `\\ir ../migrations/${files[1]}`;
  for (const value of ['', bootstrap.replace(first, ''), bootstrap.replace('\\ir replay_prerequisites.sql', ''),
    bootstrap.replace('\\ir replay_prerequisites.sql', '') + '\n\\ir replay_prerequisites.sql\n',
    bootstrap.replace(first, '\\ir SWAP').replace(second, first).replace('\\ir SWAP', second),
    `${bootstrap}\n${first}\n`, `${bootstrap}\n\\ir ../unreviewed.sql\n`]) {
    const result = validateRepository(files, value);
    assert.equal(result.status, 'BLOCKED');
    assert.ok(categories(result).includes('BOOTSTRAP_INCLUDE_ORDER_MISMATCH'));
  }
});

test('alternate include commands and disabled error stopping cannot bypass bootstrap validation', () => {
  for (const value of [`${bootstrap}\n\\i ../unreviewed.sql\n`,
    bootstrap.replace('\\set ON_ERROR_STOP on', '\\set ON_ERROR_STOP off'),
    `${bootstrap}\n\\set ON_ERROR_STOP off\n`, `${bootstrap}\n\\! synthetic-command\n`]) {
    const result = validateRepository(files, value);
    assert.equal(result.status, 'BLOCKED');
    assert.ok(categories(result).includes('BOOTSTRAP_COMMAND_MISMATCH'));
  }
});

test('empty/truncated/expanded/duplicate or malformed repository baseline cannot pass', () => {
  for (const list of [[], files.slice(1), [...files, '20260920000100_synthetic_future_change.sql'],
    [...files, `${all[0].version}_synthetic_duplicate.sql`], [...files, 'invalid.sql'],
    files.map((file) => file === files[0] ? '20260931000000_invalid_date.sql' : file)]) {
    const result = validateRepository(list, bootstrap);
    assert.equal(result.status, 'BLOCKED');
    assert.equal(validateHistory(result, envelope(all)).status, 'BLOCKED');
  }
});

test('CLI fails on missing or malformed export without printing file contents', () => {
  const temp = mkdtempSync(join(tmpdir(), 'lexhub-history-'));
  const cli = resolve(root, 'tool/database/validate_stage1_history.mjs');
  try {
    const marker = 'synthetic-private-input-do-not-echo';
    const path = join(temp, 'metadata.json');
    writeFileSync(path, marker);
    for (const args of [[], ['--history', path], ['--apply', path], ['--history', join(temp, 'missing.json')]]) {
      const result = spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8' });
      assert.equal(result.status, 1);
      assert.ok(!result.stdout.includes(marker));
      assert.equal(result.stderr, '');
      assert.doesNotThrow(() => JSON.parse(result.stdout));
    }
    writeFileSync(path, JSON.stringify(envelope(all)));
    const result = spawnSync(process.execPath, [cli, '--history', path], { encoding: 'utf8' });
    assert.equal(result.status, 0);
    assert.equal(JSON.parse(result.stdout).history.status, 'MATCHED_METADATA_ONLY');
    assert.equal(JSON.parse(result.stdout).history.productionReady, false);
  } finally { rmSync(temp, { recursive: true, force: true }); }
});
