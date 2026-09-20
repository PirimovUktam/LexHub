# Stage 1 — credential va recovery preflight, 2026-09-20

> Fingerprint yechimi bekor qilindi: real credentialga tegishli hash ham
> repositoryda saqlanmaydi. Quyidagi audit/test raqamlari oldingi snapshot;
> joriy tuzatish va tekshiruvlar hujjat oxiridagi "Fingerprint exposure fix"da.
> Eng yangi account dalillari va admin checklist quyidagi "Rotation preflight
> aniqlashtirishi" bo'limida. Avvalgi HEAD/tree/test raqamlari tarixiy snapshot;
> joriy boshlang'ich HEAD `909870f`, literal/fingerprint fix commitga kiritilgan.

**Umumiy holat: PARTIALLY VERIFIED. Production migration gate: BLOCKED.**
Branch: `audit/stage1-production-preflight`.
Boshlang'ich HEAD: `619534e36bbc5bb3e208aee09839dfc9a46bb843`.
Oldingi Stage 1 o'zgarishlari saqlandi; repository qayta boshlanmadi.

Production DB uchun faqat SELECT, Supabase/Vercel uchun faqat read-only
metadata so'rovlari ishlatildi. Backup yaratish, restore/clone, migration,
deploy, setting o'zgartirish, credential rotation, commit/push va history
rewrite bajarilmadi.

## 1. CREDENTIAL AUDIT

### Oldingi 16 topilma

2 521 reachable Git object ichidagi 1 097 matn blob qayta tekshirildi.
Ma'lum tarixiy test paroli **CRED-H01** deb nomlandi: bir xil qiymat 33 blob
versiyasida topilgan. So'ralgan 16 commit/fayl snapshotining barchasi tekshirildi;
ularda jami 18 literal occurrence bor. Bu 16 yoki 33 alohida secret/account emas.

- 14 faylda parol haqiqiy signup/login API chaqiruviga uzatilgan. Haqiqiy
  test-account credential bo'lish ehtimoli yuqori; kod yo'li mavjudligi o'sha
  chaqiruv muvaffaqiyatli bajarilganini isbotlamaydi.
- 1 fayl noto'g'ri login rad etilishini kutadi; bu parolning faol ekaniga dalil emas.
- 1 faylda qiymat kommentariyada takrorlangan; executable login dalili emas.
- Exact-match false positive: **0**. Oxirgi ikki holatni faol credential
  isboti deb hisoblash esa noto'g'ri bo'ladi.
- Ushbu 16 faylning barchasi HEAD va working tree'da mavjud; ulardagi
  CRED-H01 literal occurrence soni **0**. Biroq boshqa security testida bu parol
  qayta birlashtiriladigan bo'laklarda qolganligi aniqlandi; bu global absence
  dalili emas. Tuzatish va global scan chegaralari quyida berilgan.

Quyidagi har bir satr uchun credential turi — tarixiy test hisob paroli,
credential guruhi — **CRED-H01**. HEAD/WT ustuni faylning mavjudligini va
credentialning shu faylda qolmaganini bildiradi.

