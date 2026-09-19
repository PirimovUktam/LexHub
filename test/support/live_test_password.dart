// LexHub — LIVE TEST PAROLI (bitta joyda, MANBADA TURMAYDI).
//
// MUAMMO (O'LCHANDI 2026-09-04): repo OMMAVIY — anonim
// `GET api.github.com/repos/PirimovUktam/LexHub` -> `visibility = public`.
// Zaif, hammaga ma'lum 12 belgilik parol esa 12 ta live test faylida OCHIQ
// yozilgandi va o'sha
// testlar shu parol bilan REAL `auth.signUp` qiladi. Yaratilgan hisob
// `email_confirmed_at IS NOT NULL` bilan bazada QOLADI — uni o'chirish
// uchun `service_role` kaliti kerak, u esa mahalliy muhitda YO'Q
// (`cleanup_live_test_data_test.dart` izohi). Ya'ni har yugurtirish repo
// ko'rgan HAR KIMGA hamjamiyat feed'iga YOZISH huquqli tasdiqlangan hisob
// qoldirardi.
//
// YECHIM: parol manbada emas — faqat `--dart-define` bilan beriladi:
//
//     flutter test test/integration \
//       --dart-define-from-file=env/prod.json \
//       --dart-define=LEXHUB_LIVE_WRITE_TESTS=true \
//       --dart-define=LEXHUB_TEST_PASSWORD=<kamida 16 belgi>
//
// FAIL-CLOSED: define berilmasa yoki qisqa bo'lsa live test DARHOL
// to'xtaydi. Sukutdagi parol YO'Q — "shunday ishlayveradi" degan soxta
// muvaffaqiyat bo'lmaydi.
//
// NEGA 16 BELGI: eski sirqib chiqqan qiymat 12 belgi. Minimal uzunlikni 16
// qilib qo'yish o'sha qiymatni TUZILISHI BILAN rad etadi — shuning uchun uni
// bu faylda literal sifatida takrorlash KERAK EMAS (aks holda sir repoga
// qaytib kirardi).
//
// DIQQAT: oddiy `flutter test` ga TA'SIR QILMAYDI. Har bir live fayl
// `liveSuiteEnabled()` darvozasidan KEYIN chaqiradi (o'lchandi: 12 faylda
// ham `liveSuiteEnabled(...)` `main()` ning birinchi qatorida), darvoza esa
// sukut bo'yicha YOPIQ.

/// `--dart-define=LEXHUB_TEST_PASSWORD=...` qiymati. Compile-time konstanta —
/// `Platform.environment` bilan chetlab o'tib bo'lmaydi.
const String kLiveTestPasswordRaw =
    String.fromEnvironment('LEXHUB_TEST_PASSWORD');

/// Live testlar YARATADIGAN hisoblar uchun parol.
///
/// FAQAT live darvoza ochiq bo'lganda chaqiriladi. Qiymat bo'lmasa
/// `StateError` — bu JIM o'tmaydi va SOXTA yashil bermaydi.
String liveTestPassword() {
  if (kLiveTestPasswordRaw.length < 16) {
    throw StateError(
      'BLOCKED: live test paroli berilmadi (yoki 16 belgidan qisqa).\n'
      '  Sabab: repo OMMAVIY, shuning uchun parol manbada saqlanmaydi.\n'
      '  Qo\'shing: --dart-define=LEXHUB_TEST_PASSWORD=<kamida 16 belgi>',
    );
  }
  return kLiveTestPasswordRaw;
}
