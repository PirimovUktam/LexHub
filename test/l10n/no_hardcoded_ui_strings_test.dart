// LexHub — §16 BLOKIROVKA QILUVCHI l10n tekshiruvi.
//
// `tool/l10n_scan.py` faqat AUDIT raqamini beradi — CI'ni to'xtatmaydi.
// Shu test esa to'xtatadi: widget qatlamiga yangi hardcoded matn qo'shilsa
// yoki ro'yxatdagi fayllardagi son o'zgarsa, `flutter test` qizil bo'ladi.
//
// IKKI ZONA:
//   ZONA A — WIDGET QATLAMI (`presentation/pages`, `presentation/widgets`,
//     `core/config`, `core/theme`): NOL tolerantlik. Faqat `_widgetAllowed`
//     ichidagi ANIQ literal'lar kechiriladi, har birining sababi yozilgan.
//   ZONA B — qolgan qatlamlar: har bir fayl uchun ANIQ son qulflangan.
//     O'ssa ham, kamaysa ham test yiqiladi — ro'yxat eskirmaydi. Bu
//     fayllar hali tarjima qilinmagan; sababi `_pending` izohlarida.
//
// Skaner mantiqi `tool/l10n_scan.py` PORTI: ikkisi AYNAN bir xil son
// berishi kerak (o'lchangan: 301 literal, 25 fayl).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Foydalanuvchiga ko'rinadigan matn KUTILADIGAN nomlangan argumentlar.
///
/// `['"]?:` QO'SHILDI (2026-08-30) — ilgari naqsh faqat `title:` ni bilardi va
/// `Map` literal ichidagi `'title':` / `"title":` shaklini KO'RMASDI. O'lchangan
/// natija: `emergency_rights_page.dart` dagi 4 protokol sarlavhasi, 4 tavsifi
/// va 13 qoidasi — jami 21 ta foydalanuvchiga ko'rinadigan o'zbekcha matn —
/// bu qulf ostida BO'LMAGAN holda widget qatlamida turgan edi, ya'ni ingliz
/// UI'da eng xavfli ekran butunlay o'zbekcha ko'rinardi.
///
/// `rules` ham qo'shildi: u `_listSlotOpen` bilan birga ishlaydi.
///
/// `\b` MAJBURIY: uni qo'shmasa `"article_title": "Modda sarlavhasi"` —
/// `gemini_legal_service.dart` dagi Gemini PROMPT shablonining bir qatori —
/// `title['"]?:` ga tushib qolardi va skaner AI so'rovining JSON sxemasini
/// "tarjima qilinmagan UI matni" deb hisoblardi (o'lchandi: 2 ta yolg'on
/// nishon). Bu matn foydalanuvchiga KO'RINMAYDI, tarjima ham qilinmaydi.
final _uiSlots = RegExp(r'''(?:\bText\(|\bText\.rich\()|'''
    r'''\b(?:label|labelText|title|subtitle|hintText|tooltip|helperText|'''
    r'''errorText|semanticLabel|message|content|actionText|prefixText|'''
    r'''suffixText|counterText|rules)['"]?:''');

/// MATN RO'YXATI sloti: `'rules': [` dan yopiluvchi `]` gacha BARCHA satrlar
/// UI matni deb hisoblanadi.
///
/// NIMA UCHUN KERAK: [_ctx] oynasi 3 KOD satri. `'rules': [` ostidagi UCHINCHI
/// va keyingi elementlar oynadan CHIQIB ketadi va jimjitlikda e'tibordan
/// qoladi. O'LCHANDI (2026-08-30): faqat slot naqshini tuzatish
/// `emergency_rights_page.dart` dagi 13 qoidadan 8 tasini ko'rsatardi, 5 tasi
/// KO'RINMAY qolardi — ya'ni yarim qulf.
///
/// LUG'AT ATAYLAB QISQA: `rules` — o'lchangan holat; `bullets`/`points` —
/// yaqin sinonimlar (hozir `lib/` da yo'q, ya'ni hisobga ta'sir qilmaydi).
/// Yangi naqsh O'LCHANSA shu ro'yxatga qo'shiladi.
final _listSlotOpen = RegExp(r'''(?:rules|bullets|points)['"]?\s*:\s*\[''');

/// Dart string literal'i (escape'larni hisobga oladi).
final _str = RegExp(
    r'''(?<![\w$])(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")''');