| Commit | Fayl:tarixiy satr | Ishlatilish / haqiqiy secret ehtimoli | HEAD / WT | Amal |
|---|---|---|---|---|
| `e4ecf964beafb082640af02bf82ab0c3f12073e4` | `test/integration/cleanup_live_test_data_test.dart:38` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `ee2bac08d8b806d392442bcee255f3d6ea36d588` | `test/integration/community_write_session_rls_live_test.dart:64` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/debug_signup_repro_test.dart:33` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/forensic_auth_split_diagnosis_test.dart:88` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/forensic_db_triggers_and_schema_test.dart:55` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/real_db_error_diagnostic_test.dart:35,46,58` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/real_supabase_e2e_test.dart:58` | Negative login; faollik dalili emas | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/real_supabase_signup_cloud_verification_test.dart:35` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/verify_community_answer_live_test.dart:62` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `dc53e270c631eac3c569f77ce67be04f01d51835` | `test/integration/verify_legal_ai_proxy_live_test.dart:181` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `e4ecf964beafb082640af02bf82ab0c3f12073e4` | `test/integration/verify_mvp_blockers_live_test.dart:152` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/verify_profile_invariant_live_test.dart:63` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/verify_rate_limit_error_mapping_test.dart:38` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `ac095f4ad1580ac34bf9bcc01dea4cd221892044` | `tool/probe_creds.py:6` | Kommentariya; faollik dalili emas | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `740f3b1e0df74e4346367799cfeecfb7557828e4` | `tool/probe_legal_ai_latency.py:25` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |
| `7aa255fc9b176e38decf8ba96b348e8c65299101` | `tool/probe_legal_ai_model.py:28` | Signup/login; yuqori | Fayl bor; CRED-H01 yo'q | CRED-H01 guruhini rotate/revoke tekshirish |

**Revoke/rotate:** CRED-H01 ishlatilgan test hisoblarini egasi xavfsiz ichki
ro'yxat orqali aniqlashi kerak. Faol bo'lsa parollarni almashtirish yoki
ishlatilmaydigan hisoblarni yopish va sessiyalarni bekor qilish zarur.
Credential boshqa joyda qayta ishlatilgan bo'lsa o'sha joy ham qamraladi.
Remote login bilan tekshirish yoki rotation bu auditda bajarilmadi:
**NOT VERIFIED**. Tarixni tozalash credentialni bekor qilish o'rnini bosmaydi.

### Yangi current-tree topilma

**CRED-H01 current exposure** — `test/core/security/no_leaked_test_password_test.dart`
ichidagi yonma-yon literal bo'laklar eski parolni qayta hosil qilgan. In-memory
taqqoslash tarixiy qiymatga tengligini tasdiqladi. Oddiy contiguous-match
skani buni o'tkazib yuborgan; security testining o'zi credentialni saqlagan.
Bu faqat sintetik fixture deb tasniflanmaydi. Oraliq comparator qayta tiklanadigan
literal o'rniga SHA-256 fingerprint va byte-length ishlatgan edi.
Yakuniy review bu yechimni rad etdi: hash login credential emas, lekin
past-entropy credentialni offline taxmin qilish uchun tekshiruv vazifasini
bajarishi mumkin. Real fingerprint olib tashlandi; joriy test credential
assignment va config fallback literalini tekshiradi. Mavjud sintetik fixture
istisnolari aniq fayl va qiymat bilan cheklangan. Endi kerak bo'lmagan
`crypto` direct dev dependency olib tashlandi; resolved versiyalar o'zgarmadi.

**CRED-C01** — `test/integration/real_supabase_mvp_fixes_verification_test.dart`
ichidagi boshqa hardcoded test hisob paroli. Boshlang'ich HEAD/working tree'da
statik hisob bilan `signUpWithEmail` chaqiruviga uzatiladi. Live gate borligi
credentialni kodda saqlashni xavfsiz qilmaydi. CRED-H01 bilan teng emas.

Minimal tuzatish: mavjud `test/support/live_test_password.dart` helperiga
o'tkazish va `no_leaked_test_password_test.dart`dagi talab qilinadigan fayllar
ro'yxatini kengaytirish. Test helper uchun environment'dan credential oladi;
production credential o'zgartirilmaydi. Bu tuzatish hozir `909870f` HEAD ichida;
eski literal faqat tarixiy nusxalarda qolgan. Keyingi read-only preflight:
signup targeti noto'g'ri email formatida, production Auth'da aynan shu target
uchun 0 account. Shu fayldagi valid email MockAuthRepository fixture'iga tegishli.
Literal exposure tasdiqlangan, ammo real account credentiali bo'lganligi va
rotation targeti **NOT VERIFIED**. Mock hisobni production targeti deb olmang.

CRED-C01 uchun tekshirilgan eski commitlar:
`8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` va
`e4ecf964beafb082640af02bf82ab0c3f12073e4`. Ikki current source exposure
ikki guruhga tegishli: CRED-H01 va CRED-C01. Ularning faol hisob/parol holati
**NOT VERIFIED**; kodda qiymat saqlangani esa tasdiqlangan.

### Audit chiqishidagi hodisa

Yordamchi inspection vositalaridagi string/header redaction xatolari tufayli
CRED-H01 qiymati va keyingi boshqa chiqishda ayrim fragmentlari tool output'da
tasodifan ko'rindi. Bu topshiriqning secretni chiqarmaslik talabini buzdi.
Qiymatlar hisobot/evidence fayllariga yozilmadi. Fragment ko'rsatishga asoslangan
inspection to'xtatilib, chiqish faqat allowlist metadata bilan cheklandi.
Oldingi tool output o'chirilgan deb da'vo qilinmaydi. Tegishli test hisoblari
uchun yuqoridagi rotate/revoke tavsiyasi amal qiladi.

## 2. CURRENT TREE SECRET SCAN

| Scope | Qamrov | Tasdiqlangan koddagi exposure | False positive / boshqa holat |
|---|---|---|---|
| HEAD tracked | 684 fayl: 608 matn, 76 binary | 2 guruh, 3 occurrence: CRED-H01 security test headeri va literal bo'laklari; CRED-C01 live signup | 37 context bo'yicha ajratilgan moslik |
| Yakuniy working tree tracked + untracked | 688 fayl: 612 matn, 76 binary | Ushbu skanda 0 tasdiqlangan literal yoki qayta tiklanadigan credential | 37 context bo'yicha ajratilgan moslik; unresolved candidate 0 |
| Ignored lokal config | 13 matn fayl | CRED-L01 lokal probe credential; Git exposure topilmadi | Public client key 3 occurrence, placeholder 1 |

37 source false positive: 6 placeholder, 18 UI/localization matni, 10 sintetik
fixture, 1 negative-auth fixture, 1 documentation misoli, 1 log reason yorlig'i.
Ular faol credential deb hisoblanmaydi. HEAD va working tree bir xil fayllarni
ko'p jihatdan takrorlaydi; scope sonlari qo'shilib unique secret soni qilinmaydi.

Google/GitHub token, Supabase privileged key/JWT, private key va credentialli
DB URL patternlari bo'yicha alohida tasdiqlangan topilma yo'q. Known-password,
split-literal, token/private-key/DB-URL positive hamda safe-text/placeholder/floor
uchun scannerning 10 lokal tekshiruvi o'tdi. Bu raw substring skanidagi
ko'r nuqtani kontekst va birlashtiriladigan literal tekshiruvi bilan aniqladi.

Local-only configlar alohida tekshirildi:

- `.env`, `env/dev.json`, `env/prod.json`: Git'da kuzatilmaydi va ignore qilingan.
  Uch occurrence bir xil Supabase **publishable client key**ga tegishli;
  service-role/server secret emas.
- `env/probe.json`: Git'da kuzatilmaydi va ignore qilingan. Non-placeholder
  test paroli **CRED-L01** mavjud; CRED-H01 va CRED-C01 bilan teng emas.
  Bu lokal konfiguratsiya mavjudligi, Git exposure dalili emas. Haqiqiyligi va
  hisob holati tekshirilmadi; faqat mavjudligi sababli avtomatik rotation
  talab qilinmaydi. Faylni repository yoki logga kiritmaslik kerak.

Skan matn/pattern/context asosida; binary, paket cache'i, build artifactlari va
repositorydan tashqaridagi credential saqlash joylarida barcha mumkin bo'lgan
sirlar yo'qligini isbotlamaydi. Tarix skani 2 MBgacha binary bo'lmagan bloblarni
qamragan. Hech qanday topilma credential qiymati bilan bu hisobotda berilmagan.

## 3. BACKUP / RECOVERY

| Band | Real dalil | Holat |
|---|---|---|
| DB sessiya | MCP: `postgres`, `supabase_read_only_user`, `transaction_read_only=on`, PostgreSQL 17.6 | VERIFIED — sessiya metadata |
| Loyiha identity | CLI'da bitta LexHub, ACTIVE_HEALTHY, `ap-northeast-1`; `env/prod.json` ref'i linked ref va loyiha ro'yxati bilan mos | VERIFIED — identity |
| Backup API | `backups=null`, `physical_backup_data={}`, `walg_enabled=true` | VERIFIED — shu API javobi; backup mavjudligi NOT VERIFIED |
| PITR | `pitr_enabled=false` | VERIFIED — OFF |
| Retention | API retention yoki backup vaqtlarini bermadi; org list ham plan maydonini bermadi | NOT VERIFIED |
| Available restore point | API javobida backup/earliest/latest restore timestamp berilmagan | NOT VERIFIED |
| Manual logical backup | Rasmiy Supabase CLI yo'li hujjatlashtirilgan; ushbu muhit PATH'ida Docker/psql/pg_dump topilmadi | Imkoniyat hujjatda bor; real bajarilishi NOT VERIFIED |
| Restore to new project | Rasmiy yo'l paid plan + physical backup talab qiladi; loyiha entitlement'i va mavjud restore nuqtasi tasdiqlanmadi | NOT VERIFIED |
| Restore rehearsal / RPO / RTO | Restore boshlanmadi, tiklangan baza bilan taqqoslash qilinmadi | NOT VERIFIED |

MCP tool to'plamida backup inventory/retention/restore-management amali yo'q;
SQL katalogi provider backup mavjudligini isbotlamaydi. Shu sabab authenticated
READ-ONLY `supabase backups list`, `projects list`, `branches list`, `orgs list`
ishlatildi. `backups=null` barcha provider backuplari mutlaqo yo'q degani emas.
WALG yoqilganligi ham tiklanadigan nuqta mavjudligini isbotlamaydi.

### Admin uchun recovery tartibi — bu topshiriqda bajarilmaydi

1. Dashboard'da LexHub source loyihasini tekshirish: private ref'ni
   `env/prod.json` va `supabase/.temp/project-ref` bilan solishtirish; region
   `ap-northeast-1`, DB `postgres`, PostgreSQL 17.6. Ref yoki connection secretni
   ommaviy logga chiqarish shart emas. Restore target alohida loyiha bo'lishi kerak.
2. Database → Backups'da plan/retention, backup turi, oxirgi muvaffaqiyatli
   vaqt va available restore pointni qayd etish. API bilan tafovut bo'lsa
   provider support/admin orqali aniqlashtirish. Bu qadam READ-ONLY.
3. Tiklanadigan backup bo'lmasa, alohida ruxsatdan keyin himoyalangan admin
   muhitida rasmiy CLI logical backup yo'lini tayyorlash: roles/schema/data,
   migration history va custom Auth/Storage schema o'zgarishlarini qamrash.
   Secretlarni shell history/outputga joylamaslik; backupni shifrlangan,
   cheklangan joyda saqlash. Hozir backup yaratilmaydi yoki DB paroli reset qilinmaydi.
4. Restore mashqi uchun alohida cheklangan recovery target ajratish. Paid plan
   va physical restore point tasdiqlansa Dashboard restore-to-new-project;
   aks holda rasmiy CLI logical restore yo'li ko'rib chiqiladi. Ikkisi ham
   ma'lumot nusxalash va xarajat/remote o'zgarish yaratishi mumkin:
   **REQUIRES EXPLICIT APPROVAL**. Scheduler/webhook va tashqi chaqiruvlarni
   cheklash rejasi restore/clone boshlanishidan oldin tasdiqlanadi: avtomatik
   job foydalanuvchi kirmasdan ham ishga tushishi mumkin. Bu ishda target yaratilmagan.
5. Recovery nusxasini oddiy Preview sifatida ochmaslik. Auth ma'lumotlari
   ko'chishi mumkin; SMTP, payment/webhook, scheduler va tashqi integratsiyalar
   productionga ta'sir qilmasligi tekshiriladi; tekshiruvdan keyingina targetning
   zarur avtomatik joblari va tashqi integratsiyalariga ishlashga ruxsat beriladi.
   Storage obyektlari va Edge Functions alohida tiklanadi. Targetning yangi API
   kalitlari ishlatiladi; Auth settings, Realtime va tashqi integratsiyalar
   izolyatsiyalangan muhitga mos qayta sozlanadi. Encryption/custom-role
   konfiguratsiyasi ham alohida tekshiriladi.
6. Tiklangan targetda schema/roles/RLS/grants/triggerlar, muhim jadval
   yaxlitligi, migration history va Auth/Storage oqimini tekshirish;
   source bilan cheklangan ichki taqqoslash, haqiqiy vaqt va recovery nuqtasini
   qayd etish. Faqat backup fayli mavjudligi restore isboti emas.

Rasmiy manbalar, 2026-09-20 MCP docs orqali o'qildi:
[Database Backups](https://supabase.com/docs/guides/platform/backups),
[Restore to a new project](https://supabase.com/docs/guides/platform/clone-project),
[CLI backup/restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
Plan bo'yicha hujjatdagi umumiy retention muddatlari LexHub'ning tasdiqlangan
retention'i sifatida ishlatilmadi.

## 4. STAGING

**Alohida staging DB aniqlanmadi; Vercel Preview mavjud.**

- Supabase accessible project list: 1 — LexHub production. Branch list: 0.
  Boshqa hisob/organization'dagi ko'rinmaydigan staging yo'qligi isbotlanmagan.
- `env/dev.json` production Supabase hostiga teng; alohida staging config emas.
  `supabase/config.toml` va `.github/workflows` mavjud emas. Repositorydagi
  bo'sh lokal bootstrap va PGlite runner cloud staging workflow'i emas.
- Vercel `lexhub` ro'yxati: 31 deployment, pagination tugagan; 13 preview va
  18 production. Eng so'nggi Preview `READY`, branch `fix/vercel-git-autodeploy`,
  commit `602e01e55c1b73aee4de0fe40455363241497ad9`. HTTP/runtime sinalmagan.
- Custom environments: 0. Uch client konfiguratsiyasi uchun har bir env yozuvi
  `production` va `preview` targetlarini birga ko'rsatadi; branch override yo'q.
  Alohida staging DB qiymatlari tasdiqlanmagan. Bu izolyatsiyalangan staging
  deb hisoblanmaydi va Preview'da live-write testni yoqishga asos emas.

### Eng xavfsiz staging varianti va migration runbook

Ajratilgan Supabase test loyihasi, sintetik hisob/ma'lumot va alohida Preview
environment qiymatlari tavsiya qilinadi. Production ma'lumotlarini ko'chirish
stagingni boshlash sharti emas. Recovery nusxasi esa alohida cheklangan mashq.
Rasmiy [branching](https://supabase.com/docs/guides/deployment/branching/github-integration)
ham production ma'lumotlarini nusxalamaydi, lekin avtomatik migration replay'i
LexHub history driftini o'z-o'zidan yechmaydi; hozir yoqilmaydi.

1. Admin target ref productiondan farqlanishini, Auth/Storage/API va tashqi
   integratsiyalar ajratilganini tekshiradi. Key va DB password secret store'da;
   Vercel Preview uchun productiondan mustaqil parametrlar kerak.
2. Test targetning boshlang'ich sxemasini tasdiqlangan lokal replay va o'lchangan
   production DDL bilan solishtiradi. `rebuild.sql` faqat bo'sh lokal bazaga
   mo'ljallangan; cloud guardni chetlab o'tish yoki mavjud bazada bulk replay yo'q.
   `db push --include-all` bilan yetti eski history gapini avtomatik to'ldirmaydi.
3. Tasdiqlangan candidate-oldi staging baseline'da
   `supabase/verification/stage1_preflight.sql`: 10/10 kutiladi.
   Target allaqachon candidate'larni o'z ichiga olsa history bilan aniqlaydi;
   yangi apply deb hisoblamaydi.
4. Faqat staging amali alohida ruxsatlangach `20260919001000` →
   `20260919002000` tartibida, har biri o'z transaction'i bilan qo'llanadi.
   `stage1_postflight.sql`: joriy nusxada 9/9 kutiladi. Ikkinchi migration xatosi birinchining
   oldingi COMMIT'ini qaytarmaydi; [DB runbook](STAGE1_DATABASE.md) amal qiladi.
5. Faqat izolyatsiyalangan targetda sintetik A/B/moderator bilan answer
   author/edit/accept, expert INSERT/approval/cooldown, booking va Auth/PostgREST
   ijobiy/salbiy sinovlari bajariladi. Matn/havola tekshiruvi va qayta ijro
   natijasi qayd etiladi. Productionni ko'rsatuvchi `dev.json` ishlatilmaydi.

## 5. TEST NATIJALARI

| Tekshiruv | Natija | Dalil/chegara |
|---|---|---|
| Yangi static-signup credential regressiyasi | Tuzatishdan oldin FAIL; keyin PASS | Helper talabini chetlab o'tish aniqlanadi |
| Security test suite | 5 PASS | Helper, known-secret fingerprint, sintetik positive/negative |
| Haqiqiy tarixiy fingerprint mutatsiyasi | PASS → mutatsiyada FAIL → tiklangach PASS | Izolyatsiyalangan lokal vaqtinchalik probe; keyin o'chirildi |
| `flutter analyze --no-pub` | PASS — No issues found | Yakuniy source; `analyze-final.log` |
| `flutter test --no-pub --reporter expanded` | PASS — 993 o'tdi, 27 skip, 0 fail | `flutter-tests-final.log`; live-write gate ochilmadi |
| Deno legal-ai testlari | PASS — 31 test, 2 step | `deno-tests.log`; real production model chaqiruvi emas |
| `deno check --no-lock supabase/functions/legal-ai/index.ts` | PASS | `deno-check.log` |
| `python tool/validate_sql_syntax.py` | PASS — 36 migration, 0 xato | `sql-validation.log` |
| `node tool/database/verify_stage1_db.mjs` | PASS — 24 runtime guruhi | `db-validation.log`; lokal PGlite |
| Dependency graph taqqoslash | PASS — 163 paketning nom/versiyalari HEAD bilan bir xil | Faqat crypto dependency turi transitive'dan direct dev'ga o'tdi |
| `git diff --check` | PASS | Whitespace xatosi yo'q; raw diffdagi eski secretlar chiqarilmadi |

Loglar `build/credential_recovery/` ichida. Avvalgi 992-testli oraliq run
o'rniga yuqoridagi 993-testli yakuniy natija ishlatiladi. To'liq production
Auth/PostgREST, credential validity, backup/restore yoki migration runtime'i
bu testlardan VERIFIED deb olinmaydi.

## 6. PRODUCTION MIGRATION GATE

**BLOCKED.** Backup/retention/restore nuqtasi va real restore mashqi tasdiqlanmagan;
PITR OFF. Ajratilgan staging DB hamda Auth/PostgREST sinov dalili yo'q.
Credential rotate/revoke holati ham ochiq. Lokal testlar bu kamchiliklarni yopmaydi.
Keyinchalik recovery/staging tasdiqlansa ham production APPLY avtomatik
boshlanmaydi: **REQUIRES EXPLICIT APPROVAL**.

## 7. KEYINGI BITTA ENG XAVFSIZ ACTION

Hisob egasi **CRED-H01 bo'yicha aniqlangan production probe hisobining rotation
dalilini tekshirsin; CRED-C01 bo'yicha esa avval haqiqiy account/reuse borligini
aniqlasin**. Quyidagi joriy checklist amal qiladi. Qiymatlar chatga yuborilmasin.
Backup/restore va migration amallari ushbu qadam bilan birlashtirilmaydi.

## Git va dalil fayllari

Branch: `audit/stage1-production-preflight`.
HEAD va `main`: `619534e36bbc5bb3e208aee09839dfc9a46bb843`.
Rollback checkpoint: `9ce9f10e8a1d2b6ac960ccb5b7bb87bc0a0f5ba4` saqlandi.
Commit, push, force-push, reset/clean yoki history rewrite bajarilmadi.

Ushbu davomda tegilgan fayllar:

| Fayl | Sabab |
|---|---|
| `test/integration/real_supabase_mvp_fixes_verification_test.dart` | CRED-C01 literalini helper bilan almashtirish |
| `test/core/security/no_leaked_test_password_test.dart` | Recoverable CRED-H01 o'rniga fingerprint; yangi helper/sintetik regressionlar |
| `pubspec.yaml`, `pubspec.lock` | Mavjud crypto 3.0.7 ni test uchun direct dev dependency qilish |
| `docs/DEPLOY.md` | Production/Preview env metadata bo'yicha eskirgan bayonotni yangilash |
| `docs/STAGE1_CONTINUATION.md` | Yangi aniqlashtirilgan hisobotga havola |
| `docs/STAGE1_CREDENTIAL_RECOVERY.md` | Ushbu batafsil audit va admin runbook |

Umumiy dirty tree: 12 modified + 4 untracked fayl; bunga oldingi Stage 1
o'zgarishlari ham kiradi. Faqat shu davomda 7 faylga tegildi. HEAD o'zgarmagani
sabab ikkala current credential exposure HEAD/tarixdan olib tashlangan deb
hisoblanmaydi; tuzatish working tree'da.

Qiymatlarsiz lokal dalillar `build/credential_recovery/` ichida:
`history_detailed.json`, `recovery_metadata.json`, `staging_metadata.json`
va joriy scan/test natijalari. Bu katalog ignore qilingan.

## Current repository finalize — 2026-09-20

HEAD `619534e` va `main` o'zgarmadi. Credential qiymatlari qayta qidirilmadi;
CRED-H01/CRED-C01 tasnifi yuqoridagi saqlangan metadata asosida ishlatildi.
Yangi production so'rovi, mutation, login, rotation, commit yoki push bajarilmadi.

Yakuniy review bitta test kamchiligini topdi: helper qisqa define'ni to'g'ri
rad etsa ham, test faqat bo'sh define uchun xato kutardi. Test endi bo'sh va
16 belgidan qisqa qiymatlarni tekshiradi; yaroqli sintetik konfiguratsiya aynan
qaytishi boolean assertion bilan tasdiqlanadi. Fingerprint testiga haqiqiy
ko'p baytli UTF-8 fixture qo'shildi. Production helper va live gate o'zgarmadi.

`LEXHUB_TEST_PASSWORD` compile-time dart-define orqali uzatiladi. Bo'sh,
qisqa, yaroqli sintetik define va shell environment fallback yo'qligi lokal
tekshirildi. Helper guardi va UTF-8 algoritmi ataylab buzilganda tegishli
testlar FAIL berdi; fayllar baytma-bayt tiklangach PASS. Bunda haqiqiy
credential o'qilmadi yoki sinov konfiguratsiyasiga ko'chirilmadi.

Yakuniy natija: analyze PASS; Flutter 993 PASS/27 skip; Deno 31 PASS/2 step
va type check PASS; SQL 36 fayl/0 xato; lokal DB 24 regression guruhi PASS;
`git diff --check` PASS. 163 paketning nom/versiyalari HEAD bilan bir xil.
Loglar va aniq commit fayllar manifesti: `build/stage1_finalize/`.

### Credential rotation ACTION LIST — bajarilmagan

| Guruh | Rotate/revoke tavsiyasi | Service/account turi | Invalidate qilinadigan sessiyalar |
|---|---|---|---|
| CRED-H01 | YES — shu credentialdan foydalangan faol hisoblarda; faol holat va bajarilishi NOT VERIFIED | Supabase Auth email/password integration/probe test hisoblari; 14 tarixiy live-auth kod yo'li | Aniqlangan hisoblarning barcha web/mobile/test-client sessiyalari va refresh tokenlari |
| CRED-C01 | NOT VERIFIED — real account/reuse avval aniqlanishi kerak | Supabase Auth signup kodidagi literal; noto'g'ri email target, aynan shu target uchun 0 production account | Hozir target yo'q; faqat real account aniqlansa uning sessiyalari |

Vakolatli egasi hisoblarni mavjud audit metadata va ichki account ID orqali
aniqlaydi; eski parol bilan login sinovi o'tkazilmaydi. Kerakli test hisoblari
uchun yangi noyob credential secret store'ga beriladi; kerak bo'lmagan hisoblar
vakolatli tartibda yopiladi. Faqat local logout yetmaydi: account doirasidagi
global invalidation tekshiriladi. Dart `signOut()` defaulti local bo'lishi
mumkin; global scope ataylab tanlanishi kerak.

Bekor qilingan sessiyaning avval berilgan access JWT'si `exp`gacha amal qilishi
mumkin. Shu sabab refresh token invalidation va access-token muddati alohida
qayd etiladi; darhol barcha tokenlar yaroqsiz deb yozilmaydi. Manba:
[Supabase Signing out](https://supabase.com/docs/guides/auth/signout).
Bu ikki topilma project API/service-role/signing key sizganiga dalil emas.

Repository commitga tayyor; production release/migration tasdiqlanmagan.
Taklif: `fix(security): finalize Stage 1 guards and credential hygiene`.

## Fingerprint exposure fix — 2026-09-20

Yuqoridagi fingerprintga asoslangan oraliq yechim bekor qilindi. Joriy test
real credential, uning fingerprinti yoki uzunligiga bog'lanmaydi. Hardcoded
password/token/key assignmentlari, credential digest literal va credential
uchun `String.fromEnvironment` fallback qiymatlari tekshiriladi. Faqat
review qilingan sintetik qiymat va aniq test fayli juftligiga istisno bor;
shu qiymat production kodiga yoki yangi live testga ko'chirilsa rad etiladi.
Helper importi, mavjud live gate va compile-time konfiguratsiya saqlandi.

Bu sintaktik regression barcha mumkin bo'lgan yashirish/encoding usullarini
aniqlash yoki credential revoke qilinganini isbotlash da'vosi emas.
Hashning o'zi login credential emas, ammo past-entropy credential fingerprinti
offline guessing uchun ishlatilishi mumkin. Shu sabab real fingerprint
repositoryda saqlanmaydi. Sintetik digest misoli faqat runtime'da yaratiladi.
Hash hisoblashga ehtiyoj qolmagani uchun `crypto` direct dev dependency olib
tashlandi; pubspec fayllari oldingi `619534e` holatiga qaytdi, 163 resolved
paketning nomi/versiyasi o'zgarmadi. Production runtime kodi bu tuzatishda
o'zgarmadi.

Tekshiruvlar:

- `flutter analyze --no-pub`: PASS, 0 issue.
- Yangi credential guard: 8 test PASS; security katalogi: 139 test PASS.
- Sintetik credentialni vaqtinchalik source faylga kiritish va fixture
  istisnosini barcha fayllarga kengaytirish: 2 kutilgan FAIL; probe o'chirilib,
  test fayli baytma-bayt tiklangach 8 test yana PASS.
- To'liq Flutter suite: 996 PASS, 27 live gate skip, 0 failure.
- Deno: 31 PASS, 2 step; `index.ts` type check PASS.
- SQL: 36 migration, 0 xato; lokal PGlite: 24 regression guruhi PASS.

Amenddan oldingi HEAD/working-tree skani har birida 688 faylni ko'rdi:
612 matn va 76 binary. Credential/token patternlari matnda tekshirildi;
ma'lum fingerprint binary fayllarda ham qidirildi. HEAD'da ma'lum fingerprint
1 marta, tuzatilgan working tree'da 0 marta topildi. Boshqa tasdiqlangan
credential topilmadi; UI yorliqlari va lokal test fixturelari alohida ajratildi.
Bu binary arxivlarni ochib tekshirish yoki butun Git tarixini tozalash emas.
Amend eski lokal object/reflog nusxalarini yo'q qilmaydi; tarixiy credential
exposure va CRED-H01/CRED-C01 rotation holati hali NOT VERIFIED.

Loglar: `build/fingerprint_fix/` (ignore qilingan). Production DB, migration,
credential rotation, deploy va push bajarilmadi. Production recovery/staging
gate oldingi kabi BLOCKED; lokal source tuzatishi bu gate'ni ochmaydi.

## Rotation preflight aniqlashtirishi — 2026-09-20

Bu bo'lim shu kundagi oldingi READ-ONLY credential preflight dalillarini
repository hujjatiga ko'chiradi; yangi login/rotation/session amali bajarilmadi.
`909870f` current tree'da real credential literal/fingerprinti olib tashlangan;
tarix/reflog tozalanmagan. Keyingi lokal natija: [Stage 1 finalization](STAGE1_FINALIZATION.md).

| Band | CRED-H01 | CRED-C01 |
|---|---|---|
| Service/turi | Supabase Auth email/password test/probe | Supabase Auth signup kodidagi password literal |
| Account dalili | Production'da 1 candidate, ref `69be7ffb…`, citizen/email, confirmed; deleted/active ban yo'q | Signup `testEmail` formati noto'g'ri; aynan shu target uchun Auth'da 0 account |
| Current config aloqasi | Ignored `env/probe.json:PROBE_EMAIL` shu accountga aynan mos | Test `liveTestPassword()` orqali define oladi; real account/reuse aniqlanmagan |
| Faollik metadata | Created 2026-09-02 12:45:09 UTC; last sign-in 2026-09-04 12:14:24 UTC | Haqiqiy signup/login muvaffaqiyati NOT VERIFIED |
| Session metadata | 14 session va 14 `revoked=false` refresh-token yozuvi, oxirgi yangilanish 2026-09-04 | Target va session to'plami yo'q |
| Production relevance | YES — probe account/config ishlab turgan production loyihasiga tegishli | NOT VERIFIED; mock email real target emas |
| Rotation required | YES — historical exposure sabab tavsiya; avvalgi rotation isboti tekshirilsin | NOT VERIFIED; real account yoki reuse topilsagina YES |
| Bajarilishi / eski parol yaroqliligi | NOT VERIFIED | NOT VERIFIED |

14 ta yozuv 14 ta hozir yaroqli token degani emas. H01 probe kommentariyasidagi
2026-09-04 rotation/old-login-400 bayonoti yangi mustaqil dalil bilan tasdiqlanmagan;
tekshirilgan account audit-event so'rovi bo'sh qaytgan. Boshqa 13 tekshirilgan
email naqshi uchun 0 account topilishi butun tarixda boshqa account yo'qligini
isbotlamaydi. C01 bo'yicha `8c46350` va `e4ecf96` snapshotlaridagi signup targeti
tekshirilgan; shu fayldagi boshqa valid email faqat mock testga tegishli.

### Vakolatli admin uchun ACTION LIST — bajarilmagan

1. **Targetni tasdiqlash.** Supabase project egasi yoki Auth user management
   huquqli admin H01 accountni ichki ID va `env/probe.json:PROBE_EMAIL` orqali
   aniqlaydi. C01 uchun avval haqiqiy account/reuse evidence kerak; mock target
   bo'yicha rotation qilinmaydi. Tarixdan parol/hash tiklanmaydi.
2. **Rotation qarori.** H01 uchun oldingi rotation dalili yo'q bo'lsa, account
   kerak bo'lsa yangi noyob passwordni Auth user-management orqali o'rnatish,
   kerak bo'lmasa tasdiqlangan revoke/disable tartibini bajarish tavsiya etiladi.
   DB jadvaliga qo'lda password yozilmaydi. C01 real target/reuse tasdiqlansa
   xuddi shu tartib. Hozir ikkala amal ham bajarilmagan.
3. **Configuration.** H01 ishlatiladigan secret store, `LEXHUB_PROBE_EMAIL` /
   `LEXHUB_PROBE_PASSWORD` override'lari va ignored `env/probe.json` birga
   yangilanadi; override eski qiymat bilan faylni bosib ketmasin. `LEXHUB_TEST_PASSWORD`
   faqat alohida test konfiguratsiyasida kerak bo'lsa yangilanadi. Vercel uchta
   public client parametri bu account passwordi emas; Supabase API/service-role,
   Gemini yoki signing key rotationiga bu finding dalil bermaydi.
4. **Session invalidation.** Tegishli accountning rotationdan OLDINGI barcha
   web/mobile/probe/test sessiyalari uchun global revoke qo'llanadi. Bitta
   qurilmadagi logout yetmaydi. Admin Auth vositasi va aniq scope qayd etiladi;
   userni boshqa qurilmalardan chiqarmasdan turib "hammasi yopildi" deyilmaydi.
5. **Post-rotation evidence.** Target ref, vaqt, operator, provider action natijasi
   va config yangilanganligi qiymatlarsiz qayd etiladi. Kerakli accountda yangi
   credential bilan ruxsatlangan login tekshiriladi; password/token log qilinmaydi.
   Eski password faqat vakolatli omborda allaqachon mavjud bo'lsa, alohida
   ruxsatlangan salbiy sinovda ishlatilishi mumkin; Git/chatdan tiklanmaydi.
6. **Session evidence.** Rotationdan oldingi session ID to'plami va refresh-token
   revocation metadata'si solishtiriladi; provider qayd etgan revoke natijasi
   olinadi. Oldindan xavfsiz saqlangan test session bilan refresh rad etilishi
   alohida ruxsatlangandagina sinaladi. Keyingi yangi login sessionlari eski
   sessiya deb sanalmaydi. Access JWT `exp`gacha amal qilishi mumkin: refresh
   rad etilishi va avvalgi access-token muddati tugashi alohida tekshiriladi.
7. **Yakun mezoni.** H01 uchun target/config/rotation/global-revoke dalili to'liq
   bo'lgandagina yopiladi. C01 target topilmasa "NOT VERIFIED — identity/reuse"
   qoladi; account mavjud emasligi avtomatik "credential xavfsiz" emas.

Manba: [Supabase sign out va JWT muddati](https://supabase.com/docs/guides/auth/signout).
Production mutation, credential rotation/revoke va session invalidation ushbu
repository ishining bir qismi sifatida bajarilmaydi.
