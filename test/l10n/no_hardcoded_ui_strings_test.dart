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
// berishi kerak (o'lchangan: 339 literal, 28 fayl).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Foydalanuvchiga ko'rinadigan matn KUTILADIGAN nomlangan argumentlar.
final _uiSlots = RegExp(
    r'(?:\bText\(|\bText\.rich\(|label:|labelText:|title:|subtitle:|'
    r'hintText:|tooltip:|helperText:|errorText:|semanticLabel:|message:|'
    r'content:|actionText:|prefixText:|suffixText:|counterText:)');

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
      if (!_uiSlots.hasMatch(_ctx(lines, i))) continue;
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
};

/// ZONA B — hali tarjima qilinmagan fayllar va ANIQ literal soni.
///
/// TOIFA-1 «HUQUQIY KONTENT KATALOGI» (250 literal): shablon/xizmat nomlari,
/// qonun moddalari matni, muddat ogohlantirishlari. Bularning bir qismi §16
/// dagi "localizationdan tashqari maxsus content" istisnosiga tushadi:
/// qonun matnini INGLIZCHAGA o'girish — rasmiy bo'lmagan tarjima yaratish,
/// ya'ni huquqiy jihatdan ZARARLI. Ariza/shikoyat shablonlarining TANASI ham
/// o'zbekcha qolishi shart — O'zbekiston sudiga inglizcha da'vo topshirilmaydi.
/// Ammo katalog KARTOCHKASI (nom, tavsif) — ekran yorlig'i va u tarjimaga
/// muhtoj. Shu sababli bu toifa OCHIQ MASALA, avtomatik istisno emas.
///
/// TOIFA-2 «XATO / HOLAT MATNLARI» (74 literal): `Failure.message`,
/// `Exception` matnlari, SnackBar mazmuni. To'g'ri yechim — `Failure`ga
/// `code` qo'shib, tarjimani presentation qatlamida (`failureText`) qilish.
const _pending = <String, int>{
  // TOIFA-1 — huquqiy kontent kataloglari.
  'lib/core/legal_safety/deadlines_guard.dart': 15,
  'lib/core/legal_safety/law_article_chunk.dart': 1,
  'lib/core/legal_safety/uzbek_legal_knowledge_base.dart': 34,
  'lib/features/citizen_services/data/datasources/citizen_services_local_datasource.dart': 50,
  'lib/features/document_builder/data/datasources/document_templates_datasource.dart': 60,
  'lib/features/document_builder/data/datasources/document_templates_local_datasource.dart': 64,
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
  'lib/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart': 7,
  'lib/features/legal_experts/presentation/bloc/legal_experts_bloc.dart': 1,
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
      expect(total, 330, reason: 'Dart porti Python skaneridan uzoqlashdi.');
      expect(scan.length, 26);
    });
  });
}
