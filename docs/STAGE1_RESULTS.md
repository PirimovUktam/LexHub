# LexHub — 1-bosqich tuzatishlari natijasi

Sana: 2026-09-19. **Umumiy holat: PARTIALLY VERIFIED.**

P1-01–P1-09 bo‘yicha repository tuzatishlari va lokal tekshiruvlar yakunlandi.
P2-12 doirasida Git tarixidagi test credentiallar tekshirildi; boshqa P2 ishlari
bajarilmadi. Production database faqat Supabase MCP orqali o‘qildi. Remote
migration, deploy, yozish amali va commit bajarilmadi.

Bu bosqich boshlanishida mavjud Home redizayni va boshqa commit qilinmagan
o‘zgarishlar saqlandi. Quyidagi fayllar ro‘yxati butun `git diff` emas, aynan
ushbu bosqich boshlanishidagi holatga nisbatan o‘zgargan fayllardir.

## Umumiy tekshiruv natijalari

| Tekshiruv | Natija | Dalilning chegarasi |
|---|---|---|
| `flutter analyze --no-pub` | `No issues found!`, exit 0 | Statik tahlil |
| `flutter test --no-pub --reporter expanded` | 989 o‘tdi, 27 skip, 0 xato | Production yozuv testlari yoqilmadi; skip PASS hisoblanmaydi |
| Deno: grounding, model chain, narrative, haqiqiy HTTP handler | 31 test, 2 ichki ssenariy o‘tdi, 0 xato | Auth/Gemini transporti lokal almashtirilgan; real model/deploy isboti emas |
| `deno check --no-lock supabase/functions/legal-ai/index.ts` | Exit 0 | Type check |
| `python tool/validate_sql_syntax.py` | 36 fayl, 0 xato | Parser natijasi runtime o‘rnini bosmaydi |
| `node tool/database/verify_stage1_db.mjs` | 36 migration replay, 22 runtime regression guruhi o‘tdi | In-memory PostgreSQL/PGlite; Supabase xizmatlari va production emas |
| Flutter DB contract testlari | 7 test o‘tdi | Umumiy 989 test ichida hisoblangan |
| Himoyalarni ataylab buzib tekshirish | 16 mutatsiya QIZIL natija berdi | DB 8, huquqiy oqim 4, scope/narrative/draft 3, HTTP handler 1; manbalar baytma-bayt tiklandi |
| Release signing ma’lumotisiz build | Kutilgan xato bilan to‘xtadi | Debug imzosiga yashirin qaytish yo‘q |
| Vaqtinchalik lokal sertifikat bilan release APK | Build o‘tdi; `apksigner` exit 0 | Production imzosi emas; tarqatish uchun tasdiqlanmagan |
| Yig‘ilgan APK ichidagi secret skani | Tekshirilgan Google key, Supabase secret, private key va service-role JWT patternlari: 0 topilma | Pattern skani barcha mumkin bo‘lgan sirlar yo‘qligini isbotlamaydi |
| `git diff --check` | Whitespace xatosi yo‘q | Git LF/CRLF ogohlantirishlari mavjud |
| Supabase MCP yakuniy `SELECT` | 23 public jadval, 27 history yozuvi, yangi 2 migrationdan 0 tasi history’da | Production tuzatilmadi |

Deno buyrug‘i:

```powershell
deno test --no-lock --allow-env --allow-net=deno.land,jsr.io supabase/functions/legal-ai/grounding_test.ts supabase/functions/legal-ai/model_chain_test.ts supabase/functions/legal-ai/narrative_guard_test.ts supabase/functions/legal-ai/index_contract_test.ts
```

HTTP handler mutatsiyasidan keyin manba SHA-256 bilan tiklandi va handler testi
qayta o‘tdi. Dependency yuklash domenlaridan tashqari haqiqiy Auth/Gemini yoki
database yozuvi bajarilmadi.

## Har bir muammo bo‘yicha natija

