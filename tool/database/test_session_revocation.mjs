// 2026-09-20: real local RLS/session regressions, not hosted logout/deploy proof.
// The revoked-session mutation must reproduce a leak before its rollback.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
const root = process.cwd();
const require = createRequire(resolve(root, 'build/stage1_db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const { vector } = require('@electric-sql/pglite-pgvector');
const { pg_trgm } = require('@electric-sql/pglite/contrib/pg_trgm');
const { uuid_ossp } = require('@electric-sql/pglite/contrib/uuid_ossp');
const { btree_gist } = require('@electric-sql/pglite/contrib/btree_gist');
const db = new PGlite({ extensions: { vector, pg_trgm, uuid_ossp, btree_gist } });
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const candidate = 'supabase/migrations/20260921004000_immediate_session_revocation.sql';
const a = '30000000-0000-4000-8000-000000000001';
const b = '30000000-0000-4000-8000-000000000002';
const sa = '40000000-0000-4000-8000-000000000001';
const sb = '40000000-0000-4000-8000-000000000002';
let count = 0;
async function check(name, test) { await test(); count++; console.log(`PASS ${name}`); }
async function actor(uid, sid, sql, role = 'authenticated') {
  await db.exec('SET SESSION AUTHORIZATION authenticator');
  await db.exec(`SET ROLE ${role}`);
  await db.query("SELECT set_config('request.jwt.claims',$1,false)", [JSON.stringify({ sub: uid, session_id: sid, role })]);
  try { return await db.query(sql); }
  finally {
    await db.exec('RESET ROLE; SET SESSION AUTHORIZATION postgres; RESET ROLE');
    await db.exec("SELECT set_config('request.jwt.claims','',false)");
  }
}
const active = async (uid, sid) => (await actor(uid, sid, 'SELECT public.is_session_active() AS active')).rows[0].active;
try {
  await db.exec(read('tool/database/supabase_test_environment.sql'));
  for (const [, include] of read('supabase/bootstrap/rebuild.sql').matchAll(/^\\ir (.+)$/gm)) {
    await db.exec(readFileSync(resolve(root, 'supabase/bootstrap', include), 'utf8'));
  }
  await db.exec(read(candidate));
  for (const [id, session] of [[a, sa], [b, sb]]) {
    await db.query("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES ($1,$2,'{}')", [id, `${id}@example.invalid`]);
    await db.query('INSERT INTO auth.sessions(id,user_id) VALUES ($1,$2)', [session, id]);
  }
  const document = (await db.query("INSERT INTO public.user_documents(user_id,title,category,generated_text) VALUES ($1,'Synthetic','test','Synthetic') RETURNING id", [a])).rows[0].id;
  await db.query("INSERT INTO storage.objects(id,bucket_id,name,owner_id) VALUES ($1,'synthetic','fixture',$2)", [sa, a]);
  await db.exec("CREATE POLICY synthetic_owner ON storage.objects TO authenticated USING (owner_id=auth.uid()::text) WITH CHECK (owner_id=auth.uid()::text)");
  await check('33 restrictive policies and pre-request hook cover tables and RPCs', async () => {
    assert.equal((await db.query("SELECT count(*)::int AS n FROM pg_policies WHERE policyname='active_session_required' AND permissive='RESTRICTIVE'")).rows[0].n, 33);
    assert.ok((await db.query("SELECT rolconfig FROM pg_roles WHERE rolname='authenticator'")).rows[0].rolconfig.includes('pgrst.db_pre_request=public.require_active_session'));
  });
  await check('active session reads own profile/document/Storage', async () => {
    assert.equal(await active(a, sa), true);
    await actor(a, sa, 'SELECT public.require_active_session()');
    assert.equal((await actor(a, sa, 'SELECT public.get_my_profile() AS p')).rows[0].p.id, a);
    assert.equal((await actor(a, sa, 'SELECT id FROM public.user_documents')).rows.length, 1);
    assert.equal((await actor(a, sa, 'SELECT id FROM storage.objects')).rows.length, 1);
  });
  await check('wrong-user missing malformed and expired sessions fail closed', async () => {
    for (const sid of [sb, null, 'malformed']) assert.equal(await active(a, sid), false);
    await db.query("UPDATE auth.sessions SET not_after=now()-interval '1 second' WHERE id=$1", [sa]);
    assert.equal(await active(a, sa), false);
    await db.query('UPDATE auth.sessions SET not_after=NULL WHERE id=$1', [sa]);
  });
  await check('account cannot create change or delete native session records', async () => {
    for (const sql of ['SELECT * FROM auth.sessions', `DELETE FROM auth.sessions WHERE id='${sb}'`, `UPDATE auth.sessions SET not_after=NULL WHERE id='${sa}'`]) {
      await assert.rejects(actor(a, sa, sql), (e) => e.code === '42501');
    }
  });
  await db.query('DELETE FROM auth.sessions WHERE id=$1', [sa]);
  await check('same JWT after native session deletion fails pre-request and own RPC', async () => {
    assert.equal(await active(a, sa), false);
    await assert.rejects(actor(a, sa, 'SELECT public.require_active_session()'), (e) => e.code === '42501');
    assert.equal((await actor(a, sa, 'SELECT public.get_my_profile() AS p')).rows[0].p, null);
  });
  const expectHidden = async () => assert.equal((await actor(a, sa, 'SELECT id FROM public.user_documents')).rows.length, 0);
  await check('revoked token cannot read update delete insert owned documents', async () => {
    await expectHidden();
    for (const sql of [`UPDATE public.user_documents SET title='Forged' WHERE id='${document}' RETURNING id`, `DELETE FROM public.user_documents WHERE id='${document}' RETURNING id`]) {
      assert.equal((await actor(a, sa, sql)).rows.length, 0);
    }
    await assert.rejects(actor(a, sa, `INSERT INTO public.user_documents(user_id,title,category,generated_text) VALUES ('${a}','Forged','test','Forged')`), (e) => e.code === '42501');
  });
  await check('revoked token loses private Storage and another account stays active', async () => {
    assert.equal((await actor(a, sa, 'SELECT id FROM storage.objects')).rows.length, 0);
    assert.equal(await active(b, sb), true);
    assert.equal((await actor(b, sb, 'SELECT public.get_my_profile() AS p')).rows[0].p.id, b);
    assert.equal((await actor(b, sb, 'SELECT id FROM public.user_documents')).rows.length, 0);
  });
  await check('service workflows and anonymous public reads still pass pre-request', async () => {
    await actor(null, null, 'SELECT public.require_active_session()', 'service_role');
    await actor(null, null, 'SELECT public.require_active_session()', 'anon');
    assert.equal((await actor(null, null, 'SELECT id FROM public.user_documents', 'service_role')).rows.length, 1);
    assert.equal((await actor(null, null, 'SELECT id FROM public.user_documents', 'anon')).rows.length, 0);
  });
  await check('RLS mutation reproduces the leak and is detected then rolled back', async () => {
    await db.exec('BEGIN; ALTER POLICY active_session_required ON public.user_documents USING (true)');
    try { await assert.rejects(expectHidden(), { code: 'ERR_ASSERTION' }); }
    finally { await db.exec('ROLLBACK'); }
    await expectHidden();
  });
  await check('fresh session works while old session stays rejected', async () => {
    await db.query('INSERT INTO auth.sessions(id,user_id) VALUES ($1,$2)', [a, a]);
    assert.equal(await active(a, a), true);
    assert.equal(await active(a, sa), false);
    assert.equal((await actor(a, a, 'SELECT id FROM public.user_documents')).rows.length, 1);
  });
  console.log(`PASS ${count} session revocation regression groups`);
} catch (error) {
  console.error(`FAIL ${error.code ?? error.name}: ${error.message}`); process.exitCode = 1;
} finally { await db.close(); }