/// Texnik (tarjima qilinmaydigan) qiymatlar: sana formatlari, bo'shliq.
final _tech = RegExp(r'^(?:(?:dd|MM|yyyy|HH|mm|ss|[.,:/ -])+|\s*)$');

/// Bo'shliqsiz bitta token (identifikator / yo'l / kalit bo'lishi mumkin).
final _oneToken = RegExp(r'^[\w./:@#-]+$');
final _techInner = RegExp(r'[./:@#_]|\d');
final _camelCase = RegExp(r'[a-z][A-Z]');
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
final _latinLetter = RegExp(r'[A-Za-z]');

class _Hit {
  final int line;
  final String value;
  const _Hit(this.line, this.value);
}

/// `tool/l10n_scan.py`dagi `_is_technical_token` bilan bir xil qoida.
bool _isTechnicalToken(String s) {
  if (!_oneToken.hasMatch(s)) return false;
  if (_techInner.hasMatch(s)) return true; // yo'l / kalit / snake_case / raqam
  if (_camelCase.hasMatch(s)) return true; // camelCase identifikator
  // Bitta so'z: bosh harfi KICHIK bo'lsa identifikator deb hisoblanadi.
  return s[0].toUpperCase() != s[0];
}

bool _isUserFacing(String v) {
  // `${...}` / `$ident` interpolyatsiyasi tarjima qilinadigan qism emas.
  final s = v.replaceAll(_interpolation, '').trim();
  if (s.length < 3) return false;
  if (_latinLetter.allMatches(s).length < 3) return false;
  if (_tech.hasMatch(s) || _isTechnicalToken(s)) return false;
  const skip = ['package:', 'assets/', 'http://', 'https://', 'lib/'];
  for (final p in skip) {
    if (v.startsWith(p)) return false;
  }
  return true;
}

/// `[` va `]` FARQI — string literal'lar OLIB TASHLANGANDAN keyin.
///
/// Literal ichidagi qavs (masalan `"... (hashar) [1092]"`) slotni MUDDATIDAN
/// OLDIN yopib, ro'yxatning qolgan qoidalarini yana ko'rinmas qilardi.
int _bracketDelta(String line) {
  var delta = 0;
  for (final ch in line.replaceAll(_str, '').codeUnits) {
    if (ch == 0x5B) delta++; // [
    if (ch == 0x5D) delta--; // ]
  }
  return delta;
}

/// Izoh va bo'sh qatorlarni TASHLAB, shu qator + 2 oldingi KOD qatorini
/// qaytaradi. Izohlar hisobga olinsa, `Text(` bilan literal orasiga yozilgan
/// izoh slotni oynadan chiqarib yuboradi va literal jimjitlikda e'tibordan
/// chetda qoladi — skaner o'z-o'zini aldaydi.
String _ctx(List<String> lines, int i) {
  final parts = <String>[lines[i - 1]];
  var j = i - 2;
  while (j >= 0 && parts.length < 3) {
    final st = lines[j].trim();
    if (st.isNotEmpty &&
        !st.startsWith('//') &&
        !st.startsWith('*') &&
        !st.startsWith('/*')) {
      parts.add(lines[j]);
    }
    j--;
  }
  return parts.reversed.join('\n');
}

Map<String, List<_Hit>> _scanLib() {
  final root = Directory('lib');
  if (!root.existsSync()) {
    throw StateError(
        '`lib/` topilmadi — test paket ildizidan ishga tushirilishi kerak.');
  }
  final out = <String, List<_Hit>>{};
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/'))
      .where((p) => p.endsWith('.dart') && !p.contains('/l10n/gen/'))
      .toList()
    ..sort();
  for (final path in files) {
    final lines = File(path).readAsStringSync().split('\n');
    final hits = <_Hit>[];
    // > 0 => hozir MATN RO'YXATI ichidamiz (`_listSlotOpen` ochgan).
    var listDepth = 0;
    for (var i = 1; i <= lines.length; i++) {
      final line = lines[i - 1];
      final st = line.trim();
      if (st.startsWith('//') ||
          st.startsWith('*') ||
          st.startsWith('/*') ||
          st.startsWith('import ') ||
          st.startsWith('export ')) {
        continue;
      }
      var inListSlot = listDepth > 0;
      if (inListSlot || _listSlotOpen.hasMatch(line)) {
        inListSlot = true;
        listDepth += _bracketDelta(line);
        if (listDepth < 0) listDepth = 0;
      }
      if (!inListSlot && !_uiSlots.hasMatch(_ctx(lines, i))) continue;
      for (final m in _str.allMatches(line)) {
        final v = m.group(1) ?? m.group(2)!;
        if (_isUserFacing(v)) hits.add(_Hit(i, v));
      }
    }
    if (hits.isNotEmpty) out[path] = hits;
  }
  return out;
}

