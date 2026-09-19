# LexHub — Stage 1 davomi, 2026-09-20

> Keyingi tekshiruv: [Credential va recovery preflight](STAGE1_CREDENTIAL_RECOVERY.md).
> Credential guruhlari, current-tree tuzatishi va Preview/staging holati u yerda aniqlashtirilgan.

**Umumiy holat: PARTIALLY VERIFIED. Production migration gate: BLOCKED.**
Boshlang'ich commit: `619534e36bbc5bb3e208aee09839dfc9a46bb843`.
Ish branchi: `audit/stage1-production-preflight`. Main o'zgartirilmadi.
Production DB write, migration APPLY, deploy, credential rotation, commit va
push bajarilmadi. `9ce9f10` rollback checkpoint saqlandi.

## 1. BAJARILDI

- `STAGE1_DATABASE.md` va `STAGE1_RESULTS.md` asosida P1-01–P1-09/P2-12 qayta ko'rildi.
- Production identity, READ-ONLY sessiya, backup/PITR metadata, staging mavjudligi,
  migration history, schema/RLS/trigger/ACL va Edge/Vercel deploy metadata tekshirildi.
- Ikki candidate migration toza lokal PostgreSQL/PGlite'da qayta ijro qilindi;
  takror qo'llash, SQL syntax, transaction rollback va security regressionlar sinaldi.
- Har ikki verification SQL production'da ham faqat SELECT bilan bajarildi.
- Git tarixining 2 521 reachable obyekti orasidan 1 097 matn blob skanerlandi.

## 2. TUZATILDI

Yangi aniqlangan sabab: `LegalNarrativeGuard` `copyWith` orqali faqat asosiy
xulosa/qadamlarni almashtirardi. Model yuborgan `document_text`,
`source=document_template`, `emergency_protocol`, saqlash/tugatish belgisi va
scope metadata'si saqlanib qolishi mumkin edi. Legacy/direct-model javobi
`user_query` va `query_id`ni ham almashtira olardi.

Tuzatish: guard yangi javobni faqat ruxsat etilgan maydonlardan yaratadi;
model hujjat/favqulodda ko'rsatma yoki local persistence metadata'sini bera
olmaydi. Asl foydalanuvchi matni va query ID datasource'da yuborilgan so'rovdan
olinadi. Ishonchli lokal emergency detector va repository hisob scope'i keyin
o'z qiymatlarini biriktiradi. Haqiqiy document builder saqlashi o'zgarmadi.

Yangi regressionlar avval eski xulqda FAIL berdi; tuzatishdan so'ng PASS.
Haqiqiy datasource testida modelning soxta emergency'si yo'qoldi, lekin haqiqiy
favqulodda so'rov uchun lokal protocol saqlandi.

| Fayl | O'zgarish |
|---|---|
| `lib/core/legal_safety/legal_narrative_guard.dart` | Ruxsat etilgan remote maydonlargina yangi javobga o'tadi |
| `lib/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart` | Asl user query va query ID saqlanadi |
| `test/core/legal_safety/legal_narrative_guard_test.dart` | Hujjat/emergency/persistence metadata orqali chetlab o'tish regressiyasi |
| `test/core/legal_safety/stage1_legal_regression_test.dart` | Asl faktlar va ishonchli emergency protocol uchun datasource regressiyasi |
| `supabase/verification/stage1_preflight.sql` | 10 ta READ-ONLY prerequisite tekshiruvi |
| `supabase/verification/stage1_postflight.sql` | 8 ta READ-ONLY kutilgan yakuniy holat tekshiruvi |
| `tool/database/verify_stage1_db.mjs` | Verification SQL uchun read-only runtime va buzilgan holatlar sinovi |
| `docs/STAGE1_DATABASE.md`, `docs/STAGE1_RESULTS.md`, ushbu fayl | Gate, dalillar, qo'llash tartibi va recovery chegaralari |

Mavjud ikkita migration o'zgartirilmadi. Home dizayni/yangi feature qo'shilmadi.

## 3. TEST NATIJALARI

