// Actual local SQL/RLS regression, 2026-09-20; not remote deployment evidence.
// Synthetic fixtures prove the prior profile leak and the repaired boundary.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(resolve(root, 'build/stage1_db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const { vector } = require('@electric-sql/pglite-pgvector');
const { pg_trgm } = require('@electric-sql/pglite/contrib/pg_trgm');
const { uuid_ossp } = require('@electric-sql/pglite/contrib/uuid_ossp');
const { btree_gist } = require('@electric-sql/pglite/contrib/btree_gist');
const db = new PGlite({ extensions: { vector, pg_trgm, uuid_ossp, btree_gist } });
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const migration = 'supabase/migrations/20260920100000_profile_private_column_boundary.sql';
const owner = '20000000-0000-4000-8000-000000000001';
const other = '20000000-0000-4000-8000-000000000002';
const outsider = '20000000-0000-4000-8000-000000000003';
let cases = 0;
async function actor(id, query, params = [], role = 'authenticated') {
  await db.exec('SET SESSION AUTHORIZATION authenticator');
  await db.exec(`SET ROLE ${role}`);
  await db.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [id ?? '']);
  await db.query("SELECT set_config('request.jwt.claim.role', $1, false)", [role]);
  try { return await db.query(query, params); }
  finally { await db.exec('RESET ROLE; SET SESSION AUTHORIZATION postgres; RESET ROLE'); }
}
async function check(name, body) {
  await body(); cases++; console.log(`PASS ${name}`);
}
async function privateDenied(role = 'authenticated') {
  for (const column of ['phone', 'bio', 'license_number']) {
    await assert.rejects(actor(other, `SELECT ${column} FROM public.profiles WHERE id=$1`, [owner], role),
      (error) => error.code === '42501');
  }
}
try {
  await db.exec(read('tool/database/supabase_test_environment.sql'));
  const includes = [...read('supabase/bootstrap/rebuild.sql').matchAll(/^\\ir (.+)$/gm)];
  assert.ok(includes.length >= 37, 'Full historical bootstrap is required');
  for (const [, include] of includes) {
    // Reproduce the pre-fix ACL with the complete historical schema.
    // Later unrelated hardening candidates are validated by their own runners.
    if (include.startsWith('../migrations/2026092')) continue;
    await db.exec(readFileSync(resolve(root, 'supabase/bootstrap', include), 'utf8'));
  }
  for (const id of [owner, other, outsider]) {
    await db.query("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES ($1,$2,'{}')", [id, `${id}@example.invalid`]);
  }
  await db.query("UPDATE public.profiles SET phone='SYNTHETIC-PRIVATE-PHONE',bio='SYNTHETIC-PRIVATE-BIO',license_number='SYNTHETIC-LICENCE' WHERE id=$1", [owner]);
  await check('pre-fix cross-user private profile exposure reproduced', async () => {
    assert.equal((await actor(other, 'SELECT phone FROM public.profiles WHERE id=$1', [owner])).rows[0].phone,
      'SYNTHETIC-PRIVATE-PHONE');
  });
  await db.exec(read(migration));
  await db.exec(read(migration));
  await check('private columns denied to authenticated and guest roles', async () => {
    await privateDenied(); await privateDenied('anon');
  });
  await check('owner RPC is session-bound and denied to guests', async () => {
    const result = (await actor(owner, 'SELECT public.get_my_profile() AS profile')).rows[0].profile;
    assert.equal(result.id, owner); assert.equal(result.phone, 'SYNTHETIC-PRIVATE-PHONE');
    assert.equal((await actor(other, 'SELECT public.get_my_profile() AS profile')).rows[0].profile.id, other);
    assert.equal((await actor(null, 'SELECT public.get_my_profile() AS profile')).rows[0].profile, null);
    await assert.rejects(actor(null, 'SELECT public.get_my_profile()', [], 'anon'), (e) => e.code === '42501');
  });
  await check('owner editable fields and community public profile columns still work', async () => {
    await actor(owner, "UPDATE public.profiles SET phone='SYNTHETIC-UPDATED' WHERE id=$1", [owner]);
    assert.equal((await actor(owner, 'SELECT public.get_my_profile() AS profile')).rows[0].profile.phone, 'SYNTHETIC-UPDATED');
    assert.equal((await actor(other, 'SELECT id,full_name,role,is_verified,avatar_url FROM public.profiles WHERE id=$1', [owner])).rows.length, 1);
    assert.equal((await actor(other, "UPDATE public.profiles SET full_name='forged' WHERE id=$1 RETURNING id", [owner])).rows.length, 0);
  });
  await check('private document ownership rejects read insert reassignment update delete', async () => {
    const id = (await actor(owner, "INSERT INTO public.user_documents(user_id,title,category,generated_text) VALUES ($1,'Synthetic','test','Synthetic') RETURNING id", [owner])).rows[0].id;
    assert.equal((await actor(other, 'SELECT id FROM public.user_documents WHERE id=$1', [id])).rows.length, 0);
    assert.equal((await actor(other, "UPDATE public.user_documents SET title='forged' WHERE id=$1 RETURNING id", [id])).rows.length, 0);
    assert.equal((await actor(other, 'DELETE FROM public.user_documents WHERE id=$1 RETURNING id', [id])).rows.length, 0);
    await assert.rejects(actor(other, "INSERT INTO public.user_documents(user_id,title,category,generated_text) VALUES ($1,'Forged','test','Forged')", [owner]), (e) => e.code === '42501');
    await assert.rejects(actor(owner, 'UPDATE public.user_documents SET user_id=$1 WHERE id=$2', [other,id]), (e) => e.code === '42501');
    assert.equal((await actor(owner, 'SELECT id FROM public.user_documents WHERE id=$1', [id])).rows.length, 1);
    assert.equal((await actor(null, 'SELECT id FROM public.user_documents WHERE id=$1', [id], 'anon')).rows.length, 0);
  });
  await check('private bookmarks and pending expert licence remain owner-only', async () => {
    await actor(owner, "INSERT INTO public.bookmarks(user_id,item_type,item_id,title) VALUES ($1,'law','synthetic','Synthetic')", [owner]);
    await actor(owner, "INSERT INTO public.expert_profiles(user_id,license_number) VALUES ($1,'SYNTHETIC-PRIVATE')", [owner]);
    for (const table of ['bookmarks','expert_profiles']) {
      assert.equal((await actor(owner, `SELECT id FROM public.${table} WHERE user_id=$1`, [owner])).rows.length, 1);
      assert.equal((await actor(other, `SELECT id FROM public.${table} WHERE user_id=$1`, [owner])).rows.length, 0);
    }
  });
  await check('consultation and payment participants isolated from unrelated users', async () => {
    const expert = (await db.query('SELECT id FROM public.expert_profiles WHERE user_id=$1', [owner])).rows[0].id;
    const consultation = (await db.query("INSERT INTO public.consultations(citizen_id,expert_id,scheduled_at,fee) VALUES ($1,$2,now()+interval '7 days',10) RETURNING id", [other,expert])).rows[0].id;
    const payment = (await db.query("INSERT INTO public.payments(consultation_id,citizen_id,expert_id,idempotency_key,amount_tiyin) VALUES ($1,$2,$3,'synthetic-data-isolation',1000) RETURNING id", [consultation,other,expert])).rows[0].id;
    for (const [table,id] of [['consultations',consultation],['payments',payment]]) {
      for (const participant of [owner,other]) {
        assert.equal((await actor(participant, `SELECT id FROM public.${table} WHERE id=$1`, [id])).rows.length, 1);
      }
      assert.equal((await actor(outsider, `SELECT id FROM public.${table} WHERE id=$1`, [id])).rows.length, 0);
      assert.equal((await actor(outsider, `DELETE FROM public.${table} WHERE id=$1 RETURNING id`, [id])).rows.length, 0);
      assert.equal((await actor(other, `UPDATE public.${table} SET citizen_id=$2 WHERE id=$1 RETURNING id`, [id, outsider])).rows.length, 0);
      assert.equal((await actor(null, `SELECT id FROM public.${table} WHERE id=$1`, [id], 'anon')).rows.length, 0);
    }
  });
  await check('notifications cannot be read or modified across accounts', async () => {
    const id = (await db.query("INSERT INTO public.user_notifications(user_id,title,message) VALUES ($1,'Synthetic','Synthetic') RETURNING id", [owner])).rows[0].id;
    assert.equal((await actor(owner, 'SELECT id FROM public.user_notifications WHERE id=$1', [id])).rows.length, 1);
    assert.equal((await actor(other, 'SELECT id FROM public.user_notifications WHERE id=$1', [id])).rows.length, 0);
    assert.equal((await actor(other, 'UPDATE public.user_notifications SET is_read=true WHERE id=$1 RETURNING id', [id])).rows.length, 0);
    assert.equal((await actor(owner, 'UPDATE public.user_notifications SET is_read=true WHERE id=$1 RETURNING id', [id])).rows.length, 1);
  });
  await check('ACL mutation restores the leak and is caught before rollback', async () => {
    await db.exec('GRANT SELECT ON public.profiles TO authenticated');
    await assert.rejects(privateDenied(), { code: 'ERR_ASSERTION' });
    await db.exec(read(migration));
    await privateDenied();
  });
  console.log(`PASS ${cases} data isolation SQL regression groups`);
} catch (error) {
  console.error(`FAIL ${error.code ?? error.name}`);
  process.exitCode = 1;
} finally { await db.close(); }
