/// META-QULF — MANBA MATNIGA TAYANADIGAN QULFLAR TOZA CLONE'DA HAM ISHLASHI KERAK.
///
/// O'LCHANGAN NUQSON (2026-09-02): bu loyihada `git config core.autocrlf` ->
/// `true` (Git for Windows sukut o'rnatmasi), `.gitattributes` esa YO'Q. Repo
/// ichida fayllar LF bilan saqlanadi (`git show HEAD:supabase/schema.sql` -> 0
/// CR), ishchi daraxtga esa CHECKOUT paytida CRLF yoziladi. Shu sababli manba
/// matnini XOM o'qib, ichida `\n` bo'lgan KO'P SATRLI naqsh qidiradigan
/// qulflar TOZA CLONE'da buziladi. Ayni daraxtda o'lchandi
/// (`git diff --stat chore/claude-skills main` BO'SH edi):
///   shox, eski ishchi daraxt -> `+842 ~27 All tests passed`
///   `main`, checkout'dan keyin -> `+840 ~27 -2 Some tests failed`
///
/// Uchta qulf shu sinfda edi:
///   * `p0_security_remediation_test.dart` — anonim savol himoya VIEW'i: QIZIL;
///   * `expert_rating_no_fabrication_test.dart` — shartli `SET rating = NULL`:
///     QIZIL;
///   * `question_category_resolver_test.dart` — soxta `_fallbackPosts`
///     qaytishini INKOR qiladi (`isFalse`): YASHIL, lekin VAKUUM — naqsh
///     hech qachon moslashmagani uchun inkor HAR DOIM o'tardi.
/// Ya'ni bu sinf qulfni JIM O'LDIRADI — aynan §0 taqiqlaydigan holat.
///
/// QOIDA: fayl matnini o'qib, `contains(...)` ichida `\n` bo'lgan naqsh
/// ishlatadigan test o'qishni NORMALLASHTIRISHI SHART.
///
/// `.gitattributes` QO'SHILMADI: u mavjud CRLF ishchi daraxtni O'ZI
/// tuzatmaydi (qayta checkout talab qiladi) va har bir kelajakdagi checkout
/// xulqini o'zgartiradi — nuqson esa TESTDA, manbada emas.
///
/// O'LCHANGAN CHEKLOV — satr oxiriga bog'langan BOSHQA shakllar bu sinfda
/// EMAS, ular alohida tekshirildi va IMMUN:
///   * `profile_invariant_migration_test.dart:298` — `trimRight()` `\r` ni
///     olib tashlaydi;
///   * `bootstrap_strings_key_parity_test.dart:35`, `supabase_config_test.dart:144`
///     — `^\s*` / `\s` `\r` ni yutadi;
///   * qolgan barcha `endsWith(...)` FAYL YO'LIGA tegishli, mazmunga emas.
/// Shuning uchun bu qulf faqat O'LCHANGAN sinfni qamraydi va shundan
/// ko'proqni DA'VO QILMAYDI.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fayl matnini o'qiydigan chaqiruv (ya'ni test manbaga tayanadi).
final _readsFile = RegExp(r'readAsStringSync\(');

/// `contains(...)` naqshi ichida LITERAL `\n` bor — ya'ni ko'p satrli moslik.
final _multiLinePattern = RegExp(r"""contains\((?:'[^']*|"[^"]*)\\n""");

/// Qabul qilinadigan normallashtirish: CRLF -> LF, yoki barcha bo'sh joyni
/// bitta probelga siqish (loyihadagi `_squash` konvensiyasi).
final _normalises = RegExp(
    r"""replaceAll\('\\r\\n', '\\n'\)|replaceAll\(RegExp\(r'\\s\+'\), ' '\)""");

/// Bu faylning O'ZI skanerdan chiqariladi: yuqoridagi naqshlar shu yerda
/// MATN sifatida yozilgan.
const String _selfPath = 'test/support/source_lock_portability_test.dart';

void main() {
  final offenders = <String>[];
  final candidates = <String>[];
  var scanned = 0;

  for (final entity in Directory('test').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (path.endsWith(_selfPath)) continue;
    scanned++;

    final src = entity.readAsStringSync();
    if (!_readsFile.hasMatch(src)) continue;
    if (!_multiLinePattern.hasMatch(src)) continue;

    candidates.add(path);
    if (!_normalises.hasMatch(src)) offenders.add(path);
  }

  test('XOM manba o\'qish + ko\'p satrli naqsh = normallashtirish MAJBURIY', () {
    expect(
      offenders,
      isEmpty,
      reason: 'Bu fayllar manba matnini XOM o\'qib ko\'p satrli naqsh '
          'qidiradi. Windows\'dagi TOZA clone\'da (`core.autocrlf=true`) '
          'ishchi daraxt CRLF bo\'ladi va naqsh MOSLASHMAYDI — qulf QIZIL '
          'bo\'ladi yoki (inkor bo\'lsa) JIM O\'LADI. O\'qishga '
          "`.replaceAll('\\r\\n', '\\n')` qo\'sh: $offenders",
    );
  });

  test('detektor VAKUUM emas — o\'lchangan uch qulf HAQIQATAN topiladi', () {
    // BO'SH TEKSHIRUV KO'RINMAS QOLMASIN: agar katalog yurishi yoki naqsh
    // buzilsa, yuqoridagi test SOXTA yashil bo'lardi.
    expect(scanned, greaterThan(100),
        reason: 'test/ katalogi yurilmadi — skaner buzilgan ($scanned fayl)');

    for (final known in const <String>[
      'test/core/security/p0_security_remediation_test.dart',
      'test/features/legal_experts/expert_rating_no_fabrication_test.dart',
      'test/features/community_forum/data/datasources/'
          'question_category_resolver_test.dart',
    ]) {
      expect(candidates, contains(known),
          reason: 'shu fayl ANIQ shu sinfda edi (2026-09-02 da o\'lchangan) — '
              'detektor uni ko\'rmasa, naqsh o\'lgan');
    }
  });
}