| Tekshiruv | Natija | Chegara |
|---|---|---|
| `flutter analyze --no-pub` | PASS — `No issues found!` | Statik tahlil |
| `flutter test --no-pub --reporter expanded` | PASS — 991 o‘tdi, 27 skip, 0 xato | Production yozish testlari yoqilmadi |
| P1 guard/datasource/history/draft targeted run | PASS — 30 test | Umumiy suite ichida ham hisoblangan |
| Deno grounding/model chain/narrative/handler | PASS — 31 test, 2 ichki ssenariy | Auth/Gemini transporti lokal almashtirilgan |
| `deno check --no-lock supabase/functions/legal-ai/index.ts` | PASS | Type check |
| `python tool/validate_sql_syntax.py` | PASS — 36 migration, 0 xato | Parser; runtime'ni almashtirmaydi |
| `node tool/database/verify_stage1_db.mjs` | PASS — 36 migration, 24 runtime guruhi | Lokal PGlite; to'liq Supabase staging emas |
| Verification SQL parseri | PASS — ikkala fayl bitta SELECT statement | SQL source va READ ONLY runtime ikkalasi tekshirildi |
| Migration takror qo'llash va rollback | PASS | Lokal eski/yangi/unknown/NULL kontent, auth va booking testlari |
| Metadata tekshiruvining salbiy sinovi | PASS | Ustun/RLS/trigger/legal matn buzilganda tegishli bandlar rad etdi |
| Signing ma'lumotisiz release build | PASS — kutilgan rad etish | `Release signing is required` |
| Vaqtinchalik lokal sertifikat bilan release APK | PASS — build, `apksigner`, secret-pattern scan | Production signing NOT VERIFIED |

Yakuniy loglar: `build/stage1_continue/analyze.log`, `flutter-tests.log`,
`deno-tests.log`, `sql-baseline.log`, `db-final.log`, `apk-missing-signing.log`,
`apk-local-signing.log`. `db-baseline.log` eski 22 guruhli natija;
24 guruhli yakuniy natija `db-final.log`da. `git diff --check` o'tdi.

APK: `build/app/outputs/flutter-apk/app-release.apk`.
SHA-256: `75990acb59727f800469737f5b3ffdb400d652c7c78c7f1fb653f9811f64279d`.
Sertifikat: `CN=LexHub Local Verification Only`.
Sertifikat SHA-256: `e806bf12218f2d82027a29681b188e0b2b3002d21dcd1426c00c3b3f80a806ae`.
Vaqtinchalik kalit o'chirildi. APK production tarqatishga tasdiqlanmagan.
Google/Supabase secret/private key/service-role JWT patternlari: 0 topilma.
Bu patternlar barcha mumkin bo'lgan sirlar yo'qligini isbotlamaydi.

## 4. PRODUCTIONDA TEKSHIRILDI

| Band | Real dalil | Holat |
|---|---|---|
| Loyiha identifikatsiyasi | MCP `project_ref` va Management API loyiha ID'si lokal prod konfiguratsiyasiga mos; loyiha LexHub, ACTIVE_HEALTHY | VERIFIED — identity |
| Sessiya xavfsizligi | `supabase_read_only_user`, `transaction_read_only=on`, PostgreSQL 17.6 | VERIFIED — read-only sessiya |
| Backup/PITR metadata | `pitr_enabled=false`, `walg_enabled=true`, `backups=null`, `physical_backup_data={}` | VERIFIED — API'dagi shu holat; recovery tasdig'i emas |
| Migration history | 27 production yozuv; ikkita yangi Stage 1 version yo'q; repository'da 36 migration | VERIFIED — metadata |
| RLS | Answers, expert_profiles, profiles, questions, consultations uchun yoqilgan | VERIFIED — metadata; authorization runtime emas |
| Eski avtorizatsiya holati | Savol egasiga broad UPDATE, qo'shimcha permissive INSERT; expert guard UPDATE-only; yangi restrictive policylar soni 0 | VERIFIED — zaiflikka olib keluvchi konfiguratsiya |
| Huquqiy kontent | Eski MK 560 matni mavjud; reviewed content/reference tekshiruvlari false | VERIFIED — eski kontent mavjudligi |
| Preflight SQL | 10/10 true | VERIFIED — maqsadli prerequisite metadata |
| Postflight SQL, hali apply qilinmagan bazada | 2/8 true; guard ACL, write guard, restrictive policy va uch legal reference/content bandi false | VERIFIED — hozirgi holat kerakli yakuniy holatga mos emas |
| Edge Function | `legal-ai` v42 ACTIVE, verify_jwt=true; API orqali olingan 4 TS faylda narrative guard yo'q | VERIFIED — deploy source inspection, real-model runtime emas |
| Vercel | Repo root/Other, Production Branch main; READY target commit `619534e` | VERIFIED — deployment metadata; yangi client tuzatishlari unda yo'q |