### P1-01 — noto‘g‘ri muddatlar va modda havolalari

- **Asl sabab:** client korpusi, xizmat/shablon matnlari, promptlar va server
  kontentidagi bir xil normalar turlicha va eskirgan shaklda saqlangan.
- **Tuzatish:** MK 560 uchun ishga tiklash muddati buyruq ko‘chirma nusxasi
  topshirilgan kundan uch kalendar oy deb moslashtirildi; tegishli olti oylik
  qoida/istisnolar ajratildi. Uch oy 90 kun deb hisoblanmaydi. Konstitutsiya
  27/28/29 havolalari tuzatildi. Mehnat shablonidagi aloqasiz 437 o‘rniga
  561-modda havolasi qo‘yildi. Server kontenti uchun SQL tayyorlandi.
- **Fayllar:** quyidagi ro‘yxatdagi huquqiy korpus, ikki prompt, deadline,
  citizen service, document template, ARB/generated lokalizatsiya va
  `20260919002000` migration fayllari.
- **Testlar:** `stage1_legal_regression_test.dart`, emergency/legal safety/RAG
  testlari va DB kontent regressionlari; rasmiy LexUZ sahifalari bilan solishtirildi.
- **Holat:** PARTIALLY VERIFIED — lokal matn va oqim tekshirildi; production
  kontenti hanuz eski. Faqat tekshirilgan normalar qamrab olindi, butun korpus emas.
- **Production ishi/xavf:** kontent migrationini staging tekshiruvidan keyin
  alohida qo‘llash va o‘zgargan chunk embeddinglarini qayta hisoblash kerak.