const _widgetLayerPaths = [
  '/presentation/pages/',
  '/presentation/widgets/',
  'lib/core/config/',
  'lib/core/theme/',
];

bool _isWidgetLayer(String p) => _widgetLayerPaths.any(p.contains);

/// ZONA A carve-out'lari: fayl → {literal: SABAB}.
///
/// Har bir yozuv — ataylab tarjima QILINMAYDIGAN qiymat. Ikki toifa bor:
/// (a) backendga/DBga ketadigan KALIT (tarjima qilinsa funksiya buziladi);
/// (b) ikki tilda AYNAN bir xil bo'ladigan xalqaro belgi.
const _widgetAllowed = <String, Map<String, String>>{
  'lib/features/search/presentation/pages/search_page.dart': {
    'Aliment': "Qidiruv KALITI: `SearchQueryChangedEvent` orqali o'zbek "
        "korpusiga solishtiriladi. Tarjima 0 natija qaytaradi.",
    'Mehnat': 'Qidiruv KALITI (yuqoridagi sabab).',
    "Iste'molchi": 'Qidiruv KALITI (yuqoridagi sabab).',
    'Jarima': 'Qidiruv KALITI (yuqoridagi sabab).',
  },
  'lib/features/home/presentation/widgets/emergency_quick_button.dart': {
    'SOS': "XALQARO belgi — `uz` va `en` qiymati aynan bir xil bo'lardi, "
        "ARB kaliti faqat shovqin bo'lardi. Yonidagi sarlavha "
        "(`emergencyQuickTitle`) esa tarjimalanadi.",
  },
  'lib/features/community_forum/presentation/pages/question_detail_page.dart': {
    'Ekspert Yurist': "WIRE qiymati: `answers.author_name` ustuniga YOZILADI. "
        "Ko'rsatishda `answerAuthorRoleLabel()` tarjima qiladi.",
    'Fuqaro': 'WIRE qiymati (yuqoridagi sabab).',
  },
  // `_quickPromptChips` — 5 ta {label, query} juftligi. IKKISI HAM funksional
  // qiymat, ekran yorlig'i EMAS. Bu fayl skanerga FAQAT 2026-08-30 da,
  // `'label':` sloti qo'shilgandan keyin ko'rindi.
  'lib/features/legal_assistant/presentation/pages/legal_assistant_page.dart': {
    // `label` KALIT: `legalAiChipLabel()` (`lib/core/localization/
    // legal_ai_labels.dart:31`) uni `QuestionCategoryCatalog.normalizeName`
    // bilan normallashtirib `switch` qiladi va ARB matnini qaytaradi, ya'ni
    // `en` UI'da yorliq ALLAQACHON inglizcha. Shu literal tarjima qilinsa
    // `switch` `default` shoxiga tushib XOM matn chiqarardi. Qiymat yana
    // `_selectedCategory` ga ham yoziladi (kategoriya kaliti).
    "Ishdan nohaq bo'shatish": 'Chip KALITI: `legalAiChipLabel()` switch + '
        '`_selectedCategory`. Ko\'rinadigan matn `aiChipUnfairDismissal`.',
    "Iste'molchi huquqi (tovarni qaytarish)":
        'Chip KALITI (yuqoridagi sabab), matn `aiChipConsumerReturn`.',
    'Aliment undirish':
        'Chip KALITI (yuqoridagi sabab), matn `aiChipAlimony`.',
    "Yo'l harakati jarimasi":
        'Chip KALITI (yuqoridagi sabab), matn `aiChipTrafficFine`.',
    'Qarz va tilxat':
        'Chip KALITI (yuqoridagi sabab), matn `aiChipDebtReceipt`.',
    // `query` — AI QUVURIGA KIRUVCHI MATN. Uni inglizchaga o'girish
    // funksiyani BUZADI (uch joyda):
    //   1. `CheckEmergencyTextEvent` o'zbekcha kalit so'zlar bo'yicha
    //      favqulodda holatni aniqlaydi;
    //   2. RAG korpusi (`uzbek_legal_knowledge_base.dart`) o'zbekcha;
    //   3. Gemini prompt'i javobni "to'liq o'zbek tilida" so'raydi
    //      (`gemini_legal_service.dart`).
    // Ya'ni inglizcha savol o'zbekcha javob keltirardi va favqulodda
    // aniqlash JIM ishlamasdi. Bu `search_page.dart` qidiruv kalitlari
    // bilan AYNI toifadagi carve-out.
    "Ish beruvchi meni asossiz ravishda o'z xohishim bilan ariza yozishga majburlamoqda va ishdan bo'shatmoqchi. Qanday huquqlarim bor?":
        'AI SO\'ROV matni: o\'zbekcha RAG korpusi + favqulodda kalit '
            'so\'zlar + o\'zbekcha javob talab qiladigan prompt.',
    "Do'kondan kiyim sotib olgandim, lekin o'lchami to'g'ri kelmadi. 10 kun ichida qaytarib pulimni olsam bo'ladimi?":
        'AI SO\'ROV matni (yuqoridagi sabab).',
    "Farzandlarim uchun aliment undirmoqchiman. Ota rasman ishlamaydi, aliment qanday hisoblanadi va sudga qanday ariza beriladi?":
        'AI SO\'ROV matni (yuqoridagi sabab).',
    "Radar orqali noo'rin jarima qarori keldi. Ushbu ma'muriy qaror ustidan 10 kun ichida qanday shikoyat qilsam bo'ladi?":
        'AI SO\'ROV matni (yuqoridagi sabab).',
    "Tanishimga qarz bergan edim, tilxat yozib bergan. Pulni qaytarmayapti, sud orqali undirish tartibi qanday?":
        'AI SO\'ROV matni (yuqoridagi sabab).',
  },
};

