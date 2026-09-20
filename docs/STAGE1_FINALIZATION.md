# Stage 1 repository finalization — 2026-09-20

> Bu hisobot repository checkpoint commitidan oldingi tekshiruv snapshotidir.
> Quyidagi HEAD/working-tree va commit/push holati shu snapshotga tegishli.
> Keyingi checkpointni Git tarixidan tekshiring; commit yoki branch push
> production migration/release gate'ini ochmaydi.

**Repository: PARTIALLY VERIFIED. Production migration gate: BLOCKED.**
Branch `audit/stage1-production-preflight`; boshlang'ich va yakuniy HEAD
`909870fbdc508641bc6884f78336b94dfc8c1aba`. O'zgarishlar working tree'da qoladi.
`main` (`619534e`) va rollback checkpoint `9ce9f10` saqlangan. Commit/amend,
push, history rewrite, deploy, production migration/backup/restore, credential
rotation yoki session invalidation bajarilmadi.

## P1 va P2-12 dalillar jadvali

Asl sabablar va oldingi implementatsiya: [STAGE1_RESULTS.md](STAGE1_RESULTS.md).
Quyidagi PASS faqat ko'rsatilgan lokal test qatlamiga tegishli; ishlab turgan
production tuzatilganini bildirmaydi.

| Item | Repository fix / regression | Joriy holat va yetishmayotgan dalil |
|---|---|---|
| P1-01 | Reviewed 560/27/28/29 korpus, service/template, calendar-month qoidasining `stage1_legal_regression_test.dart` va SQL kontent testlari PASS; postflight step/body matni bilan kuchaytirildi | PARTIALLY VERIFIED; production kontent migrationi, embedding refresh va real source/deadline smoke kerak. Butun korpus qayta huquqiy ekspertizadan o'tkazilmadi |
| P1-02 | Dart/Edge narrative allowlist, manba/fallback va forged metadata regressiyasi; Dart hamda Deno HTTP-handler testlari PASS | PARTIALLY VERIFIED; yangi Edge/client deploy va haqiqiy model javobidagi manba/qadam/negative-case evidence kerak. Oldingi production v42 snapshotida yangi guard yo'q |
| P1-03 | Unknown fakt, asl query identity, yuqori riskni saqlash va asossiz countdownni olib tashlash regressionlari PASS | PARTIALLY VERIFIED; real clientda foydalanuvchi faktlari bilan end-to-end smoke kerak. Risk yuridik ekspertiza deb kafolatlanmaydi |
| P1-04 | Draft/source ajratish, serialization, haqiqiy Preview Save va saved/recent draft UI testlari PASS | PARTIALLY VERIFIED; yangi client/qurilmada eksport/save oqimi kerak; hujjat rasmiy qonun manbasi emas |
| P1-05 | Account scope, diskdagi Hive A/B/guest/legacy/reopen/delayed-response 6 ssenariysi PASS | PARTIALLY VERIFIED; ikki haqiqiy test hisob bilan qurilmada account switch smoke kerak. Disk shifrlashi bu fix emas |
| P1-06 | Candidate'da answer authorship INVOKER guard, restrictive RLS, accept/edit/switch; lokal authenticated/anon/moderator ssenariylari PASS | PARTIALLY VERIFIED; production candidate qo'llanmagan. Izolyatsiyalangan staging Auth/PostgREST ijobiy/salbiy amallari, keyin tasdiqlangan production metadata/runtime dalili kerak |
| P1-07 | Expert first INSERT va verification/rating/rejection/cooldown guard, approved booking fee testlari PASS | PARTIALLY VERIFIED; staging API dalili va mavjud production ekspertlarning eski sezgir maydonlari review'i kerak |
| P1-08 | Release-only signing, env/properties kontrakti, debug filename tekshiruvi kuchaytirildi; yangi 2 regression testi PASS | PARTIALLY VERIFIED repository; haqiqiy production signing BLOCKED. App egasining key'i, kutilgan cert SHA-256, imzolangan artifact va update smoke kerak |
| P1-09 | 36 migration bootstrap/replay, takror apply/rollback, 25 lokal DB regression guruhi PASS; pre/postflight bitta SELECT va READ ONLY transactionda sinaldi | PARTIALLY VERIFIED; 7 history gap, full Supabase staging, recovery/restore va production history/DDL reconciliation hali ochiq |
| P2-12 | Current HEAD/WT credential-pattern skani, helper/fixture/fingerprint regressiyasi PASS; real credential/fingerprint testda saqlanmaydi | PARTIALLY VERIFIED; history exposure yopilmagan. H01 rotation/global session revoke, C01 real identity/reuse NOT VERIFIED |

