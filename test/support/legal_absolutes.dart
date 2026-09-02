// LexHub — TAQIQLANGAN ABSOLUT HUQUQIY IBORALAR: YAGONA MANBA.
//
// NIMA UCHUN ALOHIDA FAYL: bu naqsh IKKI xil darajada o'lchanadi va ikki
// nusxa saqlash aynan hozir tuzatilgan nuqsonni qaytarardi (bir xil matn
// ikki joyda yozilib, keyin bir-biridan ajralib ketishi —
// `CommunityPost.categoryRoutingNote` izohiga qara):
//
//   1. MANBA darajasi — `test/core/legal_safety/ungrounded_legal_guarantee_test.dart`
//      butun `lib/` ni skanerlaydi (qulflangan inventar bilan).
//   2. EKRAN darajasi — widget testlar AYNAN pump qilingan sahifada
//      ko'rinadigan matnni tekshiradi. Bu KUCHLIROQ da'vo: ARB'dan kelib,
//      interpolyatsiya bilan YIG'ILADIGAN absolut da'voni manba skaneri
//      KO'RMAYDI, ekran testi esa ko'radi.
//
// Manba: `.claude/skills/lexhub-legal-answer-safety` §1 (taqiqlangan iboralar)
// va §3 (modda darajasidagi grounding).

/// `100%` NING UCHTA XIL ISHLATILISHI — O'LCHANDI 2026-08-30 (`lib/` da 7 ta
/// uchrash, izohlardan tashqari 3 tasi):
///   * `master_system_prompt.dart:11` — "100% asoslash": bu MODELGA
///     ko'rsatma (grounding TALABI), foydalanuvchiga berilgan kafolat emas.
///   * `citizen_services_local_datasource.dart:43` — "jarima to'liq 100%
///     miqdorda": bu FAKT (summa foizi), huquqiy da'vo emas.
///   * `emergency_rights_page.dart:40` — "100% qonuniy haqlisiz": HAQIQIY
///     buzilish, 2026-08-30 da tuzatildi.
/// Shu sababli naqsh yalang'och `100%` ni EMAS, `100% + huquqiy sifat`
/// birikmasini ushlaydi. Aks holda test ikki asosli satrni ham qizil qilib,
/// allowlist'ni kattalashtirar va o'z signalini susaytirardi.
/// INGLIZ NAQSHLARI NIMA UCHUN QO'SHILDI (2026-08-30): shu kuni
/// `emergency_rights_page.dart` ning 21 ta huquqiy matni ARB'ga ko'chirildi,
/// ya'ni ILK MARTA `en` faylida MUALLIF YOZGAN huquqiy da'volar paydo bo'ldi.
/// Ular §1 nazoratidan BUTUNLAY tashqarida qolardi:
///   * manba skaneri (`ungrounded_legal_guarantee_test.dart`) `lib/l10n/gen/`
///     ni ATAYLAB chetlab o'tadi;
///   * ekran testi esa `uz` locale'da pump qilinardi.
/// Ya'ni inglizcha absolut kafolat yozilsa — hech qaysi test ko'rmasdi.
///
/// LUG'AT O'ZBEKCHASINING AYNAN OYNASI, kengroq EMAS. Xususan yalang'och
/// `guarantee` ATAYLAB YO'Q: "constitutional guarantees" / "a driver's legal
/// guarantees" — qonuniy va TO'G'RI ibora (ARB'da ikkalasi ham bor). Naqsh
/// faqat KAFOLAT BERILGAN NATIJANI ushlaydi.
final forbiddenLegalAbsolutes = RegExp(
  "kafolatlan"
  "|to'liq himoyalangan"
  "|bexato"
  "|aniq g'alaba"
  "|hech qanday xavf yo'q"
  r"|100\s*%\s*(to'g'ri|qonuniy|kafolat|himoyalangan|aniq|xavfsiz)"
  r"|\bwe guarantee\b"
  r"|\b(guaranteed|certain)\s+(win|victory|outcome|result|success)\b"
  r"|\bfully protected\b"
  r"|\b(flawless|error-free)\b"
  r"|\b(no|zero)\s+risk\b"
  r"|100\s*%\s*(correct|legal|guaranteed|protected|certain|safe)",
  caseSensitive: false,
);
