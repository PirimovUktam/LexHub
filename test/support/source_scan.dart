/// Manba fayllarni SKANERLASH uchun umumiy yordamchilar (test-only).
///
/// Nima uchun alohida fayl: bir xil guard mantig'i ikki test faylida
/// ishlatiladi (`answer_schema_test.dart` — yozish yo'li, ...
/// `community_forum_read_path_test.dart` — o'qish yo'li). Nusxa ko'chirilgan
/// regexp'lar bir joyda yangilanmasa, guard jimgina o'lib qoladi.
library;

/// `//` bilan boshlanadigan izoh satrlarini olib tashlaydi (`///` ham).
///
/// SOURCE GUARD faqat KOD ni tekshiradi, hujjatni emas: evidence
/// izohlarida eski (buzuq) kod va mock ID'lar (`post_labor_1`,
/// `json['content']`) ATAYLAB keltirilgan va shu joyda qolishi kerak —
/// aks holda regressiyaning sababi hujjatlashmagan bo'ladi.
String stripLineComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// `answers` PostgREST zanjirida `content` ustunini nomlaydigan joylarni topadi.
///
/// [sources] — `path -> Dart manba matni`. Bir funksiyada, chunki u IKKI
/// joyda ishlatiladi: (1) real `lib/` skani, (2) detektorning o'zi fail
/// bo'la olishini isbotlaydigan sintetik test.
List<String> findAnswerContentOffenders(Map<String, String> sources) {
  final tableRef =
      RegExp(r"""\.from\(\s*(?:'answers'|"answers"|kAnswersTable)\s*\)""");
  // PostgREST ustun nomlari HAR DOIM string literal ichida bo'ladi
  // (`select('id, content')`, `insert({'content': ...})`). Dart o'zgaruvchisi
  // nomi `content` bo'lishi mumkin (`addAnswer(content:)`) — u xato emas,
  // shuning uchun faqat literal ichi tekshiriladi.
  final literals = <RegExp>[RegExp(r"'([^']*)'"), RegExp('"([^"]*)"')];
  final columnToken = RegExp(r'\bcontent\b');
  final offenders = <String>[];

  sources.forEach((path, raw) {
    final source = stripLineComments(raw);
    for (final match in tableRef.allMatches(source)) {
      // PostgREST chaqiruv zanjiri `;` gacha davom etadi.
      final end = source.indexOf(';', match.end);
      final chain =
          source.substring(match.start, end == -1 ? source.length : end);
      for (final literal in literals) {
        for (final found in literal.allMatches(chain)) {
          if (columnToken.hasMatch(found.group(1)!)) {
            offenders.add('$path: ${found.group(0)}');
          }
        }
      }
    }
  });

  return offenders;
}