## Ushbu davomda tuzatilgan kamchiliklar

1. **Preview isolation.** Build uchta public client parametrni tekshirardi,
   lekin Preview va Production bir backend ekanini rad etmasdi. Endi Preview
   production URL control qiymatini talab qiladi, bir xil DB hosti va boshqa
   project AI endpointini rad etadi. Production kontrakti o'zgarmadi.
2. **Postflight qamrovi.** Metadata/URL yaxshi bo'lsa ham service 3-qadamidagi
   eski muddat, shablon body ichidagi eski modda yoki noto'g'ri acceptance trigger
   o'tishi mumkin edi. Endi aniq step/warning/body hamda trigger type/function
   tekshiriladi. Testdagi 7 corruption holati aniqlanadi va ROLLBACK qilinadi.
3. **Debug filename.** Signing guard `/debug.keystore` suffix'ini tekshirardi;
   yalang'och `debug.keystore` va harf registri farqi o'tib ketishi mumkin edi.
   Endi Windows/Linux basename registrdan mustaqil tekshiriladi. Qayta nomlangan
   test certini aniqlash uchun baribir mustaqil expected fingerprint kerak.
4. **Credential aniqligi.** C01 uchun noto'g'ri email target va 0 account dalili,
   H01 uchun production probe identity/session metadata kiritildi. Oldingi
   rotation da'vosi mustaqil tasdiqlanmagan deb belgilandi. Credential/helper
   runtime'i o'zgartirilmadi; faqat hujjat va probe kommentariyasi yangilandi.

## Migration, staging va deployment readiness

- Ikkala candidate migrationning baytlari bu davomda o'zgarmadi. Tartib:
  `20260919001000_stage1_authorization_and_booking.sql` →
  `20260919002000_reviewed_legal_excerpts_and_deadlines.sql`.
- MCP `list_migrations` bu davomda 27 yozuvni tasdiqladi; candidate'lar yo'q.
  Schema/RLS/legal compatibility oldingi 2026-09-20 read-only snapshotiga
  tayangan; joriy preflight/postflight production'da bajarilmadi.
- Joriy preflight 10/10, postflight 9/9 faqat lokal DBda PASS. Eski production
  2/8 postflight natijasi yangi SQL uchun dalil emas. Recovery va history gate,
  transaction/forward-fix tartibi: [STAGE1_DATABASE.md](STAGE1_DATABASE.md).
- Ajratilgan staging project/config hali tashqi admin ishi. `env/dev.json`
  production bilan bir xil; yangi `env/staging.json.example` va [STAGING.md](STAGING.md)
  tayyor. Shared Preview yangi build guardidan o'tmaydi; bu kutilgan rad etish.
- `vercel.json`: Other, `python3 tool/vercel_build.py`, `build/web`, main enabled.
  Lokal pinned SDK/lockfile build PASS. Remote Git/env target/override, haqiqiy
  push-trigger, source SHA, alias HTTP/assets va rollback artifacti NOT VERIFIED;
  admin [DEPLOY.md](DEPLOY.md) bo'yicha qiymatlarni chiqarmasdan tasdiqlaydi.
- APK real signing: [RELEASE_SIGNING.md](RELEASE_SIGNING.md). Yangi production
  keystore yoki CI workflow yaratilmadi. Oldingi test-key APK production isboti emas.
- Credential admin action/config/global-revoke/post-rotation mezonlari:
  [STAGE1_CREDENTIAL_RECOVERY.md](STAGE1_CREDENTIAL_RECOVERY.md).

