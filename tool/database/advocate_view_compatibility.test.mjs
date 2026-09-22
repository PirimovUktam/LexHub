// 2026-09-22: guards 42P16 on existing TEXT/VARCHAR professional view contracts.
// Isolated PostgreSQL execution, not hosted deployment proof. Fixture type drift
// is applied only to in-memory bootstrap source; repository SQL is never edited.
import assert from 'node:assert/strict';
import test from 'node:test';
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
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const candidateFile = '20260922190000_universal_advocate_profiles.sql';
const view = 'public.public_expert_profiles_view';
const ownerId = '90000000-0000-4000-8000-000000000001';

async function columns(db) {
  return (await db.query(`SELECT attname AS name,
    format_type(atttypid,atttypmod) AS type
    FROM pg_attribute WHERE attrelid=$1::regclass AND attnum>0 AND NOT attisdropped
    ORDER BY attnum`, [view])).rows;
}

async function relation(db, name) {
  return (await db.query(`SELECT oid,relowner,relacl::text AS acl
    FROM pg_class WHERE oid=$1::regclass`, [name])).rows[0];
}

for (const [nameType, phoneType] of [
  ['text', 'text'],
  ['character varying(128)', 'character varying(32)'],
  ['text', 'character varying(32)'],
  ['character varying(128)', 'text'],
]) {
  test(`advocate migration preserves full_name=${nameType} phone=${phoneType}, grants and dependencies`, async () => {
    const db = new PGlite({ extensions: { vector, pg_trgm, uuid_ossp, btree_gist } });
    try {
      await db.exec(read('tool/database/supabase_test_environment.sql'));
      const includes = [...read('supabase/bootstrap/rebuild.sql').matchAll(/^\\ir (.+)$/gm)]
        .map((match) => match[1]);
      assert.equal(includes.filter((path) => path.endsWith(candidateFile)).length, 1);
      assert.ok(includes.at(-1).endsWith(candidateFile), 'Compatibility candidate must remain last');
      for (const include of includes.slice(0, -1)) {
        let sql = readFileSync(resolve(root, 'supabase/bootstrap', include), 'utf8');
        if (include.endsWith('20260819_base_schema.sql')) {
          if (nameType === 'text') {
            assert.equal([...sql.matchAll(/full_name VARCHAR\(128\)/g)].length, 2,
              'The drift fixture must affect the intended create/add declarations only');
            sql = sql.replaceAll('full_name VARCHAR(128)', 'full_name TEXT');
          }
          if (phoneType === 'text') {
            assert.equal([...sql.matchAll(/phone VARCHAR\(32\)/g)].length, 2,
              'The phone drift fixture must affect the intended create/add declarations only');
            sql = sql.replaceAll('phone VARCHAR(32)', 'phone TEXT');
          }
        }
        await db.exec(sql);
      }
      const previousColumns = await columns(db);
      assert.equal(previousColumns.length, 19);
      assert.equal(previousColumns.find((column) => column.name === 'full_name').type, nameType);
      assert.equal(previousColumns.find((column) => column.name === 'phone').type, phoneType);
      await db.exec(`CREATE ROLE advocate_view_reader;
        GRANT SELECT ON ${view} TO advocate_view_reader;
        CREATE VIEW public.advocate_view_consumer AS
          SELECT expert_id,full_name FROM ${view};
        GRANT SELECT ON public.advocate_view_consumer TO advocate_view_reader;
        CREATE FUNCTION public.advocate_view_consumer_fn()
          RETURNS SETOF ${view} LANGUAGE sql STABLE
          AS $$ SELECT * FROM ${view} $$;
        GRANT EXECUTE ON FUNCTION public.advocate_view_consumer_fn() TO advocate_view_reader;`);
      await db.query(`INSERT INTO auth.users(id,email,raw_user_meta_data)
        VALUES($1,'synthetic@example.invalid','{"full_name":"Synthetic Compatibility"}')`, [ownerId]);
      await db.query("UPDATE public.profiles SET role='verified_expert',is_verified=true WHERE id=$1", [ownerId]);
      await db.query(`INSERT INTO public.expert_profiles(user_id,verified_at,rating)
        VALUES($1,now(),NULL)`, [ownerId]);
      const before = await relation(db, view);
      const consumerBefore = await relation(db, 'public.advocate_view_consumer');
      const functionBefore = (await db.query(`SELECT oid,proowner,proacl::text AS acl
        FROM pg_proc WHERE oid='public.advocate_view_consumer_fn()'::regprocedure`)).rows[0];

      for (const applyPass of [1, 2]) {
        try {
          await db.exec(read(`supabase/migrations/${candidateFile}`));
        } catch (error) {
          // Report only SQLSTATE/message; never dump SQL/session payloads.
          throw new Error(`Compatibility apply ${applyPass} failed [${error.code}]: ${error.message}`);
        }

        const afterColumns = await columns(db);
        assert.equal(afterColumns.length, 22);
        assert.deepEqual(afterColumns.slice(0, 19), previousColumns);
        assert.deepEqual(afterColumns.slice(19).map((column) => column.name),
          ['avatar_path', 'specializations', 'consultations_count']);
        assert.deepEqual(await relation(db, view), before,
          'CREATE OR REPLACE must preserve view OID, owner and ACL');
        assert.deepEqual(await relation(db, 'public.advocate_view_consumer'), consumerBefore);
        assert.deepEqual((await db.query(`SELECT oid,proowner,proacl::text AS acl
          FROM pg_proc WHERE oid='public.advocate_view_consumer_fn()'::regprocedure`)).rows[0], functionBefore);
        assert.equal((await db.query(`SELECT full_name FROM public.advocate_view_consumer`)).rows[0].full_name,
          'Synthetic Compatibility');
        assert.equal((await db.query(`SELECT full_name FROM public.advocate_view_consumer_fn()`)).rows[0].full_name,
          'Synthetic Compatibility');
        assert.equal((await db.query(`SELECT has_table_privilege('advocate_view_reader',$1,'SELECT') AS ok`, [view])).rows[0].ok, true);
      }
    } finally {
      await db.close();
    }
  });
}