/// ZONA B — hali tarjima qilinmagan fayllar va ANIQ literal soni.
///
/// TOIFA-1 «HUQUQIY KONTENT KATALOGI» (205 literal): shablon/xizmat nomlari,
/// qonun moddalari matni, muddat ogohlantirishlari. Bularning bir qismi §16
/// dagi "localizationdan tashqari maxsus content" istisnosiga tushadi:
/// qonun matnini INGLIZCHAGA o'girish — rasmiy bo'lmagan tarjima yaratish,
/// ya'ni huquqiy jihatdan ZARARLI. Ariza/shikoyat shablonlarining TANASI ham
/// o'zbekcha qolishi shart — O'zbekiston sudiga inglizcha da'vo topshirilmaydi.
/// Ammo katalog KARTOCHKASI (nom, tavsif) — ekran yorlig'i va u tarjimaga
/// muhtoj. Shu sababli bu toifa OCHIQ MASALA, avtomatik istisno emas.
///
/// TOIFA-2 «XATO / HOLAT MATNLARI» (78 literal): `Failure.message`,
/// `Exception` matnlari, SnackBar mazmuni. To'g'ri yechim — `Failure`ga
/// `code` qo'shib, tarjimani presentation qatlamida (`failureText`) qilish.
const _pending = <String, int>{
  // TOIFA-1 — huquqiy kontent kataloglari.
  'lib/core/legal_safety/deadlines_guard.dart': 15,
  'lib/core/legal_safety/law_article_chunk.dart': 1,
  'lib/core/legal_safety/uzbek_legal_knowledge_base.dart': 34,
  'lib/features/citizen_services/data/datasources/citizen_services_local_datasource.dart': 50,
  // `document_templates_datasource.dart` (60) RO'YXATDAN CHIQDI (2026-08-30):
  // fayl O'CHIRILDI. U UCHINCHI shablon katalogi edi va FAQAT AI yo'nalish
  // oqimida ishlatilardi — bundle va baza katalogidan farq qilardi (maydon
  // nomi `violation_details` vs `violation_reason`). Ya'ni bu 60 literal
  // TARJIMA qilinmadi: dublikat katalog bilan birga yo'q qilindi.
  //
  // Shu sababli bundle katalogi 64 -> 79 (+15): `template_debt_pretenziya`
  // shu faylga KO'CHIRILDI (sarlavha, tavsif, 6 maydonning yorliq/namunasi).
  // Umumiy hisob 60 ta literal KAMAYDI (335 -> 290).
  'lib/features/document_builder/data/datasources/document_templates_local_datasource.dart': 79,
  'lib/features/home/data/datasources/home_local_datasource.dart': 26,
  // TOIFA-2 — xato / holat matnlari.
  //
  // P2 (2026-08-23): `error_handler.dart` 5 -> 12. Son O'SDI, lekin bu §16
  // buzilishi EMAS — aksincha tuzatish: ilgari XOM texnik matn
  // (`"Kutilmagan xatolik yuz berdi: ${error.toString()}"`, server
  // `data['message']`) to'g'ridan-to'g'ri foydalanuvchiga chiqardi. Endi har
  // bir tarmoq/HTTP holati uchun alohida NEYTRAL o'zbekcha matn + `FailureCode`
  // bor; texnik detal `details` ga (log) ko'chdi. Foydalanuvchi ko'radigan
  // matn `failureText`/`errorStateText` orqali ARB'dan (`errorNetwork`,
  // `errorServer`, ...) keladi — ya'ni bu literal'lar ingliz tilida EKRANGA
  // CHIQMAYDI, faqat o'zbek tilidagi aniqroq matn sifatida ishlatiladi.
  //
  // P1 (2026-08-27): 12 -> 13. `TimeoutException` uchun alohida shox
  // qo'shildi ("Server javob bermadi." — Dio timeout shoxidagi matnning
  // AYNAN o'zi). Ilgari `dart:async` `TimeoutException` `else` shoxiga
  // tushib `FailureCode.unknown` + "Kutilmagan xatolik" bo'lardi, ya'ni
  // foydalanuvchi sababni bilmasdi. Ingliz UI'da `errorTimeout` ARB matni
  // ko'rinadi.
  'lib/core/errors/error_handler.dart': 13,
  'lib/features/auth/data/datasources/auth_remote_datasource.dart': 9,
  'lib/features/auth/presentation/bloc/auth_bloc.dart': 4,
  // `citizen_services_repository_impl.dart` (2) va
  // `community_forum_repository_impl.dart` (7) RO'YXATDAN CHIQDI (2026-08-27):
  // ikkalasi ham `ServerFailure(message: "...: $e")` quruvchi shoxlarni
  // `ErrorHandler.handle(e)` ga almashtirdi. Ya'ni bu literal'lar TARJIMA
  // qilinmadi — O'CHIRILDI: xato matni endi markazdan (sanitizatsiya +
  // `FailureCode`) keladi va ingliz UI ARB'dan o'z matnini tanlaydi.
  'lib/features/community_forum/data/datasources/community_forum_remote_datasource.dart': 14,
  'lib/features/community_forum/data/models/community_post_model.dart': 1,
  'lib/features/consultations/data/datasources/consultation_remote_datasource.dart': 9,
  'lib/features/consultations/data/models/consultation_model.dart': 1,
  'lib/features/consultations/data/models/consultation_slot_model.dart': 2,
  'lib/features/document_builder/data/models/saved_user_document_model.dart': 1,
  'lib/features/legal_assistant/data/datasources/legal_assistant_local_datasource.dart': 3,
  // 3 ta: 1 tasi xato matni, 2 tasi favqulodda ogohlantirish KONTENTI.
  'lib/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart': 3,
  'lib/features/legal_assistant/domain/usecases/get_legal_advice_usecase.dart': 1,
  // P0 (2026-08-29): 7 -> 13. MODERATSIYA oqimi qo'shildi
  // (`getPendingApplications` + `verifyExpertApplication`) va u 6 ta yangi
  // `Failure.message` matni keltirdi:
  //   1. "Arizalar ro'yxatini yuklab bo'lmadi: $e"
  //   2. "Tasdiqlash uchun avval tizimga kiring."
  //   3. "Tasdiqlash bajarilmadi."      <- RPC `success != true` (jim
  //                                        muvaffaqiyat YO'Q, §20)
  //   4. "Tasdiqlash javobi tushunilmadi."
  //   5. "Bu amal uchun ruxsat yo'q."   <- RPC 'Access Denied' -> forbidden
  //   6. "Tasdiqlashda xatolik: $e"
  // BU MATNLAR ATAYLAB O'ZBEKCHA QOLADI va §16 ni BUZMAYDI: ular UI'ga
  // XOM holda chiqmaydi. Moderatsiya ekrani `errorStateText(...)` orqali
  // o'qiydi (`failure_text.dart`) — o'zbek locale muallif yozgan
  // sanitizatsiya qilingan `message`ni, ingliz locale esa `FailureCode`
  // bo'yicha ARB matnini oladi. Ya'ni tarjima KOD orqali, matn orqali emas.
  //
  // 13 -> 14 (2026-08-30): SANOQ o'zgarishi, yangi matn EMAS. `'message':`
  // sloti qo'shilishi bilan `legal_experts_remote_datasource.dart:215` dagi
  // `{'success': true, 'message': 'Ariza muvaffaqiyatli topshirildi.'}`
  // ko'rindi. U ham yuqoridagi toifada: `expertApplySuccessText()`
  // (`apply_expert_dialog.dart:58`) bu matnni FAQAT `uz` locale'da
  // ko'rsatadi, boshqa tilda `expertApplySuccess` ARB kalitini oladi.
  //
  // 14 -> 16 (2026-08-30): SOXTA MUVAFFAQIYAT O'CHIRILDI. `:215` dagi
  // `{'success': true, 'message': 'Ariza muvaffaqiyatli topshirildi.'}`
  // (1 literal) olib tashlandi va o'rniga RPC shartnomasi buzilganda
  // `ServerException` beriladi; uning matni 3 ta yonma-yon literaldan
  // iborat ("Ariza holati ANIQLANMADI: ..."), ya'ni -1 +3 = +2. Bu matn ham
  // yuqoridagi toifada: UI'ga XOM chiqmaydi, `errorStateText(...)` orqali
  // o'qiladi. Nuqson va tuzatish isboti:
  // `test/features/legal_experts/data/datasources/`
  // `apply_verification_no_fake_success_test.dart` (avval QIZIL bo'lgan).
  'lib/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart': 16,
  // `legal_experts_bloc.dart` ro'yxatdan CHIQARILDI (2026-08-30): undagi
  // yakka o'zbekcha literal muvaffaqiyat SnackBar'iga XOM chiqardi, ya'ni
  // ingliz UI'da o'zbekcha matn ko'rinardi. Matn `expertApplySuccess` ARB
  // kalitiga ko'chirildi; bloc endi FAQAT serverning `message`ini uzatadi.
  'lib/features/search/data/datasources/search_remote_datasource.dart': 2,
  'lib/features/search/data/models/search_result_model.dart': 2,
};