## Lokal testlar

| Tekshiruv | Natija |
|---|---|
| `flutter analyze --no-pub` | PASS, No issues found |
| Relevant Flutter security/legal/draft/expert/deploy | PASS, 298 test |
| `flutter test --no-pub --reporter expanded` | PASS, 998 test, 27 gated skip |
| Yakuniy security suite | PASS, 141 test; debug fallback mutatsiyasi expected FAIL, source baytma-bayt tiklangach PASS |
| Python build runner | PASS, 16 test; Preview guard olib tashlanganda 12 expected failure, tiklangach PASS |
| Deno grounding/model chain/narrative/HTTP handler | PASS, 31 test / 2 step; real Auth/Gemini chaqiruvi emas |
| `deno check --no-lock supabase/functions/legal-ai/index.ts` | PASS |
| SQL parser | PASS, 36 migration / 0 xato; ikkala verification SQL bitta SELECT |
| Local PostgreSQL/PGlite | PASS, 36 migration replay; 25 regression guruhi, 7 yangi corruption holati |
| Postflight mutation | Deadline tekshiruvi olib tashlanganda expected FAIL; baytma-bayt tiklangach PASS |
| Lokal Vercel build | PASS, pinned SDK va `pub get --enforce-lockfile`; uchta majburiy web artifact bo'sh emas |
| APK signing negative build | PASS: kalitsiz, nisbiy `debug.keystore`, Windows/Linux debug pathlarining 4 holati kerakli signing guard xatosi bilan rad etildi; real key yaratilmagan |
| Current HEAD/WT va web secret-pattern skani | Tekshirilgan privileged-key/token/private-key/digest/DB-URL patternlarida topilma yo'q; to'liq history/obfuscation scan emas |
| `git diff --check` va yakuniy analyze | PASS; staged fayl yo'q, HEAD o'zgarmadi |

Web `main.dart.js`: 4 248 729 byte,
SHA-256 `f43b7f5cbacf24fd6de199563c9bee9d4dd2c38dab591a3a8fa469ec08624f8a`.
Bu artifact digest, credential fingerprinti emas. Web yig'ildi, deploy qilinmadi.
Lokal evidence loglari `build/stage1_parallel/`da, Git'ga kirmaydi.

## Working tree manifesti

11 modified va 4 yangi fayl; generated/build/temp fayllar commit scope'iga kirmaydi.
Staged fayllar yo'q, commit/push qilinmadi.

```text
android/app/build.gradle.kts
docs/DEPLOY.md
docs/RELEASE_SIGNING.md
docs/STAGE1_CREDENTIAL_RECOVERY.md
docs/STAGE1_DATABASE.md
docs/STAGE1_FINALIZATION.md (new)
docs/STAGING.md (new)
env/staging.json.example (new)
supabase/verification/stage1_preflight.sql
supabase/verification/stage1_postflight.sql
test/core/security/release_signing_config_test.dart (new)
tool/database/verify_stage1_db.mjs
tool/probe_creds.py
tool/test_vercel_build.py
tool/vercel_build.py
```

## Production migration gate va keyingi 3 action

**BLOCKED:** avvalgi snapshotda PITR OFF; backup/retention/restore rehearsal
dalili yo'q, ajratilgan staging/Auth/PostgREST dalili yo'q, 7 history gap ochiq.
Current local PASS bu talablarni almashtirmaydi. Alohida production ruxsatisiz
APPLY boshlanmaydi; ushbu hujjat ruxsat emas.

1. **P1 security admin:** H01 accountning rotation/global-revoke dalilini
   yakunlash; C01 real account/reuse borligini aniqlash. Repository ishini kutdirish
   shart emas, ammo incident yopildi deb yozish uchun dalil kerak.
2. **P1 DB admin:** ajratilgan staging va recovery rehearsal, history/DDL review,
   candidate upgrade + Auth/PostgREST negative-case dalillari bilan gate tayyorlash.
3. **Release owner:** diff review; haqiqiy signing key va Vercel Preview/Production
   env verifikatsiyasi; client/Edge/database release'ini alohida tasdiqlash.