Yuklab olingan Edge entrypoint SHA-256:
`5038d7602ecd1480c37ed0c3f3a36bd2a06bf6a4f05d4f9bcc61a727a1625416`.
Source o'qildi, funksiya chaqirilmagan/deploy qilinmagan.

## 5. PRODUCTIONDA TEKSHIRILMADI

- Backupni muvaffaqiyatli restore qilish, recovery window/RPO/RTO va PITR tiklash:
  **NOT VERIFIED**. API backup ro'yxatini bermadi; bundan barcha provider
  backup'lari umuman yo'q degan xulosa chiqarilmaydi.
- To'liq Supabase staging/PostgREST/Auth smoke: **BLOCKED** — mavjud alohida
  staging project/branch/config topilmadi. Lokal PostgreSQL testi bajarildi.
- P1-06/P1-07 authorization'ning production'dagi ijobiy/salbiy write sinovlari:
  **NOT VERIFIED**, chunki production READ-ONLY.
- Yangi client guard, yangi server narrative guard va migrationlarning
  production runtime'i: **NOT VERIFIED**, bu ish davomida chiqarilmadi.
- Haqiqiy production signing: **BLOCKED** — `android/key.properties`, to'rtta
  signing env qiymati va repository keystore'i mavjud emas.
- Tarixiy credentiallar revoked/rotated ekanligi: **NOT VERIFIED**.
  Eski credential bilan login qilinmadi, hisoblar o'zgartirilmadi.

## 6. QOLGAN ISHLAR

Oldingi implementatsiyaning fayllari va batafsil root cause'lari
[dastlabki hisobot](STAGE1_RESULTS.md)da; quyidagi natijalar joriy qayta
tekshiruvga tegishli. Yangi o'zgargan fayllar 2-bo'limda sanalgan.

| Item | Asl sabab va repository natijasi | Regression / natija | Qolgan xavf / holat |
|---|---|---|---|
| P1-01 | Tarqalgan eski muddat/havolalar; korpus/prompt/service/template va `20260919002000` kontent migrationi tekshirildi | `stage1_legal_regression_test.dart`, legal safety/RAG va lokal SQL kontent ssenariylari: PASS | Production eski kontent; PARTIALLY VERIFIED |
| P1-02 | Erkin model prose hamda metadata tekshiruvni chetlab o'tgan; guard/datasource tuzatildi, 2 yangi regression bor | `legal_narrative_guard_test.dart`, `stage1_legal_regression_test.dart`, Deno narrative/handler: PASS | Server v42 eski; client o'zgarishi ham chiqarilishi kerak; PARTIALLY VERIFIED |
| P1-03 | Unknown faktni tasdiqlangan deb olish, risk pasayishi va modelning user query'ni almashtirishi; haqiqiy query saqlanadi | `stage1_legal_regression_test.dart`, `legal_safety_test.dart`, Dart/Deno narrative: PASS | Risk hanuz dastlabki baho; PARTIALLY VERIFIED, production scenario NOT VERIFIED |
| P1-04 | Draftni qonun manbasi sifatida ko'rsatish va modelning draft yorlig'ini soxtalashtirishi; ajratish/testlar saqlandi | `document_draft_safety_test.dart` va yangi metadata regressiyasi: PASS | Client yangilanishi kerak; PARTIALLY VERIFIED |
| P1-05 | Umumiy Hive tarixidan hisoblararo o'qish; hisob scope'i bilan ajratilgan oqim tekshirildi | `local_case_account_isolation_test.dart`: 6 lokal disk ssenariysi PASS | Real qurilma/auth smoke va disk shifrlashi qamralmagan; PARTIALLY VERIFIED |
| P1-06 | RLS/trigger faqat accept maydonini yetarlicha chegaralamagan; `20260919001000` candidate tekshirildi | `stage1_database_contract_test.dart`, lokal SQL muallif/egasi/moderator va impersonation ssenariylari: PASS | Production tuzatilmagan; PARTIALLY VERIFIED |
| P1-07 | Sensitive trigger INSERT'ga ulanmagan; `20260919001000` candidate tekshirildi | Lokal SQL first INSERT, booking, approval, license va cooldown ssenariylari: PASS | Production tuzatilmagan, oldingi ekspert qiymatlari tekshirilishi kerak; PARTIALLY VERIFIED |
| P1-08 | Debug signing fallback; fail-closed konfiguratsiya va lokal test APK tekshirildi | Kalitsiz rad etish, vaqtinchalik sertifikatli build, `apksigner`, secret-pattern scan: PASS | Real production key yo'q; BLOCKED |
| P1-09 | History/DDL drift va toza replay prerequisites; bootstrap va pre/post SQL tayyor | SQL parser 36 migration; lokal runner 24 guruh, takror qo'llash va rollback: PASS | PARTIALLY VERIFIED; backup/restore va staging NOT VERIFIED; production gate BLOCKED |
| P2-12 | Tarixiy test credential literal'i 16 faylda topildi | 1 097 matn blob skani; 16 commit/fayl snapshotida ichki taqqoslash bajarildi | PARTIALLY VERIFIED; faol hisoblar va rotation NOT VERIFIED; qiymatlar chiqarilmadi |

