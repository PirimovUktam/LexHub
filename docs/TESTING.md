# LexHub — TEST BUYRUQLARI

## 1. DEFAULT (CI, har bir commit) — production'ga TEGMAYDI

```bash
flutter test
```

Nima ishlaydi: `test/core`, `test/features`, `test/l10n`, `test/widget_test.dart`.

`test/integration/*` fayllari **oshkora SKIP** bo'ladi. Ular
`test/support/live_gate.dart` gate'i ostida:

```dart
void main() {
  if (!liveSuiteEnabled('<suite>')) return;
  ...
}
```

Gate `bool.fromEnvironment('LEXHUB_LIVE_WRITE_TESTS')` (COMPILE-TIME
konstanta) ga qaraydi — shell env bilan chetlab o'tib bo'lmaydi.

**Bu JIM skip EMAS:** har bir gated fayl bitta `skip:` testi qoldiradi va
reporter sababni chop etadi (`~N` hisoblagichi bilan). Yashirin yashil
hisobot bo'lmaydi.

Kutilgan natija: `+N ~22 All tests passed!`

## 2. LIVE PRODUCTION (qo'lda, ataylab)

**DIQQAT: REAL Supabase Cloud bazasiga YOZADI** (probe auth user'lar,
savollar). Faqat MVP verifikatsiyasi paytida ishlatiladi.

```bash
flutter test test/integration --dart-define-from-file=env/prod.json --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
```

Bitta fayl:

```bash
flutter test test/integration/verify_mvp_blockers_live_test.dart --dart-define-from-file=env/prod.json --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
```

`env/prod.json` **gitignore**'da va real kalitlarni saqlaydi — hech qachon
commit qilinmaydi.

## 3. MVP BLOCKER VERIFIKATSIYASI (tartib MUHIM)

1. `supabase/migrations/20260828_mvp_blockers_p0_07_p1_05_p1_06.sql` —
   Supabase **SQL Editor**'da ishga tushiriladi (privileged; CLI/agent
   buni qila olmaydi).
2. Keyin live test:
   ```bash
   flutter test test/integration/verify_mvp_blockers_live_test.dart --dart-define-from-file=env/prod.json --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
   ```
3. Kutilgan: P0-07 `42501 permission denied` (anon VA authenticated),
   P1-05 mavjud bo'lmagan advokat uchun `0 slot`, P1-06 egasi o'chiradi /
   begona 0 qator / anon fail-closed.

Migration QO'LLANMAGAN bo'lsa test `P0001 Payment record not found` yoki
12 slot ko'rib **FAIL** beradi — ya'ni "deployed" degan yolg'on holat
bo'lishi mumkin emas.

## 4. Statik kontrakt testlari (default run ichida)

| Fayl | Nimani qulflaydi |
|---|---|
| `test/core/security/mvp_blockers_migration_contract_test.dart` | `.sql` mazmuni (REVOKE, 150000 yo'q, `TO authenticated`). **Deployment isboti EMAS.** |
| `test/l10n/arb_parity_test.dart` | `app_uz.arb` ↔ `app_en.arb` kalit pariteti, tarjima qilinmagan qiymatlar |
| `test/l10n/no_hardcoded_ui_strings_test.dart` | Widget qatlamida hardcoded matn (ZONA A: nol tolerantlik) |
| `test/l10n/locale_persistence_test.dart` | Til tanlovi restart'dan keyin saqlanadi (Hive) |

## 5. Release

```bash
flutter build apk --release --dart-define-from-file=env/prod.json
```
