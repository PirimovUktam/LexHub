// Local PostgreSQL runtime regression runner, measured 2026-09-19.
// P1-06/P1-07/P1-09; this is NOT production deployment or GoTrue/PostgREST proof.
// Uses an in-memory PGlite instance: no connection string, network or remote SQL.
// Install test tools into ignored build/stage1_db (see docs/STAGE1_DATABASE.md).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { readRepository } from './validate_stage1_history.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(resolve(root, 'build/stage1_db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const { vector } = require('@electric-sql/pglite-pgvector');
const { pg_trgm } = require('@electric-sql/pglite/contrib/pg_trgm');
const { uuid_ossp } = require('@electric-sql/pglite/contrib/uuid_ossp');
const { btree_gist } = require('@electric-sql/pglite/contrib/btree_gist');
const db = new PGlite({ extensions: { vector, pg_trgm, uuid_ossp, btree_gist } });
const read = (path) => readFileSync(resolve(root, path), 'utf8');

try {
  await db.exec(read('tool/database/supabase_test_environment.sql'));
  const repository = readRepository(root);
  assert.equal(repository.status, 'PASS', JSON.stringify(repository.findings));
  const migrations = repository.migrations;
  const bootstrap = read('supabase/bootstrap/rebuild.sql');
  const includes = [...bootstrap.matchAll(/^\\ir (.+)$/gm)].map((match) => match[1]);
  const guard = bootstrap.slice(0, bootstrap.indexOf('\\ir '))
    .replace(/^\\set ON_ERROR_STOP on\r?\n/gm, '');
  await db.exec(guard);
  for (const include of includes) {
    const path = resolve(root, 'supabase/bootstrap', include);
    try { await db.exec(readFileSync(path, 'utf8')); }
    catch (error) {
      throw new Error(`${include}: ${error.message} [${error.code}] ${error.where ?? ''}`);
    }
  }
  console.log(`PASS clean bootstrap: ${migrations.length} migrations`);
  // Idempotency is measured only for the new additive production candidate.
  const candidate = 'supabase/migrations/20260919001000_stage1_authorization_and_booking.sql';
  await db.exec(read(candidate));
  console.log('PASS additive migration reapplied');

  const ids = Array.from({ length: 7 }, (_, n) =>
    `10000000-0000-4000-8000-${String(n + 1).padStart(12, '0')}`);
  const [owner, author, outsider, staff, applicant, legacy, pending] = ids;
  for (const id of ids) {
    await db.query(`INSERT INTO auth.users(id, email, raw_user_meta_data)
        VALUES ($1, $2, '{"full_name":"Local SQL fixture"}'::jsonb)`,
      [id, `${id}@example.invalid`]);
    await db.query('INSERT INTO auth.sessions(id,user_id) VALUES ($1,$1)', [id]);
  }
  await db.query("UPDATE public.profiles SET role = 'admin' WHERE id = $1", [staff]);
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.profiles')).rows[0].n, 7);
  assert.equal((await db.query(`SELECT count(*)::int AS n FROM pg_tables
    WHERE schemaname = 'public'`)).rows[0].n, 23);
  const category = (await db.query("SELECT id FROM public.categories WHERE slug='labor-law'")).rows[0].id;
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.categories')).rows[0].n, 5);

  async function actor(id, action, role = 'authenticated') {
    await db.exec('SET SESSION AUTHORIZATION authenticator');
    await db.exec(`SET ROLE ${role}`);
    await db.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [id ?? '']);
    await db.query("SELECT set_config('request.jwt.claim.role', $1, false)", [role]);
    await db.query("SELECT set_config('request.jwt.claim.session_id', $1, false)", [id ?? '']);
    const context = (await db.query('SELECT current_user, session_user')).rows[0];
    assert.equal(context.current_user, role);
    assert.equal(context.session_user, 'authenticator');
    try { return await action(); }
    finally {
      // PGlite retains the last explicit session authorization as its reset
      // default; restore the original fixture owner explicitly.
      await db.exec('RESET ROLE; SET SESSION AUTHORIZATION postgres; RESET ROLE');
      await db.exec("SELECT set_config('request.jwt.claim.sub', '', false)");
      await db.exec("SELECT set_config('request.jwt.claim.role', '', false)");
    }
  }
  let cases = 0;
  async function check(name, test) {
    await test();
    cases++;
    console.log(`PASS ${name}`);
  }
  async function denied(id, sql, params = [], code = '42501') {
    await assert.rejects(actor(id, () => db.query(sql, params)),
      (error) => error.code === code, `Expected SQLSTATE ${code}`);
  }
  const question = (await actor(owner, () => db.query(`INSERT INTO public.questions
      (user_id, category_id, title, body, content, description)
      VALUES ($1, $2, 'Local question', 'Local body', 'Local body', 'Local body') RETURNING id`,
    [owner, category]))).rows[0].id;
  const answers = [];
  for (const id of [author, outsider]) {
    answers.push((await actor(id, () => db.query(`INSERT INTO public.answers
      (question_id, user_id, body, content) VALUES ($1, $2, 'Original', 'Original') RETURNING id`,
    [question, id]))).rows[0].id);
  }
  // Emulate the extra permissive INSERT policy observed in live metadata.
  await db.exec(`CREATE POLICY legacy_broad_insert_fixture ON public.answers
    FOR INSERT WITH CHECK (auth.role() = 'authenticated')`);
  await check('question owner cannot rewrite another author answer', async () => {
    await denied(owner, 'UPDATE public.answers SET body = $1 WHERE id = $2', ['Forged', answers[0]]);
    assert.equal((await db.query('SELECT body FROM public.answers WHERE id=$1', [answers[0]])).rows[0].body, 'Original');
  });
  await check('answer author can edit own text', async () => {
    const result = await actor(author, () => db.query(`UPDATE public.answers
      SET body='Edited', content='Edited' WHERE id=$1 RETURNING body`, [answers[0]]));
    assert.equal(result.rows[0].body, 'Edited');
  });
  await check('answer identity and metadata cannot be reassigned', async () => {
    const otherQuestion = (await actor(owner, () => db.query(`INSERT INTO public.questions
      (user_id, category_id, title, body) VALUES ($1,$2,'Second','Second') RETURNING id`,
    [owner, category]))).rows[0].id;
    for (const [column, value] of [['user_id', owner], ['question_id', otherQuestion], ['upvotes_count', 5]]) {
      await denied(author, `UPDATE public.answers SET ${column}=$1 WHERE id=$2`, [value, answers[0]]);
    }
    await denied(owner, 'UPDATE public.answers SET user_id=$1, body=$2 WHERE id=$3', [owner, 'Forged', answers[0]]);
  });
  await check('author cannot self-accept someone else question', async () => {
    await denied(author, 'UPDATE public.answers SET is_accepted=true WHERE id=$1', [answers[0]]);
  });
  await check('question owner accepts/switches answer with counter and status preserved', async () => {
    for (const answer of answers) {
      const result = await actor(owner, () => db.query(`UPDATE public.answers
        SET is_accepted=true WHERE id=$1 RETURNING id`, [answer]));
      assert.equal(result.rows.length, 1);
    }
    const accepted = (await db.query('SELECT id FROM public.answers WHERE question_id=$1 AND is_accepted', [question])).rows;
    assert.deepEqual(accepted.map((row) => row.id), [answers[1]]);
    const q = (await db.query('SELECT status, answers_count FROM public.questions WHERE id=$1', [question])).rows[0];
    assert.equal(q.status, 'answered');
    assert.equal(q.answers_count, 2);
  });
  await check('unrelated user cannot update answer through RLS', async () => {
    const result = await actor(applicant, () => db.query(`UPDATE public.answers
      SET body='Forged' WHERE id=$1 RETURNING id`, [answers[0]]));
    assert.equal(result.rows.length, 0);
  });
  await check('legacy broad INSERT policy cannot impersonate another author', async () => {
    await denied(owner, `INSERT INTO public.answers(question_id,user_id,body)
      VALUES ($1,$2,'Forged')`, [question, author]);
    await denied(author, `INSERT INTO public.answers(question_id,user_id,body,is_accepted)
      VALUES ($1,$2,'Premature',true)`, [question, author]);
  });
  await check('vote counter still updates through trusted trigger', async () => {
    await actor(owner, () => db.query(`INSERT INTO public.votes(user_id,target_type,target_id,vote_value)
      VALUES ($1,'answer',$2,1)`, [owner, answers[0]]));
    assert.equal((await db.query('SELECT upvotes_count FROM public.answers WHERE id=$1', [answers[0]])).rows[0].upvotes_count, 1);
  });
  await check('moderation answer edit remains available', async () => {
    const result = await actor(staff, () => db.query(`UPDATE public.answers
      SET body='Moderated' WHERE id=$1 RETURNING body`, [answers[0]]));
    assert.equal(result.rows[0].body, 'Moderated');
  });
  await check('expert first INSERT rejects verification/rating/rejection spoofing', async () => {
    for (const fragment of ["verified_at) VALUES ($1, now())", "rating, reviews_count) VALUES ($1, 5, 1)",
      "rejected_at) VALUES ($1, now())", "rejection_reason) VALUES ($1, 'Forged')"]) {
      await denied(applicant, `INSERT INTO public.expert_profiles(user_id, ${fragment}`, [applicant]);
    }
    assert.equal((await db.query('SELECT count(*)::int AS n FROM public.expert_profiles WHERE user_id=$1', [applicant])).rows[0].n, 0);
  });
  await check('safe pending direct INSERT remains possible and UPDATE cannot escalate', async () => {
    await actor(pending, () => db.query('INSERT INTO public.expert_profiles(user_id) VALUES ($1)', [pending]));
    await denied(pending, 'UPDATE public.expert_profiles SET verified_at=now() WHERE user_id=$1', [pending]);
    await denied(pending, 'UPDATE public.expert_profiles SET rating=5,reviews_count=1 WHERE user_id=$1', [pending]);
  });
  let expertId;
  await check('existing application and moderator approval RPCs remain usable', async () => {
    const result = await actor(applicant, () => db.query(`SELECT public.apply_for_expert_verification(
      'Local fixture', 2, 'LOCAL-STAGE1', NULL, NULL, NULL, 123456.78) AS result`));
    expertId = result.rows[0].result.expert_id;
    assert.ok(expertId);
    const approval = await actor(staff, () => db.query('SELECT public.verify_expert_application($1, true, NULL) AS result', [applicant]));
    assert.equal(approval.rows[0].result.success, true);
    assert.equal((await db.query('SELECT is_verified FROM public.profiles WHERE id=$1', [applicant])).rows[0].is_verified, true);
  });
  await check('approved licence is immutable through direct UPDATE and reapplication', async () => {
    await denied(applicant, "UPDATE public.expert_profiles SET license_number='FORGED-LICENCE' WHERE user_id=$1", [applicant]);
    await actor(applicant, () => db.query(`SELECT public.apply_for_expert_verification(
      'Local fixture updated', 3, 'FORGED-LICENCE', NULL, NULL, NULL, 123456.78)`));
    const row = (await db.query('SELECT license_number,specialization,verified_at FROM public.expert_profiles WHERE user_id=$1', [applicant])).rows[0];
    assert.equal(row.license_number, 'LOCAL-STAGE1');
    assert.equal(row.specialization, 'Local fixture updated');
    assert.notEqual(row.verified_at, null);
  });
  await check('pending licence remains editable but rejection state cannot bypass cooldown', async () => {
    const edited = await actor(pending, () => db.query(`UPDATE public.expert_profiles
      SET license_number='LOCAL-PENDING' WHERE user_id=$1 RETURNING license_number`, [pending]));
    assert.equal(edited.rows[0].license_number, 'LOCAL-PENDING');
    await actor(staff, () => db.query("SELECT public.verify_expert_application($1,false,'Local review reason')", [pending]));
    const rejected = (await db.query('SELECT rejected_at,rejection_reason FROM public.expert_profiles WHERE user_id=$1', [pending])).rows[0];
    assert.notEqual(rejected.rejected_at, null);
    assert.equal(rejected.rejection_reason, 'Local review reason');
    await denied(pending, 'UPDATE public.expert_profiles SET rejected_at=NULL WHERE user_id=$1', [pending]);
    await denied(pending, 'UPDATE public.expert_profiles SET rejection_reason=NULL WHERE user_id=$1', [pending]);
    await denied(pending, `SELECT public.apply_for_expert_verification(
      'Local fixture', 2, 'LOCAL-PENDING', NULL, NULL, NULL, 1)`, [], 'LX429');
    await denied(pending, 'SELECT public.withdraw_expert_application()', [], 'LX429');
    assert.deepEqual((await db.query('SELECT rejected_at,rejection_reason FROM public.expert_profiles WHERE user_id=$1', [pending])).rows[0], rejected);
  });
  await check('booking rejects legacy verified_at without approved user profile', async () => {
    const fakeId = (await db.query(`INSERT INTO public.expert_profiles(user_id,verified_at,consultation_fee)
      VALUES ($1,now(),10) RETURNING id`, [legacy])).rows[0].id;
    await denied(owner, "SELECT public.book_consultation($1,now()+interval '3 days')", [fakeId], 'P0001');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM public.consultations')).rows[0].n, 0);
  });
  await check('approved booking writes exact fee and payment snapshot', async () => {
    const result = await actor(owner, () => db.query("SELECT public.book_consultation($1,now()+interval '3 days') AS result", [expertId]));
    const booking = result.rows[0].result;
    assert.equal(booking.success, true);
    const stored = (await db.query('SELECT fee,price_amount_tiyin,payment_id FROM public.consultations WHERE id=$1', [booking.consultation_id])).rows[0];
    assert.equal(Number(stored.fee), 123456.78);
    assert.equal(Number(stored.price_amount_tiyin), 12345678);
    assert.equal(stored.payment_id, booking.payment_id);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM public.payments WHERE id=$1', [stored.payment_id])).rows[0].n, 1);
  });
  await check('anon cannot call booking RPC', async () => {
    await assert.rejects(actor(null, () => db.query("SELECT public.book_consultation($1,now()+interval '3 days')", [expertId]), 'anon'),
      (error) => error.code === '42501');
  });
  const legalSql = read('supabase/migrations/20260919002000_reviewed_legal_excerpts_and_deadlines.sql');
  await check('reviewed legal excerpts match the client source and are idempotent', async () => {
    await db.exec(legalSql);
    const rows = (await db.query('SELECT chunk_id,content,lex_url FROM public.law_article_chunks ORDER BY chunk_id')).rows;
    assert.equal(rows.length, 4);
    const client = read('lib/core/legal_safety/uzbek_legal_knowledge_base.dart');
    for (const row of rows) {
      const start = client.indexOf(`chunkId: '${row.chunk_id}'`);
      assert.ok(start >= 0);
      const block = client.slice(start, client.indexOf('\n    ),', start));
      assert.ok(block.includes(`content: "${row.content}"`), `${row.chunk_id} content mismatch`);
      assert.ok(block.includes(`lexUrl: '${row.lex_url}'`), `${row.chunk_id} URL mismatch`);
    }
  });
  const oldLaborText = "Ishga tiklash to'g'risidagi nizolar bo'yicha sudga murojaat qilish muddati xodimga u bilan mehnat shartnomasi bekor qilinganligi haqidagi buyruq nusxasi topshirilgan kundan e'tiboran 1 oyni tashkil etadi.";
  const oldLaborUrl = 'https://lex.uz/docs/6257288#6270500';
  await check('existing old legal excerpt is corrected and stale embedding cleared', async () => {
    await db.query(`UPDATE public.law_article_chunks SET content=$1, lex_url=$2,
        embedding=array_fill(0.0::real,ARRAY[1536])::vector WHERE chunk_id='labor_art_560'`, [oldLaborText, oldLaborUrl]);
    await db.exec(legalSql);
    const row = (await db.query("SELECT content,lex_url,embedding FROM public.law_article_chunks WHERE chunk_id='labor_art_560'")).rows[0];
    assert.ok(row.content.includes('uch oy'));
    assert.ok(row.lex_url.endsWith('#6269139'));
    assert.equal(row.embedding, null);
  });
  await check('unknown content drift aborts instead of overwriting reference edits', async () => {
    const before = (await db.query("SELECT content FROM public.law_article_chunks WHERE chunk_id='labor_art_560'")).rows[0].content;
    await db.query("UPDATE public.law_article_chunks SET content='Unreviewed edit' WHERE chunk_id='labor_art_560'");
    await assert.rejects(db.exec(legalSql), (error) => error.code === 'P0001');
    await db.exec('ROLLBACK');
    assert.equal((await db.query("SELECT content FROM public.law_article_chunks WHERE chunk_id='labor_art_560'")).rows[0].content, 'Unreviewed edit');
    await db.query("UPDATE public.law_article_chunks SET content=$1 WHERE chunk_id='labor_art_560'", [before]);
  });
  await check('NULL service drift aborts and rolls back earlier excerpt updates', async () => {
    const warning = (await db.query("SELECT warning_note FROM public.service_steps WHERE service_id='service_labor_complaint' AND step_number=3")).rows[0].warning_note;
    await db.query("UPDATE public.law_article_chunks SET content=$1,lex_url=$2 WHERE chunk_id='labor_art_560'", [oldLaborText, oldLaborUrl]);
    await db.query("UPDATE public.service_steps SET warning_note=NULL WHERE service_id='service_labor_complaint' AND step_number=3");
    await assert.rejects(db.exec(legalSql), (error) => error.code === 'P0001');
    await db.exec('ROLLBACK');
    assert.equal((await db.query("SELECT content FROM public.law_article_chunks WHERE chunk_id='labor_art_560'")).rows[0].content, oldLaborText);
    await db.query("UPDATE public.service_steps SET warning_note=$1 WHERE service_id='service_labor_complaint' AND step_number=3", [warning]);
    await db.exec(legalSql);
  });
  await check('labour template fixes article 437 reference without losing fields', async () => {
    const row = (await db.query(`SELECT body_template,required_fields,legal_basis,source_url
      FROM public.document_templates WHERE id='template_labor_complaint'`)).rows[0];
    assert.ok(row.legal_basis.includes('161, 560, 561'));
    assert.ok(row.body_template.includes('161, 560 va 561-moddalariga'));
    assert.ok(!row.body_template.includes('437'));
    assert.ok(row.source_url.endsWith('#6269151'));
    for (const field of row.required_fields) {
      assert.ok(row.body_template.includes(`{{${field.id}}}`));
    }
    await db.exec(legalSql);
    assert.equal((await db.query("SELECT body_template FROM public.document_templates WHERE id='template_labor_complaint'")).rows[0].body_template, row.body_template);
  });
  // 2026-09-20: the operational SQL must run read-only and detect broken guards.
  const preflight = read('supabase/verification/stage1_preflight.sql');
  const postflight = read('supabase/verification/stage1_postflight.sql');
  await check('preflight and postflight execute in a read-only transaction', async () => {
    await db.exec('BEGIN READ ONLY');
    try {
      const before = (await db.query(preflight)).rows;
      const after = (await db.query(postflight)).rows;
      assert.equal(before.length, 10);
      assert.equal(after.length, 9);
      assert.deepEqual(before.filter((row) => !row.passed), []);
      assert.deepEqual(after.filter((row) => !row.passed), []);
    } finally { await db.exec('ROLLBACK'); }
  });
  await check('operational checks detect missing column, RLS and disabled guard', async () => {
    await db.exec(`BEGIN;
      ALTER TABLE public.answers RENAME COLUMN user_id TO broken_owner;
      ALTER TABLE public.answers DISABLE ROW LEVEL SECURITY;
      ALTER TABLE public.answers DISABLE TRIGGER trg_00_guard_answer_write;
      UPDATE public.law_article_chunks SET content='Unreviewed fixture edit'
          WHERE chunk_id='labor_art_560';`);
    try {
      const before = (await db.query(preflight)).rows;
      const after = (await db.query(postflight)).rows;
      assert.equal(before.find((row) => row.check_name === 'required_column_types').passed, false);
      assert.equal(before.find((row) => row.check_name === 'private_tables_rls').passed, false);
      assert.equal(after.find((row) => row.check_name === 'insert_update_invoker_guards').passed, false);
      assert.equal(after.find((row) => row.check_name === 'private_tables_rls').passed, false);
      assert.equal(after.find((row) => row.check_name === 'reviewed_legal_excerpts').passed, false);
    } finally { await db.exec('ROLLBACK'); }
  });
  // 2026-09-20: metadata/reference checks must not hide broken step/body text.
  await check('postflight rejects stale deadline text, template body and acceptance trigger', async () => {
    for (const [mutation, checkName] of [
      ["UPDATE public.service_steps SET description='Unreviewed deadline' WHERE service_id='service_labor_complaint' AND step_number=3", 'labour_service_reference'],
      ["UPDATE public.service_steps SET warning_note=NULL WHERE service_id='service_labor_complaint' AND step_number=3", 'labour_service_reference'],
      ["UPDATE public.document_templates SET body_template=replace(body_template,'161, 560 va 561-moddalariga','161, 437 va 560-moddalariga') WHERE id='template_labor_complaint'", 'labour_template_reference'],
      ["UPDATE public.document_templates SET body_template='' WHERE id='template_labor_complaint'", 'labour_template_reference'],
      ['ALTER TABLE public.answers DISABLE TRIGGER trg_handle_answer_acceptance', 'acceptance_trigger'],
      ['DROP TRIGGER trg_handle_answer_acceptance ON public.answers; CREATE TRIGGER trg_handle_answer_acceptance AFTER UPDATE ON public.answers FOR EACH ROW EXECUTE FUNCTION public.handle_answer_acceptance()', 'acceptance_trigger'],
      ['DROP TRIGGER trg_handle_answer_acceptance ON public.answers; CREATE TRIGGER trg_handle_answer_acceptance BEFORE UPDATE ON public.answers FOR EACH ROW EXECUTE FUNCTION public.guard_answer_write()', 'acceptance_trigger'],
    ]) {
      await db.exec('BEGIN');
      try {
        await db.exec(mutation);
        const rows = (await db.query(postflight)).rows;
        assert.equal(rows.find((row) => row.check_name === checkName)?.passed, false, checkName);
        if (checkName === 'acceptance_trigger') {
          const before = (await db.query(preflight)).rows;
          assert.equal(before.find((row) => row.check_name === 'existing_acceptance_trigger').passed, false);
        }
      } finally { await db.exec('ROLLBACK'); }
    }
  });
  console.log(`PASS ${cases} PostgreSQL runtime regression groups (local only)`);
} catch (error) {
  console.error(`FAIL ${error.message}`);
  process.exitCode = 1;
} finally {
  await db.close();
}
