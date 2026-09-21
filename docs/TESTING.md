# LexHub testlari

## Default: lokal regression

```sh
flutter analyze
flutter test
```

Suite unit/widget, mocked repository/network, synthetic input, localization
va security regression testlarini bajaradi. Test natijasidagi PASS, failure
va skip sonlarini alohida qayd eting; vaqt o'tishi bilan sonlar o'zgaradi.

| Qatlam | Joylashuv | Nimani tasdiqlaydi |
|---|---|---|
| Unit/widget | `test/core`, `test/features`, `test/widget` | State, validation, serialization va UI oqimlari |
| Security | `test/core/security` | Account isolation, secret/config guardlari, signing va SQL kontraktlari |
| Localization | `test/l10n` | ARB parity, UI matnlari va locale persistence |
| Gated live | `test/integration`, `test/support/live_gate.dart` | Faqat aniq target va write ruxsati bilan remote oqimlar |
| Python | `tool/test_*.py` | Build isolation, credential helper va SQL validator |
| Deno | `supabase/functions/legal-ai/*_test.ts` | AI auth/input, grounding va error-normalization |
| PostgreSQL | `tool/database` | Lokal runtime ownership/RLS/session regressiyalari |
| Browser | `tool/*browser_smoke.py`, `tool/staging_visual_smoke.py` | Real builddagi navigation, form, persistence va rendering |

Gated testlar default run'da sabab bilan **skip** bo'ladi. Ular PASS deb
hisoblanmaydi. `LEXHUB_LIVE_WRITE_TESTS` compile-time gate'ini tasodifan
yoqmang; eski integration testlar remote Auth/data yaratishi mumkin.
Faqat ruxsatli target, synthetic account va tasdiqlangan cleanup bilan ishlating.
Parolni argument yoki repoga yozish o'rniga ignored test config/secret mechanism
orqali `test/support/live_test_password.dart`ga bering.

## Backend va tooling (productionga ulanmaydi)

Python 3.11+ uchun alohida virtualenv'da `tool/requirements-security.txt`ni
o'rnating. Deno va Node.js ham kerak.

```sh
python -m unittest discover -s tool -p "test_*.py"
deno test --allow-env supabase/functions
deno check supabase/functions/legal-ai/index.ts
python tool/validate_sql_syntax.py
node --test tool/database/validate_stage1_history.test.mjs
node --test tool/database/auth_abuse_guards.test.mjs
```

PGlite dependency va to'liq runtime SQL commandi:
[STAGE1_DATABASE.md](STAGE1_DATABASE.md). Static SQL/contract testi live
Supabase policy, Auth yoki migration deploymentini isbotlamaydi.

## Staging va browser

[Staging konfiguratsiyasini](STAGING.md) tayyorlab, aynan joriy source'dan
`flutter build web --release --dart-define-from-file=env/staging.json` bajaring.
Playwright browserini shu virtualenv ichida o'rnating:

```sh
python -m playwright install chromium
python tool/profile_staging_smoke.py --browser
```

Profile runner `LEXHUB_STAGING_URL`, `LEXHUB_STAGING_ANON_KEY` va
`LEXHUB_STAGING_SERVICE_KEY`ni process environment'dan oladi, staging identityni
qat'iy tekshiradi va vaqtinchalik hisob/avatarlardan foydalanadi. Qiymatlar
outputga chiqmasin. Production service keyni stagingga bermang.

Browser harness local buildga production CSP headerlarini qo'llaydi; file
picker, avatar upload, validation, save/error, reload, logout/login va
responsive oqimlarni tekshiradi. `tool/staging_visual_smoke.py` kengroq
navigation smoke uchun. Playwright tests yoki screenshots server policy
regressiyalarining o'rnini bosmaydi; ikkala qatlam alohida tekshiriladi.

## Nosozlik va release tekshiruvi

`tool/blackhole_server.py` va `tool/watch_error_screen.py` faqat lokal/device
timeout tekshiruvi uchun. Synthetic config yarating; production key/configni
black-hole targetga ko'chirmang.

Har bir o'zgarishdan keyin tegishli regression, `git diff --check` va secret
scan bajariladi. Release buildda client bundle alohida tekshiriladi.
Real secret topilsa qiymati yoki uning fingerprinti hisobotga kiritilmaydi.
Tarixiy exposure holatini active/revoked deb belgilash uchun operator dalili
kerak; Git historyni yashirish yoki testni yumshatish tuzatish emas.

[Web release](DEPLOY.md) | [Android signing](RELEASE_SIGNING.md)