Rasmiy manbalar: [MK 560](https://lex.uz/docs/6257288#6269139),
[MK 561](https://lex.uz/docs/6257288#6269151),
[Konstitutsiya 27](https://lex.uz/docs/6445145#6445434),
[28](https://lex.uz/docs/6445145#6445509),
[29](https://lex.uz/docs/6445145#6445518). Tekshiruv sanasi: 2026-09-19.

### P1-02 — AI xulosasi va harakatlar rejasini tekshirish

- **Asl sabab:** modda ro‘yxatini kontekst bilan tekshirish erkin summary,
  qadamlar va risk matnidagi huquqiy da’volarni qamrab olmagan.
- **Tuzatish:** Dart va Edge Function guardlari modeldan faqat manba tanlovini
  oladi; xulosa va qadamlar tanlangan kontekst bilan bog‘lanadi. Erkin model
  da’volari, taxminiy deadline va kafolatlar o‘tkazilmaydi. Dalil yetarli bo‘lmasa
  oshkora deterministic fallback ishlaydi. Uzun parcha kesib buzilmaydi — to‘liq
  matn huquqiy asoslarda qoladi. Proxy, direct Gemini va legacy oqim qamrab olindi.
- **Fayllar:** `legal_narrative_guard.dart`, `narrative_guard.ts`,
  `gemini_legal_service.dart`, `legal_assistant_remote_datasource.dart`,
  `legal-ai/index.ts`, ikki prompt va lokalizatsiya.
- **Testlar:** Dart narrative testlari; Deno narrative va haqiqiy `Deno.serve`
  handlerini chaqiruvchi `index_contract_test.ts`; da’vo o‘tkazish mutatsiyasi ushlandi.
- **Holat:** PARTIALLY VERIFIED — lokal runtime o‘tdi; real model/deployment
  NOT VERIFIED. Bu ongli cheklov: erkin huquqiy maslahat o‘rniga dalilga bog‘langan
  manba ko‘rigi beriladi. Kontekstga moslik uning rasmiyligi, dolzarbligi yoki
  vaziyatga to‘g‘ri tatbiqini o‘z-o‘zidan kafolatlamaydi.
- **Production ishi/xavf:** Edge Function va yangi clientni alohida chiqarish
  kerak. Yangi client eski server javobini ham cheklaydi; eski clientlar bundan
  foydalanmaydi. Korpus sifati va tanlangan manbaning aloqadorligi bo‘yicha xavf qoladi.

### P1-03 — foydalanuvchi faktlari va risk

- **Asl sabab:** yozma dalil mavjudligi oldindan `true` deb olingan, evristika
  modelning yuqori riskini pasaytirishi va tasdiqlanmagan muddat chiqarishi mumkin edi.
- **Tuzatish:** unknown fakt saqlanadi; yuqori risk va yurist talabi yo‘qolmaydi;
  voqea boshlanish sanasi aniqlanmasa `deadlineDays=null`. Izohlar UZ/EN ARB’da.
- **Fayllar:** `risk_matrix_evaluator.dart`, `deadlines_guard.dart`,
  `legal_assistant_remote_datasource.dart`, narrative guardlar va lokalizatsiya.
- **Testlar:** `stage1_legal_regression_test.dart`, `legal_safety_test.dart`,
  Dart/Deno narrative testlari; noaniq dalil va riskni pasaytirish holatlari qamralgan.
- **Holat:** PARTIALLY VERIFIED — lokal runtime tekshirildi; real foydalanuvchi
  faktlari bilan yakuniy huquqiy baho tasdiqlanmadi.
- **Production ishi/xavf:** yangi client/server versiyasini chiqarish kerak.
  Risk dastlabki ehtiyotkor baho bo‘lib qoladi, yuridik ekspertiza emas.

### P1-04 — tayyor hujjatni qonun manbasidan ajratish

- **Asl sabab:** tayyorlangan matn `LawArticle` sifatida saqlanib, rasmiy manba
  va to‘liq huquqiy muvofiqlik taassurotini bergan.
- **Tuzatish:** `source=document_template` va `documentText` ajratildi;
  draftning `legalBasis` va asossiz action plan’i bo‘sh. Preview, Saved va Recent
  ko‘rinishlarida draft matni/disclaimer beriladi; qonun/AI/risk kartalari
  chiqarilmaydi. “Rasmiy Hujjat” va tekshirilmagan kafolatlar olib tashlandi.
- **Fayllar:** `legal_response.dart`, `document_preview_page.dart`, yangi
  `document_draft_content.dart`, `saved_cases_page.dart`, `recent_cases_feed.dart`,
  tegishli ARB/generated fayllar.
- **Testlar:** `document_draft_safety_test.dart` — serialization, draft UI va
  haqiqiy Preview Save; guarantee va Home regression assertionlari yangilandi.
- **Holat:** PARTIALLY VERIFIED — widget/runtime tekshirildi; qurilmada to‘liq
  eksport oqimi qayta sinalmadi. Legacy entity’dagi majburiy risk maydoni
  compatibility uchun qoldi, draft UI uni ko‘rsatmaydi.
- **Production ishi/xavf:** client yangilanishi kerak; tayyor hujjat mazmunini
  foydalanuvchi/yurist tekshirishi zarur.

### P1-05 — mahalliy tarixni hisoblar bo‘yicha ajratish

- **Asl sabab:** Hive kalitlari va o‘qish/o‘chirish amallari hisob doirasi bilan
  chegaralanmagan, eski private route/state hisob almashganda qolishi mumkin edi.
- **Tuzatish:** `account:<userId>` va yangi guest sessiya scope’i; scope bilan
  Hive key/read/delete; boshlang‘ich hisobga bog‘langan kechikkan AI javobi;
  hisob almashganda route/BLoC state qayta yaratiladi. Egasi noma’lum legacy
  yozuvlar o‘chirilmaydi va tasodifiy hisobga berilmaydi — ko‘rinishdan yashiriladi.
- **Fayllar:** `local_case_scope.dart`, DI, `main.dart`, local datasource,
  repository, entity, BLoC va document preview.
- **Testlar:** `local_case_account_isolation_test.dart` — haqiqiy vaqtinchalik
  Hive diskida 6 ssenariy: A/B, logout/guest, legacy, reopen, kechikkan javob,
  token refresh. Scope filtrini olib tashlash mutatsiyasi testlarda ushlandi.
- **Holat:** PARTIALLY VERIFIED — lokal disk isboti bor; real qurilmada ikki
  production hisob bilan end-to-end sinov bajarilmadi.
- **Production ishi/xavf:** client yangilanishi kerak. Hive shifrlanmagan;
  qurilma fayllariga kirishdan himoya bu tuzatishning natijasi emas.

### P1-06 — Community javobini tahrirlash avtorizatsiyasi

- **Asl sabab:** production UPDATE policy savol egasiga javobning barcha
  maydonlarini tahrirlashga yo‘l qo‘ygan; acceptance trigger faqat bitta maydonni
  tekshirgan. Qo‘shimcha permissive INSERT policy muallifni tekshirmagan.
- **Tuzatish:** INVOKER guard va restrictive RLS; muallif/identitet/counter
  himoyasi. Savol egasining accept PATCH’i, muallif va moderator tahriri saqlanadi.
- **Fayllar/testlar:** `20260919001000_stage1_authorization_and_booking.sql`,
  `stage1_database_contract_test.dart`, lokal SQL runner/fixture.
- **Holat:** PARTIALLY VERIFIED — lokal authenticated rolida ijobiy/salbiy
  ssenariylar o‘tdi; production himoyasi NOT VERIFIED va qo‘llanmagan.
- **Production ishi/xavf:** migrationni alohida qo‘llab, PostgREST orqali
  ikki hisob/moderator bilan qayta tekshirish kerak. Hozirgi production zaifligi qoladi.

### P1-07 — Expert profilining birinchi INSERT’i

- **Asl sabab:** sensitive field trigger faqat UPDATE’da ishlagan; INSERT RLS
  faqat `user_id`ni tekshirgan. Booking faqat expert `verified_at`ga ishongan.
- **Tuzatish:** INSERT pending/unrated bo‘lishi shart; tasdiq/reytingni client
  bera olmaydi. License, rejection va cooldown himoyalari saqlanadi. Booking
  tasdiqlangan profil rolini tekshiradi va majburiy haqiqiy `fee`ni ham yozadi.
- **Fayllar/testlar:** P1-06 migration/runner/contractlari;
  `expert_apply_cooldown_test.dart`, `expert_verification_invariant_test.dart`.
- **Holat:** PARTIALLY VERIFIED — lokal SQL runtime o‘tdi; production NOT VERIFIED.
- **Production ishi/xavf:** migrationni qo‘llash va mavjud ekspertlarning oldingi
  verification/rating qiymatlarini alohida tekshirish kerak. Migration mavjud
  shubhali yozuvlarni taxmin bilan o‘zgartirmaydi.

### P1-08 — release signing

- **Asl sabab:** release build debug signing konfiguratsiyasidan foydalangan.
- **Tuzatish:** lokal properties yoki CI secret env orqali release signing;
  ma’lumot yetishmasa build to‘xtaydi. Debug fallback olib tashlandi.
- **Fayllar:** `android/app/build.gradle.kts`, `android/key.properties.example`,
  [RELEASE_SIGNING.md](RELEASE_SIGNING.md).
- **Testlar:** kalitsiz buildning rad etilishi, vaqtinchalik test sertifikati
  bilan release APK, `apksigner`, APK hash va secret skani.
- **Holat:** PARTIALLY VERIFIED. Haqiqiy production imzosi bilan build
  **BLOCKED** — tegishli signing key mavjud emas.
- **Production ishi/xavf:** ilova egasining haqiqiy upload/release key’i bilan
  build va kutilgan fingerprintni tekshirish kerak. Lokal test APK tarqatilmasin.

APK: `build/app/outputs/flutter-apk/app-release.apk`.
SHA-256: `0a965b828f05c4e5e0c99663ee733938443e49cc856579e0183a5855875bda44`.
Test sertifikati: `CN=LexHub Local Build Verification`; vaqtinchalik kalit saqlanmadi.

### P1-09 — migration va boshlang‘ich sxemani qayta tiklash

- **Asl sabab:** production DDL va migration history bir-biridan farqlangan;
  tarixiy replay’da zarur ustun/kataloglar yetishmagan, INSERT policy uchun
  `qual` assertioni noto‘g‘ri qo‘llangan.
- **Tuzatish:** bo‘sh lokal baza uchun tartibli `rebuild.sql`, o‘lchangan sxema
  ko‘prigi va in-memory PostgreSQL tekshiruvchi runner. Tarixiy faylda faqat
  INSERT assertioni `with_check`ka tuzatildi; `schema.sql` kirish nuqtasi aniqlashtirildi.
- **Fayllar:** `supabase/bootstrap/*`, `supabase/schema.sql`,
  `20260830100000_rls_never_enabled_tables.sql`, `tool/database/*`, DB contract
  va [STAGE1_DATABASE.md](STAGE1_DATABASE.md).
- **Testlar:** 36 migration, 23 jadval/5 kategoriya, yangi migrationlarni qayta
  ijro etish, 22 regression guruhi va 7 Flutter contract testi.
- **Holat:** PARTIALLY VERIFIED — lokal SQL replay o‘tdi. To‘liq Supabase
  restore, Auth/PostgREST xizmatlari, backup/PITR va production history reconciliation
  **NOT VERIFIED**. Oddiy `supabase db reset` ko‘prikni avtomatik bajarmaydi.
- **Production ishi/xavf:** DBA history/DDL’ni solishtirishi kerak; avvalgi 34
  repo migrationiga qarshi production history’da 27 ta bor. Eski migrationlarni
  bulk push yoki bootstrapni mavjud production bazaga qo‘llash mumkin emas.

### P2-12 — Git tarixidagi test credentiallar

- **Asl sabab:** tarixiy integration/script fayllarida literal test parollari
  mavjud. Bu faqat foydalanuvchi so‘ragan qo‘shimcha tekshiruv doirasida ko‘rildi.
- **Natija:** password o‘zgarishlariga tegishli 11 candidate commit tekshirildi;
  ular orasida oddiy unit fixture’lar ham bor. Bu 11 ta faol credential sizganini
  anglatmaydi. Hech qanday credential qiymati hisobotga chiqarilmadi.
- **Fayllar/testlar:** shu bosqichda yangi credential o‘zgarishi kiritilmadi;
  oldindan mavjud `liveTestPassword()` va `no_leaked_test_password_test.dart`
  himoyalari saqlandi va umumiy suite’da tekshirildi. Joriy integration/tool
  skanidagi qolgan literal mavjud bo‘lmagan hisobga loginning rad etilishini
  tekshiruvchi ataylab yaroqsiz qiymat; account yaratmaydi.
- **Holat:** PARTIALLY VERIFIED — tarix tekshirildi; tarixiy haqiqiy
  credentiallar bekor qilingani/almashtirilgani **NOT VERIFIED**.
- **Production ishi/xavf:** account egasi tegishli credentiallarni rotation
  qilib, eski qiymatlar ishlamasligini alohida tasdiqlashi kerak. Remote login,
  rotation va Git history rewrite bajarilmadi.

## Aynan shu bosqichda o‘zgargan/yangi fayllar

Quyidagi 55 implementatsiya/test/runbook fayli va ushbu yakuniy hisobot.
Credential tozalash va Home redizaynining oldindan mavjud boshqa diff’lari bu
ro‘yxatga bizning yangi ishimiz sifatida qo‘shilmadi.

```text
android/app/build.gradle.kts
android/key.properties.example
docs/RELEASE_SIGNING.md
docs/STAGE1_DATABASE.md
docs/STAGE1_RESULTS.md
lib/core/di/injection_container.dart
lib/core/legal_safety/deadlines_guard.dart
lib/core/legal_safety/legal_narrative_guard.dart
lib/core/legal_safety/master_system_prompt.dart
lib/core/legal_safety/risk_matrix_evaluator.dart
lib/core/legal_safety/uzbek_legal_knowledge_base.dart
lib/core/network/gemini_legal_service.dart
lib/core/storage/local_case_scope.dart
lib/features/citizen_services/data/datasources/citizen_services_local_datasource.dart
lib/features/document_builder/data/datasources/document_templates_local_datasource.dart
lib/features/document_builder/presentation/pages/document_preview_page.dart
lib/features/document_builder/presentation/widgets/document_draft_content.dart
lib/features/home/presentation/widgets/recent_cases_feed.dart
lib/features/legal_assistant/data/datasources/legal_assistant_local_datasource.dart
lib/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart
lib/features/legal_assistant/data/repositories/legal_assistant_repository_impl.dart
lib/features/legal_assistant/domain/entities/legal_response.dart
lib/features/legal_assistant/presentation/bloc/legal_assistant_bloc.dart
lib/features/saved_cases/presentation/pages/saved_cases_page.dart
lib/l10n/arb/app_en.arb
lib/l10n/arb/app_uz.arb
lib/l10n/gen/app_localizations.dart
lib/l10n/gen/app_localizations_en.dart
lib/l10n/gen/app_localizations_uz.dart
lib/main.dart
supabase/bootstrap/rebuild.sql
supabase/bootstrap/replay_prerequisites.sql
supabase/functions/legal-ai/index.ts
supabase/functions/legal-ai/index_contract_test.ts
supabase/functions/legal-ai/master_prompt.ts
supabase/functions/legal-ai/narrative_guard.ts
supabase/functions/legal-ai/narrative_guard_test.ts
supabase/migrations/20260830100000_rls_never_enabled_tables.sql
supabase/migrations/20260919001000_stage1_authorization_and_booking.sql
supabase/migrations/20260919002000_reviewed_legal_excerpts_and_deadlines.sql
supabase/schema.sql
test/core/legal_safety/emergency_detector_test.dart
test/core/legal_safety/legal_narrative_guard_test.dart
test/core/legal_safety/legal_rag_pipeline_test.dart
test/core/legal_safety/legal_safety_test.dart
test/core/legal_safety/stage1_legal_regression_test.dart
test/core/legal_safety/ungrounded_legal_guarantee_test.dart
test/core/security/local_case_account_isolation_test.dart
test/core/security/stage1_database_contract_test.dart
test/features/document_builder/document_draft_safety_test.dart
test/features/emergency_rights/presentation/pages/emergency_rights_page_test.dart
test/features/home/home_redesign_test.dart
test/features/legal_experts/expert_apply_cooldown_test.dart
test/features/legal_experts/expert_verification_invariant_test.dart
tool/database/supabase_test_environment.sql
tool/database/verify_stage1_db.mjs
```

## Alohida bajarilishi kerak bo‘lgan keyingi ishlar

1. [Database runbook](STAGE1_DATABASE.md) bo‘yicha staging sinovi, history/DDL
   reconciliation va alohida ruxsat bilan faqat ikki yangi migrationni qo‘llash;
   eski ekspert qiymatlari va o‘zgargan embeddinglarni tekshirish.
2. Yangi Edge Function/clientni chiqarish, haqiqiy signing key bilan build va
   real qurilmada hisob almashish, draft hamda AI oqimini tekshirish.
3. Tarixiy haqiqiy test credentiallarini almashtirish va eski qiymatlarning
   bekor bo‘lganini tasdiqlash.

**Production database tuzatilmadi. Repository tayyorligi production
xavfsizligi tasdiqlanganini anglatmaydi.**
