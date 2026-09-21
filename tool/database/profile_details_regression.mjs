// 2026-09-21: private profile persistence/validation/ownership regression.
// Real local PostgreSQL permissions; not remote Storage HTTP/deployment proof.
import assert from 'node:assert/strict';

export async function profileDetailsRegression({ db, actor, owner, outsider, check, denied }) {
  const read = (id) => actor(id, async () => (await db.query('SELECT public.get_my_profile() AS p')).rows[0].p);
  const save = (id, changes) => actor(id, async () =>
    (await db.query('SELECT public.update_my_profile($1::jsonb) AS p', [JSON.stringify(changes)])).rows[0].p);
  await check('profile legacy NULL fields and Auth email source', async () => {
    const p = await read(owner);
    assert.equal(p.first_name, null);
    assert.equal(p.date_of_birth, null);
    assert.equal(p.email, `${owner}@example.invalid`);
    assert.equal(p.id, owner);
  });
  await check('profile all fields persist and nullable fields clear', async () => {
    const changes = { first_name: 'Synthetic', last_name: 'Profile', phone: '+998901234567',
      date_of_birth: '2000-02-29', gender: 'female', address: 'Synthetic address', occupation: 'Tester', bio: 'Synthetic biography' };
    const p = await save(owner, changes);
    for (const [key, value] of Object.entries(changes)) assert.equal(p[key], value);
    assert.equal(p.full_name, 'Synthetic Profile');
    assert.deepEqual(await read(owner), p);
    const cleared = await save(owner, { bio: null, gender: null, date_of_birth: null });
    assert.equal(cleared.bio, null);
    assert.equal(cleared.gender, null);
    assert.equal(cleared.date_of_birth, null);
  });
  for (const field of ['phone','bio','first_name','last_name','date_of_birth','gender','address','occupation','avatar_path']) {
    await check(`profile private column denied: ${field}`, async () => {
      await denied(outsider, `SELECT ${field} FROM public.profiles WHERE id=$1`, [owner]);
    });
  }
  await check('profile cross-user updates/deletes and forged identity denied', async () => {
    const before = await read(owner);
    await actor(outsider, () => db.query("UPDATE public.profiles SET full_name='Intruder' WHERE id=$1", [owner]));
    await actor(outsider, () => db.query('DELETE FROM public.profiles WHERE id=$1', [owner]));
    assert.deepEqual(await read(owner), before);
    for (const key of ['id','user_id','role','email','is_verified','reputation_points','avatar_url']) {
      await assert.rejects(save(outsider, { [key]: owner }), (e) => e.code === '22023');
    }
  });
  await check('profile invalid calendar/future dates, enums, size and JSON rejected', async () => {
    for (const changes of [{ date_of_birth:'2025-02-29' }, {date_of_birth:'9999-01-01'},
      {date_of_birth:'2000-01-01T00:00:00Z'}, {date_of_birth:'infinity'}, {gender:'unsupported'},
      {bio:'x'.repeat(301)}, {first_name:'x'.repeat(65)}, {occupation:'x'.repeat(129)},
      {address:'x'.repeat(501)}, {phone:'123'}, {bio:42}, [], null]) {
      await assert.rejects(save(owner, changes), (e) => e.code === '22023');
    }
    await denied(owner, "UPDATE public.profiles SET bio=$1 WHERE id=$2", ['x'.repeat(301), owner], '22023');
  });
  const path = `${owner}/00000000-0000-4000-8000-000000000001.png`;
  await check('private avatar own upload/read/reference permitted', async () => {
    await actor(owner, () => db.query('INSERT INTO storage.objects(id,bucket_id,name) VALUES ($1,\'user-avatars\',$2)', [owner,path]));
    assert.equal((await save(owner, {avatar_path:path})).avatar_path, path);
    assert.equal((await actor(owner, () => db.query('SELECT name FROM storage.objects WHERE name=$1', [path]))).rows.length, 1);
  });
  await check('private avatar cross-user read/write/delete and reference denied', async () => {
    assert.equal((await actor(outsider, () => db.query('SELECT name FROM storage.objects WHERE name=$1', [path]))).rows.length, 0);
    await denied(outsider, "INSERT INTO storage.objects(id,bucket_id,name) VALUES ($1,'user-avatars',$2)", [outsider,path]);
    await actor(outsider, () => db.query('DELETE FROM storage.objects WHERE name=$1', [path]));
    assert.equal((await db.query('SELECT name FROM storage.objects WHERE name=$1', [path])).rows.length,1);
    await assert.rejects(save(outsider,{avatar_path:path}), (e)=>e.code==='22023');
    await assert.rejects(save(owner,{avatar_path:`${owner}/00000000-0000-4000-8000-000000000002.png`}), (e)=>e.code==='22023');
    assert.equal((await actor(null, () => db.query('SELECT name FROM storage.objects WHERE name=$1', [path]),'anon')).rows.length,0);
  });
  await check('revoked session cannot read/update profile or avatar', async () => {
    try {
      await db.query('DELETE FROM auth.sessions WHERE user_id=$1',[owner]);
      assert.equal(await read(owner),null);
      await assert.rejects(save(owner,{bio:'blocked'}),(e)=>e.code==='42501');
      assert.equal((await actor(owner,()=>db.query('SELECT name FROM storage.objects WHERE name=$1',[path]))).rows.length,0);
    } finally { await db.query('INSERT INTO auth.sessions(id,user_id) VALUES ($1,$1)',[owner]); }
  });
}
