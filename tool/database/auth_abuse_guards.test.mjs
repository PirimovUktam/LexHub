// Guards hook quota bypass, identity leaks and exposed hook execution (2026-09-20).
// Runs actual PostgreSQL in local PGlite; NOT hosted Auth activation/HTTP proof.
import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(resolve(root, 'build/stage1_db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
const sql = readFileSync(resolve(root,
  'supabase/migrations/20260921002000_auth_abuse_guards.sql'), 'utf8');
const account = '10000000-0000-4000-8000-000000000001';
const signup = (email = 'synthetic@example.invalid', ip = '192.0.2.1') => ({
  metadata: { ip_address: ip }, user: { email },
});
const password = (valid = false, user = account, ip = '192.0.2.1') => ({
  user_id: user, valid, metadata: { ip_address: ip },
});

async function hook(name, event, role = 'supabase_auth_admin') {
  await db.exec(`SET ROLE ${role}`);
  try {
    return (await db.query(`SELECT auth_guard.${name}($1::jsonb) AS result`,
      [JSON.stringify(event)])).rows[0].result;
  } finally { await db.exec('RESET ROLE'); }
}
const signupHook = (event) => hook('before_user_created', event);
const passwordHook = (event) => hook('password_verification_attempt', event);
function quotaError(response) {
  assert.equal(response.error.http_code, 429);
  assert.match(response.error.message, /Retry after (?:[1-8]?[0-9]{1,2}|900) seconds\./);
  assert.doesNotMatch(JSON.stringify(response), /example\.invalid|192\.0\.2|identity_salt|attempt_windows/);
}

before(async () => {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE ROLE service_role BYPASSRLS; CREATE ROLE supabase_auth_admin;`);
  await db.exec(sql);
});
beforeEach(async () => { await db.exec('TRUNCATE auth_guard.attempt_windows'); });
after(async () => { await db.close(); });

test('migration is idempotent and keeps the server-only identity salt', async () => {
  const first = (await db.query('SELECT salt FROM auth_guard.identity_salt')).rows[0].salt;
  await db.exec(sql);
  assert.equal((await db.query('SELECT salt FROM auth_guard.identity_salt')).rows[0].salt, first);
  assert.equal((await db.query(`SELECT count(*)::int n FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='auth_guard' AND c.relkind='r' AND c.relrowsecurity`)).rows[0].n, 2);
});

test('signup counts normalized identifier across changing IP addresses', async () => {
  for (let n = 1; n <= 3; n++) {
    assert.deepEqual(await signupHook(signup('  Synthetic@Example.Invalid ', `192.0.2.${n}`)), {});
  }
  quotaError(await signupHook(signup('synthetic@example.invalid', '192.0.2.4')));
});

test('signup counts shared IP across distinct account identifiers', async () => {
  for (let n = 0; n < 10; n++) {
    assert.deepEqual(await signupHook(signup(`synthetic-${n}@example.invalid`)), {});
  }
  quotaError(await signupHook(signup('synthetic-eleventh@example.invalid')));
  assert.deepEqual(await signupHook(signup('synthetic-other@example.invalid', '192.0.2.2')), {});
});

test('signup canonicalizes IPv6 addresses to prevent textual IP bypass', async () => {
  for (let n = 0; n < 10; n++) {
    assert.deepEqual(await signupHook(signup(`ipv6-${n}@example.invalid`, '2001:db8::1')), {});
  }
  quotaError(await signupHook(signup('ipv6-over@example.invalid', '2001:0db8:0:0:0:0:0:1')));
});

test('signup ignores user metadata pretending to be trusted request metadata', async () => {
  const event = signup();
  delete event.metadata;
  event.user.user_metadata = { ip_address: '192.0.2.1' };
  assert.equal((await signupHook(event)).error.http_code, 400);
  assert.equal((await db.query('SELECT count(*)::int n FROM auth_guard.attempt_windows')).rows[0].n, 0);
});

test('signup rejects missing, malformed and oversized identity safely', async () => {
  for (const event of [{}, signup('', '192.0.2.1'), signup('a@x\ny.invalid'),
    signup('x'.repeat(321) + '@example.invalid'), signup('valid@example.invalid', 'garbage'),
    signup('valid@example.invalid', null)]) {
    assert.equal((await signupHook(event)).error.http_code, 400);
  }
  assert.equal((await db.query('SELECT count(*)::int n FROM auth_guard.attempt_windows')).rows[0].n, 0);
});

test('quota expires after 15 minutes without extending on rejected requests', async () => {
  for (let n = 0; n < 3; n++) await signupHook(signup());
  const start = (await db.query(`SELECT started_at FROM auth_guard.attempt_windows
    WHERE action='signup' AND scope='identifier'`)).rows[0].started_at;
  quotaError(await signupHook(signup()));
  quotaError(await signupHook(signup()));
  assert.deepEqual((await db.query(`SELECT started_at FROM auth_guard.attempt_windows
    WHERE action='signup' AND scope='identifier'`)).rows[0].started_at, start);
  await db.exec("UPDATE auth_guard.attempt_windows SET started_at=now()-interval '16 minutes'");
  assert.deepEqual(await signupHook(signup()), {});
  assert.equal((await db.query(`SELECT attempts FROM auth_guard.attempt_windows
    WHERE action='signup' AND scope='identifier'`)).rows[0].attempts, 1);
});

test('ten failed password attempts allowed, eleventh receives structured 429', async () => {
  for (let n = 0; n < 10; n++) {
    assert.deepEqual(await passwordHook(password()), { decision: 'continue' });
  }
  quotaError(await passwordHook(password()));
});

test('password identifier quota cannot be bypassed by rotating source IP', async () => {
  for (let n = 1; n <= 10; n++) await passwordHook(password(false, account, `192.0.2.${n}`));
  quotaError(await passwordHook(password(false, account, '192.0.2.11')));
});

test('valid password clears only own failures and never revokes active sessions', async () => {
  for (let n = 0; n < 9; n++) await passwordHook(password());
  assert.deepEqual(await passwordHook(password(true)), { decision: 'continue' });
  assert.equal((await db.query(`SELECT count(*)::int n FROM auth_guard.attempt_windows
    WHERE action='password' AND scope='identifier'`)).rows[0].n, 0);
  assert.equal((await db.query(`SELECT count(*)::int n FROM auth_guard.attempt_windows
    WHERE action='password' AND scope='ip'`)).rows[0].n, 1);
  assert.deepEqual(await passwordHook(password()), { decision: 'continue' });
});

test('correct password cannot bypass the ten-failure cooldown, expiry permits login', async () => {
  for (let n = 0; n < 10; n++) await passwordHook(password());
  quotaError(await passwordHook(password(true)));
  quotaError(await passwordHook(password(true, account, '192.0.2.99')));
  await db.exec("UPDATE auth_guard.attempt_windows SET started_at=now()-interval '16 minutes'");
  assert.deepEqual(await passwordHook(password(true)), { decision: 'continue' });
});

test('password IP quota stops distributed identifier spraying, valid login remains usable', async () => {
  for (let n = 1; n <= 60; n++) {
    const user = `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
    assert.deepEqual(await passwordHook(password(false, user)), { decision: 'continue' });
  }
  quotaError(await passwordHook(password()));
  assert.deepEqual(await passwordHook(password(true)), { decision: 'continue' });
});

test('older password hook without IP metadata still enforces account quota', async () => {
  const event = { user_id: account, valid: false };
  for (let n = 0; n < 10; n++) await passwordHook(event);
  quotaError(await passwordHook(event));
});

test('malformed password hook never accepts forged truthy validity', async () => {
  for (const event of [{}, { user_id: account, valid: 'true' },
    { user_id: 'invalid', valid: false }, { user_id: null, valid: false },
    password(false, account, 'invalid')]) {
    assert.equal((await passwordHook(event)).error.http_code, 400);
  }
});

test('attempts do not retain raw identifiers and expired rows are purged', async () => {
  await signupHook(signup());
  const rows = (await db.query('SELECT * FROM auth_guard.attempt_windows')).rows;
  assert.equal(rows.length, 2);
  for (const row of rows) assert.equal(row.identity_hash.length, 32);
  assert.doesNotMatch(JSON.stringify(rows), /synthetic@example\.invalid|192\.0\.2\.1/);
  await db.exec("UPDATE auth_guard.attempt_windows SET started_at=now()-interval '2 days'");
  await signupHook(signup('new@example.invalid', '192.0.2.2'));
  assert.equal((await db.query('SELECT count(*)::int n FROM auth_guard.attempt_windows')).rows[0].n, 2);
});

test('anonymous/authenticated/service roles cannot execute hooks or read quota identity data', async () => {
  for (const role of ['anon', 'authenticated', 'service_role']) {
    await assert.rejects(hook('before_user_created', signup(), role), e => e.code === '42501');
    await assert.rejects(hook('password_verification_attempt', password(), role), e => e.code === '42501');
    await db.exec(`SET ROLE ${role}`);
    try {
      await assert.rejects(db.query('SELECT * FROM auth_guard.identity_salt'), e => e.code === '42501');
      await assert.rejects(db.query('DELETE FROM auth_guard.attempt_windows'), e => e.code === '42501');
    } finally { await db.exec('RESET ROLE'); }
  }
});

test('auth admin can only invoke hooks, not arbitrary limiter or identity-key helpers', async () => {
  await db.exec('SET ROLE supabase_auth_admin');
  try {
    await assert.rejects(db.query("SELECT auth_guard.identity_key('synthetic')"), e => e.code === '42501');
    await assert.rejects(db.query("SELECT auth_guard.consume_attempt('signup','ip','192.0.2.1',60)"), e => e.code === '42501');
    await assert.rejects(db.query('SELECT * FROM auth_guard.identity_salt'), e => e.code === '42501');
  } finally { await db.exec('RESET ROLE'); }
});

test('staging config enables only Free-tier hook and keeps native abuse controls', () => {
  const config = JSON.parse(readFileSync(resolve(root, 'supabase/auth/staging-abuse-config.json'), 'utf8'));
  assert.equal(config.hook_before_user_created_uri, 'pg-functions://postgres/auth_guard/before_user_created');
  assert.equal(config.hook_before_user_created_enabled, true);
  assert.equal(config.hook_password_verification_attempt_enabled, undefined);
  assert.equal(config.rate_limit_otp, 30);
  assert.equal(config.rate_limit_verify, 30);
  assert.equal(config.rate_limit_token_refresh, 150);
  assert.equal(config.smtp_max_frequency, 60);
  assert.equal(config.refresh_token_rotation_enabled, true);
  assert.equal(config.security_refresh_token_reuse_interval, 10);
  assert.equal(config.security_sb_forwarded_for_enabled, false);
  assert.equal(config.external_anonymous_users_enabled, false);
  assert.equal(config.mailer_autoconfirm, false);
  assert.equal(Object.keys(config).length, 11);
});