void main() {
  final scan = _scanLib();

  group('§16 — hardcoded UI matnlari', () {
    test("ZONA A: widget qatlamida ro'yxatdan tashqari literal YO'Q", () {
      final violations = <String>[];
      scan.forEach((path, hits) {
        if (!_isWidgetLayer(path)) return;
        final allowed = _widgetAllowed[path] ?? const <String, String>{};
        for (final h in hits) {
          if (!allowed.containsKey(h.value)) {
            violations.add('$path:${h.line}  "${h.value}"');
          }
        }
      });
      expect(violations, isEmpty,
          reason: "Bu matnlar ARB'ga ko'chirilishi kerak (§16), yoki ataylab "
              "tarjima qilinmasa `_widgetAllowed`ga SABABI bilan yozilishi "
              "kerak:\n${violations.join('\n')}");
    });

    test("ZONA A: carve-out ro'yxati eskirmagan", () {
      final stale = <String>[];
      _widgetAllowed.forEach((path, literals) {
        final present = (scan[path] ?? const <_Hit>[]).map((h) => h.value);
        for (final literal in literals.keys) {
          if (!present.contains(literal)) stale.add('$path  "$literal"');
        }
      });
      expect(stale, isEmpty,
          reason: 'Bu carve-out kodda yo\'q — ro\'yxatdan olib tashlansin:\n'
              '${stale.join('\n')}');
    });

    test('ZONA B: har bir faylning literal soni qulflangan', () {
      final actual = <String, int>{};
      scan.forEach((path, hits) {
        if (!_isWidgetLayer(path)) actual[path] = hits.length;
      });
      expect(actual, equals(_pending),
          reason: 'ZONA B o\'zgardi. Son KAMAYSA — tarjima qilindi, '
              '`_pending` yangilansin. O\'SSA — yangi hardcoded matn '
              "qo'shildi, §16 buzildi.");
    });

    test('umumiy son `tool/l10n_scan.py` bilan bir xil', () {
      final total = scan.values.fold<int>(0, (a, b) => a + b.length);
      // 331 -> 338: P2 xato lokalizatsiyasi `error_handler.dart` ga 7 ta
      // neytral o'zbekcha matn qo'shdi (izoh `_pending` da).
      // 338 -> 339: P1 timeout shoxi (`error_handler.dart` 12 -> 13).
      // 339 -> 330 (28 -> 26 fayl): P1 xato-halolligi tozalashi — jamiyat
      // forumi va davlat xizmatlari repozitoriylari `ErrorHandler.handle` ga
      // o'tdi, ya'ni 9 ta XOM `"...: $e"` matni butunlay yo'q qilindi.
      // 330 -> 336: P0 ariza moderatsiyasi oqimi. Faqat
      // `legal_experts_remote_datasource.dart` o'sdi (7 -> 13), fayl soni
      // O'ZGARMADI (26) — yangi matnlar mavjud faylga tushdi. Sabab va
      // har bir matn `_pending` izohida sanab o'tilgan.
      // 336 -> 335 (26 -> 25 fayl): `legal_experts_bloc.dart` dagi YAKKA
      // literal (`"Ariza muvaffaqiyatli topshirildi."`) O'CHIRILDI — u
      // ingliz UI'da o'zbekcha SnackBar berardi, chunki muvaffaqiyat matni
      // `Text(state.message)` orqali XOM ko'rsatiladi. Endi bloc serverning
      // `message`ini uzatadi, matnni UI tanlaydi (`expertApplySuccessText`
      // + `expertApplySuccess` ARB kaliti). Ya'ni son SANOQ o'zgarishi
      // emas, HAQIQIY tuzatish natijasi; `tool/l10n_scan.py` ham 335
      // beradi (o'lchangan, 2026-08-30).
      //
      // 335 -> 290 (25 -> 24 fayl): UCHINCHI shablon katalogi
      // (`document_templates_datasource.dart`, 60 literal) O'CHIRILDI, uning
      // yagona kerakli shabloni bundle'ga ko'chdi (+15). 60 - 15 = 45 ta
      // literal KAMAYDI. Sabab `_pending` izohida; o'lchangan 2026-08-30.
      //
      // 290 -> 301 (24 -> 25 fayl): SKANER KO'RISH DOIRASI KENGAYDI —
      // loyihada yangi hardcoded matn PAYDO BO'LMADI. O'lchangan yo'l
      // (2026-08-30):
      //   290 -> 324: `['"]?:` + `_listSlotOpen` qo'shildi -> 34 ta ilgari
      //               KO'RINMAGAN literal chiqdi (21 `emergency_rights_page`,
      //               10 `legal_assistant_page`, 1 `legal_experts` datasource,
      //               2 Gemini prompt'i);
      //   324 -> 322: `\b` qo'shildi -> Gemini PROMPT shablonining 2 ta
      //               yolg'on nishoni ketdi (`"article_title": ...`);
      //   322 -> 301: `emergency_rights_page.dart` ning 21 literali ARB'ga
      //               KO'CHDI (fayl skanerdan butunlay chiqdi).
      // Qoldi: +10 `legal_assistant_page` (`_widgetAllowed`, chip KALITI va
      // AI so'rov matni) va +1 `legal_experts` (`_pending`, `uz`-only
      // muvaffaqiyat matni). FAYL SONI: 24 + 1 = 25 — yangi ko'ringan
      // `legal_assistant_page.dart` qo'shildi; `emergency_rights_page.dart`
      // va `gemini_legal_service.dart` skanerga KIRDI va yana CHIQDI
      // (birinchisi ARB'ga ko'chgani, ikkinchisi yolg'on nishon bo'lgani
      // uchun).
      //
      // 301 -> 303 (fayl soni O'ZGARMAYDI, 25): SOXTA MUVAFFAQIYAT
      // O'CHIRILDI. `legal_experts_remote_datasource.dart` dagi to'qilgan
      // `'Ariza muvaffaqiyatli topshirildi.'` (-1) olib tashlandi va RPC
      // shartnomasi buzilgan holat uchun 3 ta yonma-yon literaldan iborat
      // "Ariza holati ANIQLANMADI: ..." matni (+3) qo'yildi. -1 + 3 = +2;
      // `tool/l10n_scan.py` shu faylda 16 beradi (o'lchangan, 2026-08-30).
      // Bu YANGI hardcoded matn EMAS: `_pending` izohida yozilganidek,
      // datasource matnlari UI'ga `errorStateText(...)` orqali chiqadi.
      expect(total, 303, reason: 'Dart porti Python skaneridan uzoqlashdi.');
      expect(scan.length, 25);
    });
  });
}
