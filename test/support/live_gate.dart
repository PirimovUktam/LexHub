// LexHub — LIVE PRODUCTION TEST GATE (P2 test konfiguratsiyasi).
//
// MUAMMO: `test/integration/*` fayllari REAL Supabase Cloud proyektiga
// ulanadi. Ularning bir qismi hatto YOZADI (`auth.signUp`, `questions`
// INSERT). Shu sababli oddiy `flutter test` ularni ishga tushirsa:
//   1) dart-define'lar (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) bo'lmagani
//      uchun 31 ta test YIQILADI — CI hech qachon yashil bo'lmaydi;
//   2) dart-define'lar berilsa, oddiy test buyrug'i PRODUCTION bazasiga
//      yozib qo'yadi.
//
// YECHIM: bu gate. `main()` ning BIRINCHI qatorida chaqiriladi:
//
//     void main() {
//       if (!liveSuiteEnabled('real_supabase_e2e')) return;
//       ...
//     }
//
// `LEXHUB_LIVE_WRITE_TESTS=true` BERILMAGANDA fayl bitta SKIPPED test
// qoldiradi — ya'ni natija JIM «PASS» emas: reporter `~1` va SABABni
// chop etadi. Yashirin yashil hisobot bo'lmaydi.
//
// DEFAULT (production'ga TEGMAYDI, hammasi yashil bo'lishi kerak):
//
//     flutter test
//
// LIVE (REAL CLOUD — ataylab, oshkora):
//
//     flutter test test/integration \
//       --dart-define-from-file=env/prod.json \
//       --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
//
// DIQQAT: `bool.fromEnvironment` COMPILE-TIME konstanta — `Platform.
// environment` emas. Ya'ni gate'ni shell env bilan chetlab o'tib
// bo'lmaydi, faqat `--dart-define` bilan.

import 'package:flutter_test/flutter_test.dart';

/// `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` berilganda `true`.
const bool kLiveTestsEnabled =
    bool.fromEnvironment('LEXHUB_LIVE_WRITE_TESTS', defaultValue: false);

/// Skip sababi — reporter'da AYNAN shu matn chiqadi.
const String kLiveGateReason =
    'LIVE PRODUCTION TEST — o\'tkazib yuborildi (production bazasiga '
    'tegmaslik uchun). Ishga tushirish: flutter test test/integration '
    '--dart-define-from-file=env/prod.json '
    '--dart-define=LEXHUB_LIVE_WRITE_TESTS=true';

/// `true` qaytsa — live suite ishlashi mumkin.
///
/// `false` qaytganda chaqiruvchi DARHOL `return` qilishi kerak; shu paytda
/// bu funksiya bitta OSHKORA skipped test ro'yxatga oladi, shuning uchun
/// fayl «0 test» bo'lib jimgina yashil ko'rinmaydi.
bool liveSuiteEnabled(String suite) {
  if (kLiveTestsEnabled) return true;
  test('$suite — LIVE GATE (production)', () {}, skip: kLiveGateReason);
  return false;
}