### Credential history — qiymatlarsiz dalil

Tekshiruv barcha mavjud Git ref'laridagi 2 MBgacha binary bo'lmagan bloblarni
qamradi: 1 097 ta matn blob. Ma'lum sirqib chiqqan test paroli 33 blob versiyasi,
16 fayl yo'lida uchradi. Bu 33 xil parol yoki 16 ta faol account degani emas.
Qo'shimcha generic password topilmalari orasida unit/example fixture'lar bor.
Tekshirilgan Google/GitHub/Supabase privileged-key/private-key/DB-URL patternlari
bo'yicha alohida topilma yo'q; bu barcha sirlar yo'qligining mutlaq isboti emas.

Har bir quyidagi commit/fayl snapshoti qayta o'qilib, topilma mavjudligi ichki
taqqoslash bilan tasdiqlandi. Credential qiymati hisobot yoki logga chiqarilmadi.

| Commit | Fayl | Credential turi |
|---|---|---|
| `e4ecf964beafb082640af02bf82ab0c3f12073e4` | `test/integration/cleanup_live_test_data_test.dart` | Tarixiy test hisob paroli |
| `ee2bac08d8b806d392442bcee255f3d6ea36d588` | `test/integration/community_write_session_rls_live_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/debug_signup_repro_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/forensic_auth_split_diagnosis_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/forensic_db_triggers_and_schema_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/real_db_error_diagnostic_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/real_supabase_e2e_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/real_supabase_signup_cloud_verification_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/verify_community_answer_live_test.dart` | Tarixiy test hisob paroli |
| `dc53e270c631eac3c569f77ce67be04f01d51835` | `test/integration/verify_legal_ai_proxy_live_test.dart` | Tarixiy test hisob paroli |
| `e4ecf964beafb082640af02bf82ab0c3f12073e4` | `test/integration/verify_mvp_blockers_live_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/verify_profile_invariant_live_test.dart` | Tarixiy test hisob paroli |
| `8c463507f2560fe6a84f7f4e89b5e6ed726ba9af` | `test/integration/verify_rate_limit_error_mapping_test.dart` | Tarixiy test hisob paroli |
| `ac095f4ad1580ac34bf9bcc01dea4cd221892044` | `tool/probe_creds.py` | Tarixiy test hisob paroli |
| `740f3b1e0df74e4346367799cfeecfb7557828e4` | `tool/probe_legal_ai_latency.py` | Tarixiy test hisob paroli |
| `7aa255fc9b176e38decf8ba96b348e8c65299101` | `tool/probe_legal_ai_model.py` | Tarixiy test hisob paroli |

Hammasining turi: tarixiy test hisob paroli. Xavf: tegishli hisob hanuz faol
bo'lsa yuqori. Revoke/rotate: tegishli hisoblar egasi tekshirishi va zarur
rotationni bajarishi kerak; bajarilganligi NOT VERIFIED. Git tarixini qayta
yozish credentialni bekor qilmaydi. Bu ishda history rewrite qilinmadi.

## 7. KEYINGI ENG XAVFSIZ QADAM

1. Backup/recovery dalilini olish va alohida staging'ga tiklash mashqini bajarish.
   Hozir production migration gate yopiq. Read-only preflight 10/10 bo'lishi
   bu talab o'rnini bosmaydi.
2. [Database runbook](STAGE1_DATABASE.md) bo'yicha staging'da tekshirib, aniq
   alohida ruxsatdan so'ng faqat `20260919001000` → `20260919002000` tartibini
   qo'llash. **REQUIRES EXPLICIT APPROVAL.** Avtomatik APPLY yoki `db push` yo'q.
3. Production signing key va credential rotationni tegishli egalar bilan
   yakunlash; yangi client/Edge Functionni alohida tasdiqlangan release'da
   chiqarib, real runtime tekshiruvini bajarish. **REQUIRES EXPLICIT APPROVAL.**
