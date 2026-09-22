// 2026-09-22: professional profile ownership, publication and request isolation.
// Executes real PostgreSQL RLS/ACL/RPCs in PGlite; not Storage HTTP/deployment proof.
import assert from 'node:assert/strict';

export async function advocateProfileRegression({ db, actor, check, denied }) {
  const [lawyer, client, outsider, legacy] = Array.from({ length: 4 }, (_, n) =>
    `80000000-0000-4000-8000-${String(n + 1).padStart(12, '0')}`);
  for (const id of [lawyer, client, outsider, legacy]) {
    await db.query(`INSERT INTO auth.users(id,email,raw_user_meta_data)
      VALUES($1,$2,'{"full_name":"Synthetic private account"}')`, [id, `${id}@example.invalid`]);
    await db.query('INSERT INTO auth.sessions(id,user_id) VALUES($1,$1)', [id]);
  }
  const rpc = (id, sql, params = [], role = 'authenticated') =>
    actor(id, async () => (await db.query(sql, params)).rows[0]?.p, role);
  const save = (changes) => rpc(lawyer, 'SELECT public.save_advocate_profile($1) AS p', [changes]);
  let expert;
  let legacyExpert;
  const read = (id = client, role = 'authenticated') =>
    rpc(id, 'SELECT public.get_advocate_profile($1) AS p', [expert], role);
  const insertChild = (table, values) => actor(lawyer, async () => {
    const entries = Object.entries({ expert_id: expert, ...values });
    return (await db.query(`INSERT INTO public.${table}(${entries.map(([k]) => k).join(',')})
      VALUES(${entries.map((_, i) => `$${i + 1}`).join(',')}) RETURNING *`, entries.map(([, v]) => v))).rows[0];
  });
  const sendRequest = (id = client, serviceId = null) => rpc(id,
    'SELECT public.send_advocate_request($1,$2,$3) AS p', [expert, 'Synthetic consultation request', serviceId]);
  const status = (id, request, value) => rpc(id,
    'SELECT public.update_advocate_request_status($1,$2) AS p', [request, value]);
  const message = (id, request, body) => rpc(id,
    'SELECT public.send_advocate_message($1,$2) AS p', [request, body]);

  await check('advocate draft create/save/reload uses real fields and no private account data', async () => {
    assert.equal(await rpc(lawyer, 'SELECT public.get_my_advocate_profile() AS p'), null);
    const p = await save({ first_name: 'Public', last_name: 'Counsel', bio: 'Professional biography',
      workplace: 'Synthetic law office', specializations: ['Employment'], languages: ['Uzbek'],
      experience_years: 4, address: 'Synthetic public office' });
    expert = p.id;
    assert.ok(expert);
    assert.equal(p.is_owner, true);
    assert.equal(p.verified, false);
    assert.equal(p.full_name, 'Public Counsel');
    assert.equal(p.rating, null);
    assert.equal(p.reviews_count, 0);
    assert.equal(p.consultations_count, 0);
    assert.equal(p.experience_years, 4);
    assert.deepEqual(p.specializations, ['Employment']);
    assert.deepEqual(await read(lawyer), p);
    assert.doesNotMatch(JSON.stringify(p), /example\.invalid|Synthetic private account/);
    const updated = await save({ bio: 'Persisted professional biography', languages: ['Uzbek', 'English B2'] });
    assert.equal((await read(lawyer)).bio, updated.bio);
    assert.deepEqual((await read(lawyer)).languages, ['Uzbek', 'English B2']);
  });
  await check('advocate pending/draft stays invisible and cannot self-verify', async () => {
    assert.equal(await read(), null);
    assert.equal(await read(null, 'anon'), null);
    await save({ is_published: true });
    assert.equal(await read(), null);
    for (const key of ['verified', 'verified_at', 'user_id', 'expert_id', 'rating', 'reviews_count', 'license_number']) {
      await assert.rejects(save({ [key]: 'forged' }), (e) => e.code === '22023');
    }
    await denied(lawyer, 'UPDATE public.expert_profiles SET verified_at=now() WHERE id=$1', [expert]);
    await denied(lawyer, 'UPDATE public.advocate_profiles SET is_published=true WHERE expert_id=$1', [expert]);
    assert.equal((await actor(outsider, () => db.query('SELECT * FROM public.advocate_profiles'))).rows.length, 0);
  });
  await db.query("UPDATE public.profiles SET role='verified_expert',is_verified=true WHERE id=$1", [lawyer]);
  await db.query("UPDATE public.expert_profiles SET verified_at=now(),license_number='SYNTHETIC-ADVOCATE' WHERE id=$1", [expert]);
  await check('approved publication and legacy directory remain compatible without private leakage', async () => {
    const p = await read(null, 'anon');
    assert.equal(p.full_name, 'Public Counsel');
    assert.equal(p.is_owner, false);
    assert.equal(p.verified, true);
    assert.equal(p.license_number, 'SYNTHETIC-ADVOCATE');
    await db.query("UPDATE public.profiles SET role='verified_expert',is_verified=true WHERE id=$1", [legacy]);
    legacyExpert = (await db.query("INSERT INTO public.expert_profiles(user_id,verified_at,rating) VALUES($1,now(),NULL) RETURNING id", [legacy])).rows[0].id;
    const old = await rpc(null, 'SELECT public.get_advocate_profile($1) AS p', [legacyExpert], 'anon');
    assert.equal(old.full_name, 'Synthetic private account');
    assert.equal(old.first_name, null);
    assert.equal(old.rating, null);
    assert.equal(await rpc(legacy, 'SELECT public.get_my_advocate_profile() AS p'), null);
    const directory = await rpc(null, 'SELECT public.get_advocate_directory() AS p', [], 'anon');
    assert.ok(directory.some((p) => p.expert_id === legacyExpert));
    const current = directory.find((p) => p.expert_id === expert);
    assert.equal(current.full_name, 'Public Counsel');
    assert.equal(current.specialization, 'Employment');
    assert.equal(current.phone, null);
    assert.equal(current.rating, null);
    assert.equal('eligible_consultation_ids' in current, false);
    assert.equal('services' in current, false);
  });
  await check('legacy published availability supports generic requests without an extension', async () => {
    assert.equal((await db.query('SELECT count(*)::int n FROM public.advocate_profiles WHERE expert_id=$1', [legacyExpert])).rows[0].n, 0);
    assert.equal((await rpc(client, 'SELECT public.get_advocate_profile($1) AS p', [legacyExpert])).accepting_clients, true);
    for (const kind of ['consultation', 'message']) {
      const sent = await rpc(client, 'SELECT public.send_advocate_request($1,$2,NULL,$3) AS p',
        [legacyExpert, 'Synthetic legacy request', kind]);
      assert.equal(sent.expert_id, legacyExpert);
      assert.equal(sent.requester_id, client);
      assert.equal(sent.kind, kind);
      assert.equal(sent.status, 'pending');
      assert.equal(sent.service_id, null);
      assert.equal(sent.service_title, null);
      assert.equal(sent.price_uzs, null);
    }
    try {
      await db.query('UPDATE public.expert_profiles SET is_available_for_booking=false WHERE id=$1', [legacyExpert]);
      assert.equal((await rpc(client, 'SELECT public.get_advocate_profile($1) AS p', [legacyExpert])).accepting_clients, false);
      await assert.rejects(rpc(client, 'SELECT public.send_advocate_request($1,$2) AS p',
        [legacyExpert, 'Unavailable synthetic legacy request']), (e) => e.code === '22023');
    } finally {
      await db.query('UPDATE public.expert_profiles SET is_available_for_booking=true WHERE id=$1', [legacyExpert]);
    }
    assert.equal((await db.query('SELECT count(*)::int n FROM public.advocate_profiles WHERE expert_id=$1', [legacyExpert])).rows[0].n, 0);
  });
  let service;
  await check('advocate services persist CRUD and reject cross-owner reassignment', async () => {
    service = await insertChild('advocate_services', { title: 'Consultation', description: 'Synthetic service',
      price_uzs: 150000, duration_minutes: 30, delivery_mode: 'online' });
    assert.equal((await read()).services[0].id, service.id);
    await actor(lawyer, () => db.query('UPDATE public.advocate_services SET price_uzs=175000 WHERE id=$1', [service.id]));
    assert.equal((await read()).services[0].price_uzs, 175000);
    assert.equal((await actor(outsider, () => db.query('SELECT * FROM public.advocate_services WHERE id=$1', [service.id]))).rows.length, 0);
    assert.equal((await actor(outsider, () => db.query('UPDATE public.advocate_services SET title=$1 WHERE id=$2 RETURNING id', ['Forged', service.id]))).rows.length, 0);
    await denied(outsider, "INSERT INTO public.advocate_services(expert_id,title,delivery_mode) VALUES($1,'Forged','online')", [expert]);
    await denied(lawyer, 'UPDATE public.advocate_services SET id=gen_random_uuid() WHERE id=$1', [service.id]);
    await actor(lawyer, () => db.query('UPDATE public.advocate_services SET is_active=false WHERE id=$1', [service.id]));
    assert.equal((await read()).services.length, 0);
    assert.equal((await read(lawyer)).services.length, 1);
    await actor(lawyer, () => db.query('UPDATE public.advocate_services SET is_active=true WHERE id=$1', [service.id]));
  });
  for (const [table, key, values, field, updated] of [
    ['advocate_experience', 'experience', { organization: 'Synthetic office', position: 'Counsel', start_date: '2020-01-01' }, 'position', 'Senior counsel'],
    ['advocate_education', 'education', { institution: 'Synthetic law school', qualification: 'Law', start_year: 2010, end_year: 2014 }, 'qualification', 'Law degree'],
    ['advocate_working_hours', 'working_hours', { weekday: 1, opens_at: '09:00', closes_at: '18:00' }, 'closes_at', '17:00:00'],
  ]) {
    await check(`${table} create/update/read/delete and ownership`, async () => {
      const item = await insertChild(table, values);
      assert.equal((await read())[key].length, 1);
      await actor(lawyer, () => db.query(`UPDATE public.${table} SET ${field}=$1 WHERE id=$2`, [updated, item.id]));
      assert.equal((await read())[key][0][field], updated);
      assert.equal((await actor(outsider, () => db.query(`DELETE FROM public.${table} WHERE id=$1 RETURNING id`, [item.id]))).rows.length, 0);
      await actor(lawyer, () => db.query(`DELETE FROM public.${table} WHERE id=$1`, [item.id]));
      assert.equal((await read())[key].length, 0);
    });
  }
  await check('advocate server constraints reject malformed profile/services/hours', async () => {
    for (const payload of [null, [], { bio: 3 }, { specializations: [null] }, { languages: [''] },
      { experience_years: -1 }, { experience_years: 1.5 }, { accepting_clients: null }, { verified: true }]) {
      await assert.rejects(save(payload), (e) => e.code === '22023');
    }
    await assert.rejects(save({ bio: 'x'.repeat(3001) }), (e) => e.code === '23514');
    await assert.rejects(save({ public_phone: '123' }), (e) => e.code === '23514');
    await assert.rejects(save({ public_email: 'bad' }), (e) => e.code === '23514');
    await denied(lawyer, 'UPDATE public.advocate_services SET price_uzs=-1 WHERE id=$1', [service.id], '23514');
    await assert.rejects(insertChild('advocate_working_hours', { weekday: 2, opens_at: '18:00', closes_at: '09:00' }), (e) => e.code === '23514');
    const closed = await insertChild('advocate_working_hours', { weekday: 2, is_closed: true });
    assert.equal(closed.opens_at, null);
    await assert.rejects(insertChild('advocate_working_hours', { weekday: 2, is_closed: true }), (e) => e.code === '23505');
  });
  const path = `${lawyer}/00000000-0000-4000-8000-000000000001.pdf`;
  const avatar = `${lawyer}/00000000-0000-4000-8000-000000000002.png`;
  let document;
  await check('advocate private object upload/document reference/explicit publication', async () => {
    for (const [id, name] of [[lawyer, path], [client, avatar]]) {
      await actor(lawyer, () => db.query("INSERT INTO storage.objects(id,bucket_id,name) VALUES($1,'advocate-documents',$2)", [id, name]));
    }
    document = await insertChild('advocate_documents', { title: 'Synthetic certificate', kind: 'certificate', object_path: path });
    assert.equal((await read()).documents.length, 0);
    assert.equal((await read(lawyer)).documents.length, 1);
    assert.equal((await actor(null, () => db.query('SELECT * FROM storage.objects WHERE name=$1', [path]), 'anon')).rows.length, 0);
    await actor(lawyer, () => db.query('UPDATE public.advocate_documents SET is_public=true WHERE id=$1', [document.id]));
    assert.equal((await read()).documents[0].object_path, path);
    assert.equal((await actor(null, () => db.query('SELECT * FROM storage.objects WHERE name=$1', [path]), 'anon')).rows.length, 1);
    await save({ avatar_path: avatar });
    assert.equal((await read()).avatar_path, avatar);
    assert.equal((await actor(null, () => db.query('SELECT * FROM storage.objects WHERE name=$1', [avatar]), 'anon')).rows.length, 1);
    assert.equal((await db.query("SELECT public FROM storage.buckets WHERE id='advocate-documents'")).rows[0].public, false);
  });
  await check('published document read never grants cross-user update/delete/reference', async () => {
    await denied(outsider, "INSERT INTO storage.objects(id,bucket_id,name) VALUES($1,'advocate-documents',$2)", [outsider, path]);
    for (const sql of ['DELETE FROM storage.objects WHERE name=$1 RETURNING name',
      "UPDATE storage.objects SET name=name||'.pdf' WHERE name=$1 RETURNING name"]) {
      assert.equal((await actor(outsider, () => db.query(sql, [path]))).rows.length, 0);
    }
    await assert.rejects(save({ avatar_path: `${outsider}/00000000-0000-4000-8000-000000000002.png` }), (e) => e.code === '22023');
    await assert.rejects(insertChild('advocate_documents', { title: 'Missing', kind: 'license',
      object_path: `${lawyer}/00000000-0000-4000-8000-000000000003.pdf` }), (e) => e.code === '22023');
    assert.equal((await db.query('SELECT * FROM storage.objects WHERE name=$1', [path])).rows.length, 1);
  });
  await check('draft/revoked approval immediately hides published documents and directory', async () => {
    await save({ is_published: false });
    assert.equal(await read(null, 'anon'), null);
    assert.equal((await actor(null, () => db.query('SELECT * FROM storage.objects WHERE name=$1', [path]), 'anon')).rows.length, 0);
    await save({ is_published: true });
    await db.query('UPDATE public.expert_profiles SET rejected_at=now() WHERE id=$1', [expert]);
    assert.equal(await read(null, 'anon'), null);
    assert.equal((await actor(null, () => db.query('SELECT * FROM storage.objects WHERE name=$1', [avatar]), 'anon')).rows.length, 0);
    await db.query('UPDATE public.expert_profiles SET rejected_at=NULL WHERE id=$1', [expert]);
  });
  let request;
  await check('consultation request takes server service snapshot and participant-only data', async () => {
    request = await sendRequest(client, service.id);
    assert.equal(request.status, 'pending');
    assert.equal(request.requester_id, client);
    assert.equal(request.price_uzs, 175000);
    assert.equal(request.service_title, 'Consultation');
    for (const id of [lawyer, client]) {
      assert.equal((await actor(id, () => db.query('SELECT * FROM public.advocate_consultation_requests WHERE id=$1', [request.id]))).rows.length, 1);
    }
    assert.equal((await actor(outsider, () => db.query('SELECT * FROM public.advocate_consultation_requests WHERE id=$1', [request.id]))).rows.length, 0);
    await denied(client, "UPDATE public.advocate_consultation_requests SET status='completed' WHERE id=$1", [request.id]);
    await assert.rejects(sendRequest(lawyer), (e) => e.code === '42501');
    await assert.rejects(rpc(null, 'SELECT public.send_advocate_request($1,$2) AS p', [expert, 'Synthetic'], 'anon'), (e) => e.code === '42501');
    await actor(lawyer, () => db.query('DELETE FROM public.advocate_services WHERE id=$1', [service.id]));
    const stored = (await db.query('SELECT * FROM public.advocate_consultation_requests WHERE id=$1', [request.id])).rows[0];
    assert.equal(stored.service_id, null);
    assert.equal(stored.service_title, 'Consultation');
    assert.equal(Number(stored.price_uzs), 175000);
  });
  await check('messages lock an open request before insertion and validate participant access', async () => {
    const definition = (await db.query(`SELECT pg_get_functiondef(
      'public.send_advocate_message(uuid,text)'::regprocedure) AS source`)).rows[0].source;
    const code = definition.replace(/--[^\n]*/g, '');
    assert.match(code, /PERFORM\s+1\s+FROM\s+public\.advocate_consultation_requests\s+WHERE\s+id\s*=\s*p_request_id\s+AND\s+status\s+IN\s*\('pending',\s*'accepted'\)\s+FOR\s+SHARE\s*;\s*IF\s+NOT\s+FOUND\s+THEN/i,
      'A message must hold the open request row lock through its insert');
    const sent = await message(client, request.id, 'Synthetic message');
    assert.equal(sent.sender_id, client);
    const reply = await message(lawyer, request.id, 'Synthetic reply');
    assert.equal(reply.sender_id, lawyer);
    assert.equal((await actor(client, () => db.query('SELECT * FROM public.advocate_messages WHERE request_id=$1', [request.id]))).rows.length, 2);
    assert.equal((await actor(outsider, () => db.query('SELECT * FROM public.advocate_messages WHERE request_id=$1', [request.id]))).rows.length, 0);
    await assert.rejects(message(outsider, request.id, 'Forbidden'), (e) => e.code === '42501');
    await assert.rejects(message(client, request.id, 'x'.repeat(4001)), (e) => e.code === '22023');
    await denied(client, 'INSERT INTO public.advocate_messages(request_id,sender_id,body) VALUES($1,$2,$3)', [request.id, lawyer, 'Spoof']);
  });
  await check('request lifecycle requires recipient acceptance and client completion', async () => {
    await assert.rejects(status(client, request.id, 'accepted'), (e) => e.code === '22023');
    await assert.rejects(status(outsider, request.id, 'declined'), (e) => e.code === '42501');
    assert.equal((await status(lawyer, request.id, 'accepted')).status, 'accepted');
    await assert.rejects(status(lawyer, request.id, 'completed'), (e) => e.code === '22023');
    assert.equal((await status(client, request.id, 'completed')).status, 'completed');
    await assert.rejects(message(client, request.id, 'Closed'), (e) => e.code === '22023');
    assert.equal((await read()).consultations_count, 0, 'A request is not a completed paid consultation');
  });
  await check('request and message rate limits return PT429 with no extra rows', async () => {
    const second = await sendRequest();
    await sendRequest();
    await assert.rejects(sendRequest(), (e) => e.code === 'PT429');
    for (let n = 0; n < 29; n++) await message(client, second.id, 'Bounded synthetic message');
    await assert.rejects(message(client, second.id, 'Excess'), (e) => e.code === 'PT429');
    assert.equal((await db.query('SELECT count(*)::int n FROM public.advocate_messages WHERE sender_id=$1', [client])).rows[0].n, 30);
  });
  await check('reviews require completed owned consultation and never leak reviewer private identity', async () => {
    const c = (await db.query(`INSERT INTO public.consultations(citizen_id,expert_id,scheduled_at,status,fee)
      VALUES($1,$2,now(),'pending',0) RETURNING id`, [client, expert])).rows[0].id;
    const review = (id, rating = 4) => rpc(id, 'SELECT public.save_advocate_review($1,$2,$3) AS p', [c, rating, 'Synthetic review']);
    await assert.rejects(review(client), (e) => e.code === '42501');
    assert.equal((await actor(client, () => db.query("UPDATE public.consultations SET status='completed' WHERE id=$1 RETURNING id", [c]))).rows.length, 0);
    await db.query("UPDATE public.consultations SET status='completed' WHERE id=$1", [c]);
    assert.deepEqual((await read()).eligible_consultation_ids, [c]);
    await assert.rejects(review(outsider), (e) => e.code === '42501');
    await assert.rejects(review(lawyer), (e) => e.code === '42501');
    await assert.rejects(review(client, 6), (e) => e.code === '22023');
    await review(client);
    const updated = await review(client, 5);
    const p = await read(null, 'anon');
    assert.equal(p.rating, 5);
    assert.equal(p.reviews_count, 1);
    assert.equal(p.consultations_count, 1);
    assert.equal(p.reviews.length, 1);
    assert.equal(p.reviews[0].id, updated.id);
    assert.equal('reviewer_id' in p.reviews[0], false);
    assert.equal('consultation_id' in p.reviews[0], false);
    assert.deepEqual((await read()).eligible_consultation_ids, []);
    assert.equal((await actor(lawyer, () => db.query('SELECT * FROM public.advocate_reviews'))).rows.length, 0);
  });
  await check('revoked sessions cannot read aggregate, mutate, or access documents/conversations', async () => {
    try {
      await db.query('DELETE FROM auth.sessions WHERE user_id=$1', [lawyer]);
      await assert.rejects(read(lawyer), (e) => e.code === '42501');
      await assert.rejects(save({ bio: 'Revoked write' }), (e) => e.code === '42501');
      assert.equal((await actor(lawyer, () => db.query('SELECT * FROM public.advocate_consultation_requests'))).rows.length, 0);
      assert.equal((await actor(lawyer, () => db.query('SELECT * FROM storage.objects WHERE name=$1', [path]))).rows.length, 0);
    } finally { await db.query('INSERT INTO auth.sessions(id,user_id) VALUES($1,$1)', [lawyer]); }
  });
  await check('advocate metadata floor: all 9 tables RLS and session guarded; write RPC anonymous denied', async () => {
    const tables = (await db.query("SELECT relname,relrowsecurity FROM pg_class WHERE relnamespace='public'::regnamespace AND relkind='r' AND relname LIKE 'advocate_%'")).rows;
    assert.equal(tables.length, 9);
    assert.ok(tables.every((t) => t.relrowsecurity));
    assert.equal((await db.query("SELECT count(*)::int n FROM pg_policies WHERE schemaname='public' AND tablename LIKE 'advocate_%' AND policyname='active_session_required' AND permissive='RESTRICTIVE'")).rows[0].n, 9);
    for (const signature of ['save_advocate_profile(jsonb)', 'send_advocate_request(uuid,text,uuid,text)',
      'update_advocate_request_status(uuid,text)', 'send_advocate_message(uuid,text)', 'save_advocate_review(uuid,integer,text)']) {
      assert.equal((await db.query("SELECT has_function_privilege('anon',$1,'EXECUTE') ok", [`public.${signature}`])).rows[0].ok, false);
    }
  });
}
