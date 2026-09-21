# Database bootstrap va migration validation

Bu repositorydagi SQL manbalari va lokal sinovlar uchun runbook.
Cloud project identity, migration approval, credential/recovery dalillari va
operator jurnali public repositoryda saqlanmaydi. Fayl mavjudligi yoki lokal
PASS productionga migration qo'llanganini anglatmaydi.

## Bo'sh lokal database

`supabase/bootstrap/rebuild.sql` yagona psql kirish nuqtasi: faqat bo'sh,
loopback/mahalliy Supabase database uchun. `replay_prerequisites.sql` tarixiy
migratsiyalarning clean replay talablari orasidagi ko'prikni beradi.
`supabase/schema.sql` tarixiy ma'lumotnoma; deployment entrypoint emas.

Lokal Supabase rollari, Auth/Storage schema, default grantlar va `vector`,
`uuid-ossp`, `pg_trgm`, `btree_gist` extensionlari talab qilinadi.
Bootstrap mavjud/cloud bazaga ishlatilmaydi; guardlar olib tashlanmaydi.
Oddiy `supabase db reset` bootstrap ko'prigini avtomatik bajarmaydi.

Docker talab qilmaydigan synthetic SQL regressiyalari:

```sh
npm install --prefix build/stage1_db --no-save --ignore-scripts @electric-sql/pglite@0.5.8 @electric-sql/pglite-pgvector@0.0.9
node tool/database/verify_stage1_db.mjs
node --test tool/database/validate_stage1_history.test.mjs
python tool/validate_sql_syntax.py
```

Runner in-memory PGlite yaratadi; remote connection string olmaydi.
Auth rollari/grantlari fixture bilan beriladi. RLS ownership, moderation,
booking, legal-content drift, private profile/avatar va revoked session
regressiyalari haqiqiy lokal PostgreSQL'da bajariladi. Bu GoTrue, PostgREST,
SMTP, cloud Storage, production concurrency yoki recovery testi emas.

## History va DDL qarori

`tool/database/validate_stage1_history.mjs` repository version/filename,
bootstrap tartibi va history mappingni tekshiradi. Remote history snapshotini
operator alohida READ-ONLY oladi va live DDL, policy, trigger, grant bilan
solishtiradi. History yozuvi yo'qligi SQL effektlari yo'q degani emas.

Quyidagi eski compatibility qarorlari saqlanadi; jadval bugungi live holat
degani emas. Operator har bir qarorni yangi dalil bilan tasdiqlaydi.

| Version | Avtomatik replay | Kerakli qaror |
|---|---|---|
| `20260830080000` | Yo'q | Question anonymity/RLS effektlari mos bo'lsa history-only reconciliation |
| `20260830090000` | Yo'q | Template/FK, sana placeholderlari va freshness metadata uchun content review va forward correction |
| `20260830100000` | Yo'q | Deny-all jadval policy'larini ochish accessni kengaytiradi; deferred qismlar alohida tasdiqlanadi |
| `20260830110000` | Yo'q | Mavjud owner policy va deferred UPDATE/INSERT qismlarini ajratish |
| `20260830120000` | Yo'q | Owner write policy definitionlari mosligini tekshirish; kerak bo'lsa history-only reconciliation |
| `20260903000000` | Yo'q | Profile visibility helper, owner/search_path va grantlarni solishtirish |
| `20260903001000` | Yo'q | Anon write revoke va har bir object-owner default ACL'ni solishtirish |

`20260830090000`ni ko'r-ko'rona replay qilish katalog matni va review sanasini
almashtirishi mumkin. Missing template'lar, required-fields/body mosligi va
freshness dalili content owner bilan tekshiriladi. Reviewed forward correction
old/new-state guard, transaction va idempotence bilan alohida version bo'ladi;
unknown drift rad etiladi. Barcha eski versionlarni birdan applied deb belgilash
yoki `db push --include-all` ishlatish mumkin emas.

## Staging va production chegarasi

Candidate-oldi baseline uchun tartib `20260919001000` -> `20260919002000`.
Allaqachon yangilangan targetga bu ikki faylni avtomatik qayta yubormang.
Keyingi migrationlar repository history va target DDL asosida review qilinadi.
`supabase/verification/stage1_preflight.sql` va `stage1_postflight.sql`
verification uchun; har bir `passed` qiymatini tekshirish kerak; psql exit
code 0 bo'lishi barcha assertion o'tdi degani emas.

Production apply uchun alohida ruxsat, staging acceptance, mos history/DDL,
backup/retention va restore-point dalili talab qilinadi. Recovery rehearsal
izolyatsiyalangan targetda bajarilib, RPO/RTO o'lchanadi. Productionda restore
sinovi, eski cleanup migration replay yoki foydalanuvchi ma'lumotini seed qilish
avtomatlashtirilmaydi. Frontend rollback database o'zgarishini qaytarmaydi.

[Staging](STAGING.md) | [Testlar](TESTING.md)
