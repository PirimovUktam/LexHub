// Regression for isolate-local quota bypass and account tampering, 2026-09-20.
// Executes PostgreSQL in local PGlite; not remote deployment or HTTP evidence.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(resolve(root, 'build/stage1_db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
let passed = 0;
const owner = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';
const migration = readFileSync(resolve(root,
  'supabase/migrations/20260921003000_legal_ai_quota.sql'), 'utf8');
async function check(name, test) {
  await test(); passed++; console.log(`PASS ${name}`);
}
async function asUser(id, action, role = 'authenticated') {
  assert(['authenticated', 'anon'].includes(role));
  await db.exec(`SET ROLE ${role}`);
  await db.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [id ?? '']);
  await db.query("SELECT set_config('request.jwt.claim.role', $1, false)", [role]);
  try { return await action(); } finally { await db.exec('RESET ROLE'); }
}
async function consume(id) {
  return (await asUser(id, () => db.query('SELECT public.consume_legal_ai_quota() AS quota'))).rows[0].quota;
}
try {
  await db.exec(readFileSync(resolve(root, 'tool/database/supabase_test_environment.sql'), 'utf8'));
  await db.exec(migration);
  await db.exec(migration);
  await db.query('INSERT INTO auth.users(id) VALUES ($1), ($2)', [owner, other]);
  await check('ten accepted; eleventh rejected with bounded Retry-After', async () => {
    for (let index = 0; index < 10; index++) {
      assert.deepEqual(await consume(owner), { allowed: true, retry_after_seconds: 0, remaining: 9 - index });
    }
    const rejected = await consume(owner);
    assert.equal(rejected.allowed, false);
    assert.equal(rejected.remaining, 0);
    assert(rejected.retry_after_seconds > 0 && rejected.retry_after_seconds <= 3600);
    assert.equal((await consume(owner)).allowed, false);
  });
  await check('another account has independent capacity', async () => {
    assert.deepEqual(await consume(other), { allowed: true, retry_after_seconds: 0, remaining: 9 });
  });
  await check('anonymous caller and missing subject cannot consume', async () => {
    await assert.rejects(asUser(null, () => db.query('SELECT public.consume_legal_ai_quota()'), 'anon'),
      error => error.code === '42501');
    await assert.rejects(consume(null), error => error.code === '42501');
  });
  await check('caller cannot read/reset own or another account counters', async () => {
    for (const sql of [
      'SELECT * FROM legal_ai_private.usage',
      'DELETE FROM legal_ai_private.usage',
      "UPDATE legal_ai_private.usage SET accepted_at='{}'::timestamptz[]",
    ]) {
      await assert.rejects(asUser(other, () => db.exec(sql)), error => error.code === '42501');
    }
    assert.equal((await consume(owner)).allowed, false);
  });
  await check('expired timestamps free capacity; rejecting does not extend lockout', async () => {
    await db.query(`UPDATE legal_ai_private.usage SET accepted_at =
      ARRAY[clock_timestamp() - interval '61 minutes', clock_timestamp() - interval '59 minutes']
      WHERE user_id=$1`, [owner]);
    assert.deepEqual(await consume(owner), { allowed: true, retry_after_seconds: 0, remaining: 8 });
    const row = (await db.query('SELECT cardinality(accepted_at) AS count FROM legal_ai_private.usage WHERE user_id=$1', [owner])).rows[0];
    assert.equal(row.count, 2);
  });
  await check('RPC has no target/limit argument and RLS is enabled', async () => {
    const functions = (await db.query(`SELECT pronargs, prosecdef, proconfig FROM pg_proc
      WHERE proname='consume_legal_ai_quota'`)).rows;
    assert.equal(functions.length, 1);
    assert.equal(functions[0].pronargs, 0);
    assert.equal(functions[0].prosecdef, true);
    assert.deepEqual(functions[0].proconfig, ['search_path=""']);
    assert.equal((await db.query(`SELECT relrowsecurity FROM pg_class
      WHERE oid='legal_ai_private.usage'::regclass`)).rows[0].relrowsecurity, true);
  });
  await check('account cleanup cascades quota metadata', async () => {
    await db.query('DELETE FROM auth.users WHERE id=$1', [owner]);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM legal_ai_private.usage WHERE user_id=$1', [owner])).rows[0].n, 0);
  });
  console.log(`Legal AI quota: ${passed} passed`);
} finally { await db.close(); }
