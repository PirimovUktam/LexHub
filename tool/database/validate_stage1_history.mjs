// Offline metadata validation only; never connects, repairs history or applies SQL.
// Usage: node tool/database/validate_stage1_history.mjs [--history export.json]
// Export contract: { complete: true, row_count: N, migrations: [{ version, name }] }
// A matching export is not live DDL, recovery, authorization or release evidence.
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
export const KNOWN_GAPS = Object.freeze({
  '20260830080000': 'DBA_RECONCILIATION_NO_REPLAY',
  '20260830090000': 'FORWARD_CORRECTION_REQUIRED',
  '20260830100000': 'DEFERRED_DENY_ALL',
  '20260830110000': 'PARTIAL_AND_DEFERRED',
  '20260830120000': 'DBA_RECONCILIATION_NO_REPLAY',
  '20260903000000': 'DBA_RECONCILIATION_NO_REPLAY',
  '20260903001000': 'DBA_RECONCILIATION_DEFAULT_ACL_REVIEW',
});
export const CANDIDATES = Object.freeze(['20260919001000', '20260919002000',
  '20260920100000', '20260921002000', '20260921003000', '20260921004000',
  '20260921120000']);

function validVersion(value) {
  if (typeof value !== 'string' || !/^\d{8}(?:\d{6})?$/.test(value)) return false;
  const timestamp = value.padEnd(14, '0');
  const iso = `${timestamp.slice(0, 4)}-${timestamp.slice(4, 6)}-${timestamp.slice(6, 8)}T${timestamp.slice(8, 10)}:${timestamp.slice(10, 12)}:${timestamp.slice(12, 14)}.000Z`;
  const date = new Date(iso);
  return Number.isFinite(date.getTime()) && date.toISOString() === iso;
}

export function validateRepository(filenames, bootstrap) {
  const findings = [];
  const migrations = [];
  const seen = new Set();
  for (const file of filenames) {
    const match = /^(\d{8}(?:\d{6})?)_([a-z][a-z0-9_]*)\.sql$/.exec(file);
    if (!match || !validVersion(match[1])) {
      findings.push({ category: 'INVALID_REPOSITORY_FILENAME' });
      continue;
    }
    const [, version, name] = match;
    if (seen.has(version)) findings.push({ version, category: 'DUPLICATE_REPOSITORY_VERSION' });
    seen.add(version);
    migrations.push({ version, name, file });
  }
  migrations.sort((a, b) => a.file.localeCompare(b.file));
  // 34 historical migrations plus 7 candidates, including private profile details.
  // A truncated checkout
  // must not silently become a new baseline. New versions require review too.
  if (migrations.length !== 41 || [...Object.keys(KNOWN_GAPS), ...CANDIDATES]
    .some((version) => !seen.has(version))) {
    findings.push({ category: 'STAGE1_BASELINE_MISMATCH' });
  }
  const includes = [...bootstrap.matchAll(/^\s*\\ir\s+([^\r\n]+)\r?$/gm)]
    .map((match) => match[1].trim());
  const commands = bootstrap.split(/\r?\n/).map((line) => line.trim())
    .filter((line) => line.startsWith('\\'));
  if (commands[0] !== '\\set ON_ERROR_STOP on'
    || commands.filter((line) => line === '\\set ON_ERROR_STOP on').length !== 1
    || commands.slice(1).some((line) => !/^\\ir\s+[^\r\n]+$/.test(line))) {
    findings.push({ category: 'BOOTSTRAP_COMMAND_MISMATCH' });
  }
  const expected = migrations.map(({ file }) => `../migrations/${file}`);
  expected.splice(1, 0, 'replay_prerequisites.sql');
  if (JSON.stringify(includes) !== JSON.stringify(expected)) {
    findings.push({ category: 'BOOTSTRAP_INCLUDE_ORDER_MISMATCH' });
  }
  return { status: findings.length ? 'BLOCKED' : 'PASS', migrations, findings };
}

export function validateHistory(repository, exported) {
  const findings = [...repository.findings];
  if (repository.status !== 'PASS') return { status: 'BLOCKED', productionReady: false, findings };
  // Explicit completeness plus exact count prevents accepting a paginated/empty
  // result accidentally. Completeness itself remains the exporter responsibility.
  if (!exported || exported.complete !== true || !Array.isArray(exported.migrations)
    || !Number.isSafeInteger(exported.row_count)
    || exported.row_count !== exported.migrations.length || exported.row_count === 0) {
    return { status: 'BLOCKED', productionReady: false, findings: [{ category: 'INCOMPLETE_HISTORY_EXPORT' }] };
  }
  const byVersion = new Map(repository.migrations.map((item) => [item.version, item]));
  const live = new Set();
  for (const row of exported.migrations) {
    if (!row || !validVersion(row.version) || typeof row.name !== 'string') {
      findings.push({ category: 'INVALID_HISTORY_ROW' });
      continue;
    }
    if (live.has(row.version)) findings.push({ version: row.version, category: 'DUPLICATE_HISTORY_VERSION' });
    live.add(row.version);
    const expected = byVersion.get(row.version);
    if (!expected) findings.push({ version: row.version, category: 'UNKNOWN_HISTORY_VERSION' });
    else if (row.name !== expected.name) findings.push({ version: row.version, category: 'HISTORY_NAME_MISMATCH' });
  }
  for (const { version } of repository.migrations) {
    if (!live.has(version)) findings.push({ version, category: CANDIDATES.includes(version)
      ? 'PENDING_CANDIDATE' : KNOWN_GAPS[version] ?? 'UNEXPECTED_HISTORY_GAP' });
  }
  if (live.has(CANDIDATES[1]) && !live.has(CANDIDATES[0])) {
    findings.push({ version: CANDIDATES[1], category: 'CANDIDATE_ORDER_VIOLATION' });
  }
  // Even MATCHED_METADATA_ONLY cannot authorize replay, repair or production.
  return { status: findings.length ? 'BLOCKED' : 'MATCHED_METADATA_ONLY', productionReady: false, findings };
}

export function readRepository(repositoryRoot = root) {
  return validateRepository(
    readdirSync(resolve(repositoryRoot, 'supabase/migrations')).filter((name) => name.endsWith('.sql')),
    readFileSync(resolve(repositoryRoot, 'supabase/bootstrap/rebuild.sql'), 'utf8'),
  );
}

function main(args) {
  if (args.length !== 0 && (args.length !== 2 || args[0] !== '--history')) {
    console.log(JSON.stringify({ status: 'BLOCKED', category: 'INVALID_ARGUMENTS' }));
    return 1;
  }
  try {
    const repository = readRepository();
    const history = args.length
      ? validateHistory(repository, JSON.parse(readFileSync(resolve(args[1]), 'utf8')))
      : { status: 'NOT_PROVIDED', productionReady: false, findings: [] };
    console.log(JSON.stringify({ repository: repository.status,
      repositoryCount: repository.migrations.length, repositoryFindings: repository.findings, history }, null, 2));
    return repository.status === 'PASS' && history.status === 'MATCHED_METADATA_ONLY' ? 0 : 1;
  } catch {
    // Never echo input, raw SQL, paths, connection strings or parser messages.
    console.log(JSON.stringify({ status: 'BLOCKED', category: 'UNREADABLE_OR_INVALID_INPUT' }));
    return 1;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
