/// KIRITISH MAYDONI KONTURI VA TO'LDIRILGAN TUGMA JUFTLIGI — QULF.
///
/// 1. NUQSON (o'lchangan): `enabledBorder` yorug' mavzuda `borderLight`
///    (#E2E8F0) — oq maydon foni ustida 1.23:1, sahifa foni (#F8FAFC) ustida
///    1.18:1. Qorong'ida `borderDark` (#334155) — `surfaceDark` ustida 1.72:1,
///    `cardDark` ustida 1.41:1. Maydon foni ham kartadan faqat 1.05-1.22:1
///    farq qiladi, ya'ni input CHEGARASINI ko'rsatadigan boshqa signal YO'Q —
///    WCAG 1.4.11 (UI komponenti uchun 3:1) buzilgan edi.
///    Yechim: `borderStrongLight` (3.30 / 3.15:1), `borderStrongDark`
///    (4.10 / 3.36:1) — mavzu va `auth_text_field.dart` da BIR XIL.
///
/// 2. LATENT TUZOQ: qorong'i mavzuda `colorScheme.primary` = `indigo` +
///    `onPrimary` = oq -> 4.47:1. Grafik uchun o'tadi, MATN uchun AA'dan past.
///    M3 `FilledButton` fonni AYNI shu juftlikdan oladi, shuning uchun
///    `filledButtonTheme` aniq `indigoDark` + oq (6.29:1) ga bog'landi.
///
/// NIMA UCHUN `ThemeData` QURILMAYDI: `AppTheme` ichida
/// `GoogleFonts.plusJakartaSansTextTheme()` chaqiriladi, u testda shriftni
/// TARMOQDAN olishga urinadi va xato test TUGAGANDAN KEYIN kelib, kontrast
/// tekshiruvi o'tgan bo'lsa ham suite'ni qizil qiladi (shu sabab
/// `color_contrast_test.dart` ham manbadan o'qiydi). Shuning uchun mavzu
/// ULANISHI `app_theme.dart` MANBASIDAN ajratiladi, rang esa `AppColors` dan.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/constants/app_colors.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// `//` izohlari olib tashlangan manba — izohdagi O'LCHOV eslatmalari
/// (masalan "eski `borderDark` 1.41:1") qulfga ILINMASLIGI kerak.
String _codeOnly(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// Bitta mavzu getterining kod bloki.
String _themeBlock(String getter) {
  final source = _codeOnly('lib/core/theme/app_theme.dart');
  final at = source.indexOf('get $getter');
  if (at == -1) {
    throw StateError('`app_theme.dart` da `get $getter` yo\'q — mavzu API '
        'o\'zgargan, testni yangilang');
  }
  final next = source.indexOf('static ThemeData get', at + 1);
  return source.substring(at, next == -1 ? source.length : next);
}

const Map<String, Color> _tokens = <String, Color>{
  'borderStrongLight': AppColors.borderStrongLight,
  'borderStrongDark': AppColors.borderStrongDark,
  'borderLight': AppColors.borderLight,
  'borderDark': AppColors.borderDark,
  'primary': AppColors.primary,
  'indigo': AppColors.indigo,
  'indigoDark': AppColors.indigoDark,
  'electricBlue': AppColors.electricBlue,
  'electricBlueOnDark': AppColors.electricBlueOnDark,
};

/// `key` dan keyingi BIRINCHI rang ifodasini rangga aylantiradi.
Color _colorAfter(String block, String key, {String? within}) {
  var scope = block;
  if (within != null) {
    final w = scope.indexOf(within);
    expect(w, isNot(-1), reason: '`$within` topilmadi');
    scope = scope.substring(w);
  }
  final at = scope.indexOf(key);
  expect(at, isNot(-1), reason: '`$key` topilmadi — uslub o\'chirilgan?');
  final tail = scope.substring(at);
  final m = RegExp(r'(AppColors\.(\w+)|Colors\.white|Colors\.black)')
      .firstMatch(tail);
  expect(m, isNotNull, reason: '`$key` uchun rang ifodasi topilmadi');
  final raw = m!.group(0)!;
  if (raw == 'Colors.white') return Colors.white;
  if (raw == 'Colors.black') return Colors.black;
  final name = m.group(2)!;
  final color = _tokens[name];
  if (color == null) {
    throw StateError('`AppColors.$name` shu testning xaritasida yo\'q — '
        'mavzuga yangi rang ulangan, uni ATAYLAB baholab xaritaga qo\'shing');
  }
  return color;
}

void main() {
  final lightBlock = _themeBlock('lightTheme');
  final darkBlock = _themeBlock('darkTheme');

  group('kiritish maydoni konturi — 1.4.11 (3:1)', () {
    test('yorug\' mavzu: kontur maydon foni VA sahifa foni ustida >= 3:1', () {
      final c = _colorAfter(lightBlock, 'enabledBorder',
          within: 'inputDecorationTheme');
      expect(c, AppColors.borderStrongLight);
      expect(_contrast(c, Colors.white), greaterThanOrEqualTo(3.0));
      expect(
          _contrast(c, AppColors.backgroundLight), greaterThanOrEqualTo(3.0));
      expect(_contrast(c, AppColors.surfaceLight), greaterThanOrEqualTo(3.0));
    });

    test('qorong\'i mavzu: kontur uchta yuzada ham >= 3:1', () {
      final c = _colorAfter(darkBlock, 'enabledBorder',
          within: 'inputDecorationTheme');
      expect(c, AppColors.borderStrongDark);
      expect(_contrast(c, AppColors.surfaceDark), greaterThanOrEqualTo(3.0));
      expect(_contrast(c, AppColors.cardDark), greaterThanOrEqualTo(3.0));
      expect(_contrast(c, AppColors.backgroundDark), greaterThanOrEqualTo(3.0));
    });

    test('ESKI konturlar haqiqatan yiqilardi', () {
      expect(_contrast(AppColors.borderLight, Colors.white), lessThan(3.0));
      expect(
          _contrast(AppColors.borderDark, AppColors.surfaceDark), lessThan(3.0));
      expect(_contrast(AppColors.borderDark, AppColors.cardDark), lessThan(3.0));
    });

    test('`auth_text_field.dart` mavzu bilan BIR XIL tokenni ishlatadi', () {
      final code =
          _codeOnly('lib/features/auth/presentation/widgets/auth_text_field.dart');
      expect(code.contains('AppColors.borderStrongDark'), isTrue);
      expect(code.contains('AppColors.borderStrongLight'), isTrue);
      expect(code.contains('AppColors.borderDark : AppColors.borderLight'),
          isFalse,
          reason: 'zaif kontur qaytdi');
    });

    test('kontur ajratuvchi/divider tokenidan farq qiladi — ierarxiya', () {
      expect(AppColors.borderStrongLight, isNot(AppColors.dividerLight));
      expect(AppColors.borderStrongDark, isNot(AppColors.dividerDark));
    });

    test('fokus konturi 1.4.11 dan o\'tadi — maydon foni USTIDA o\'lchandi',
        () {
      final l = _colorAfter(lightBlock, 'focusedBorder',
          within: 'inputDecorationTheme');
      final d = _colorAfter(darkBlock, 'focusedBorder',
          within: 'inputDecorationTheme');
      expect(_contrast(l, Colors.white), greaterThanOrEqualTo(3.0));
      expect(_contrast(d, AppColors.surfaceDark), greaterThanOrEqualTo(3.0));
    });
  });

  group('to\'ldirilgan tugma (FilledButton) juftligi', () {
    test('ikki mavzuda ham fon+yorliq >= 4.5:1', () {
      for (final block in <String>[lightBlock, darkBlock]) {
        final bg =
            _colorAfter(block, 'backgroundColor', within: 'filledButtonTheme');
        final fg =
            _colorAfter(block, 'foregroundColor', within: 'filledButtonTheme');
        expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
      }
    });

    test('qorong\'i mavzu `colorScheme.primary` ni FON qilib ISHLATMAYDI', () {
      final bg =
          _colorAfter(darkBlock, 'backgroundColor', within: 'filledButtonTheme');
      expect(bg, AppColors.indigoDark);
      expect(bg, isNot(AppColors.indigo), reason: 'M3 sukut juftligi qaytdi');
    });

    test('M3 sukut yo\'li (indigo + oq) qorong\'ida haqiqatan yiqilardi', () {
      // `darkTheme` da `colorScheme` `indigo` dan quriladi, `onPrimary` esa oq.
      expect(_contrast(Colors.white, AppColors.indigo), lessThan(4.5));
      // ...lekin grafik sifatida o'tadi — shuning uchun `primary` aksent
      // bo'lib qoladi va faqat MATNLI to'ldirilgan tugma qayta bog'landi.
      expect(_contrast(Colors.white, AppColors.indigo),
          greaterThanOrEqualTo(3.0));
    });

    test('`FilledButton` faqat MA\'LUM joylarda — yangi ishlatilishi ushlanadi',
        () {
      // TUZOQ QAYTA YOZILDI (YUMSHATILMADI), 2026-08-30.
      //
      // Ilgari bu test `expect(hits, isEmpty)` edi va u "hali hech qayerda
      // ishlatilmaydi" O'LCHOVINI qulflardi. Endi bitta ishlatilish BOR
      // (`crash_log_page.dart` — tozalash dialogining tasdiq tugmasi), ya'ni
      // `isEmpty` KODNI emas, TARIXNI tekshirardi.
      //
      // Testning MAQSADI o'zgarmadi: `FilledButton` mavzu juftligi tekshirilgan
      // holda qolishi kerak. Kontrast qulfi yuqoridagi uchta testda
      // (`filledButtonTheme` fon+yorliq >= 4.5:1 ikki mavzuda ham, qorong'ida
      // `indigoDark`) — ular O'TADI, ya'ni mavjud ishlatilish AA.
      //
      // Shuning uchun endi RO'YXAT qulflanadi: yangi fayl qo'shilsa test
      // yiqiladi va muallif kontrast juftligini ataylab tekshiradi.
      const known = <String>{
        'crash_log_page.dart',
      };
      final hits = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('FilledButton(')) {
          hits.add(f.path.split(Platform.pathSeparator).last);
        }
      }
      expect(hits.toSet(), known,
          reason: 'Yangi `FilledButton` ishlatilishi paydo bo\'ldi. Bu YOMON '
              'EMAS — `filledButtonTheme` ikki mavzuda ham AA juftlik beradi. '
              'Faqat ro\'yxatni yangila (va yangi fon ishlatilsa kontrastni '
              'o\'lch).');
    });
  });
}
