/// WCAG AA KONTRAST QULFI — mavzu ranglari o'lchanadi, "chiroyli" deb
/// baholanmaydi.
///
/// NIMA UCHUN BU TEST BOR: `bodySmall` va `hintStyle` rangi mavzuda BIR JOYDA
/// belgilanadi, lekin 65+ joyda ko'rinadi. Ilgari u Slate 400 (#94A3B8) edi va
/// oq fon ustida 2.56:1 kontrast berardi — WCAG AA talabi (oddiy matn uchun
/// 4.5:1) dan ikki barobar past. Buni na `flutter analyze`, na widget testlari,
/// na skrinshotga qarash aniqlay olmaydi: rang "kulrang matn" bo'lib
/// KO'RINADI, faqat o'lchov nuqsonni ko'rsatadi.
///
/// Bu yerda rang QO'LDA yozilgan token nomiga ishonib emas, `app_theme.dart`
/// MANBASIDAN o'qib olinadi (qaysi token qaysi uslubga ULANGANI ajratiladi),
/// so'ng nisbat WCAG formulasi bilan hisoblanadi. Kimdir palitrani
/// "yumshoqroq" qilsa yoki mavzuni boshqa tokenga ulasa — test yiqiladi.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/tone.dart';

/// WCAG 2.1 nisbiy yorqinlik (relative luminance).
double _luminance(Color c) {
  double channel(double v) {
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  // `Color.r/g/b` 0..1 oralig'ida (Flutter 3.27+ keng gamut API).
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 kontrast nisbati — 1:1 dan 21:1 gacha.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Oddiy matn uchun WCAG AA.
const double kAaText = 4.5;

/// Grafik obyekt / UI komponenti (ikonka, chegara) uchun WCAG AA.
const double kAaNonText = 3.0;

/// `app_theme.dart` MANBASIDAN uslubga ulangan `AppColors` token nomini
/// ajratib oladi.
///
/// NIMA UCHUN MANBA, `ThemeData` EMAS: `AppTheme.lightTheme` ichida
/// `GoogleFonts.plusJakartaSansTextTheme()` chaqiriladi. Testda u shriftni
/// tarmoqdan olishga urinadi (`allowRuntimeFetching = false` bo'lsa esa
/// "asset topilmadi" deb) va xato test TUGAGANDAN KEYIN kelib, kontrast
/// tekshiruvi o'tgan bo'lsa ham suite'ni yiqitadi. Shriftni assetga qo'shish
/// bu testning vazifasi emas — bizni FAQAT rang ulanishi qiziqtiradi.
String themeTokenFor({required String getter, required String styleKey}) {
  final source = File('lib/core/theme/app_theme.dart').readAsStringSync();

  final getterAt = source.indexOf('get $getter');
  if (getterAt == -1) {
    throw StateError('`app_theme.dart` da `get $getter` topilmadi — '
        'mavzu API o\'zgargan, testni yangilang');
  }
  // Blok chegarasi: keyingi `static ThemeData get ...` yoki fayl oxiri.
  final nextGetter = source.indexOf('static ThemeData get', getterAt + 1);
  final block =
      source.substring(getterAt, nextGetter == -1 ? source.length : nextGetter);

  final styleAt = block.indexOf(styleKey);
  if (styleAt == -1) {
    throw StateError('`$getter` blokida `$styleKey` topilmadi — uslub '
        'o\'chirilgan yoki nomi o\'zgargan, testni yangilang');
  }
  final match =
      RegExp(r'AppColors\.(\w+)').firstMatch(block.substring(styleAt));
  if (match == null) {
    throw StateError('`$getter` > `$styleKey` uchun `AppColors.<token>` '
        'topilmadi — rang xom `Color(0x...)` bilan yozilgan bo\'lishi mumkin');
  }
  return match.group(1)!;
}

/// Token nomi → haqiqiy qiymat. Bu map ATAYLAB qo'lda yuritiladi: mavzuga
/// yangi token ulansa, test "xarita eskirgan" deb yiqiladi va kimdir uning
/// kontrastini ATAYLAB baholashi shart bo'ladi.
const Map<String, Color> kKnownTextTokens = <String, Color>{
  'textPrimaryLight': AppColors.textPrimaryLight,
  'textSecondaryLight': AppColors.textSecondaryLight,
  'textMutedLight': AppColors.textMutedLight,
  'textPrimaryDark': AppColors.textPrimaryDark,
  'textSecondaryDark': AppColors.textSecondaryDark,
  'textMutedDark': AppColors.textMutedDark,
};

Color resolveToken(String name) {
  final color = kKnownTextTokens[name];
  if (color == null) {
    throw StateError('`$name` tokeni `kKnownTextTokens` xaritasida yo\'q. '
        'Mavzuga yangi matn rangi ulangan — uni xaritaga qo\'shing, shunda '
        'kontrasti shu testda avtomatik o\'lchanadi.');
  }
  return color;
}

void main() {
  // DIQQAT: bu faylda `AppTheme.lightTheme` / `darkTheme` ATAYLAB
  // chaqirilmaydi. Ular `GoogleFonts.plusJakartaSansTextTheme()` ni
  // ishga soladi, u esa testda shriftni tarmoqdan olishga urinadi
  // (`allowRuntimeFetching = false` bo'lsa "asset topilmadi" deb yiqiladi) va
  // xato test TUGAGANDAN KEYIN kelib, kontrast tekshiruvlari o'tgan bo'lsa ham
  // suite'ni qizil qiladi. Shuning uchun mavzu ULANISHI manbadan o'qiladi
  // (`themeTokenFor`), rang esa `AppColors` dan olinadi: qulf kuchi
  // saqlanadi, shrift I/O esa umuman ishtirok etmaydi.

  group('formula o\'zi to\'g\'ri ishlaydi', () {
    // Qo'riqchining qo'riqchisi: agar formulani kimdir buzsa, quyidagi
    // testlar JIMGINA o'tib ketishi mumkin. Ma'lum qiymatlar bilan tekshiramiz.
    test('qora/oq = 21:1, bir xil rang = 1:1', () {
      expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          closeTo(21.0, 0.01));
      expect(contrast(AppColors.primary, AppColors.primary),
          closeTo(1.0, 0.001));
    });

    test('WebAIM bilan tekshirilgan namuna: #767676 oq ustida 4.54:1', () {
      expect(contrast(const Color(0xFF767676), const Color(0xFFFFFFFF)),
          closeTo(4.54, 0.02));
    });
  });

  group('manba ajratuvchisi to\'g\'ri tokenni oladi', () {
    // IKKINCHI QO'RIQCHINING QO'RIQCHISI: `themeTokenFor` regex bilan
    // ishlaydi. Agar u NOTO'G'RI `AppColors.*` ni ilib olsa (masalan qo'shni
    // uslubning rangini), yuqoridagi kontrast testlari JIMGINA o'tib ketardi —
    // "o'lchandi" degan da'vo yolg'on bo'lardi. Shuning uchun ulanish aynan
    // qulflanadi: mavzuda rang o'zgarsa, bu test ATAYLAB yiqiladi va kimdir
    // yangi tokenni baholashi shart bo'ladi.
    test('yorug\' mavzu ulanishi', () {
      expect(themeTokenFor(getter: 'lightTheme', styleKey: 'bodyLarge:'),
          'textPrimaryLight');
      expect(themeTokenFor(getter: 'lightTheme', styleKey: 'bodyMedium:'),
          'textSecondaryLight');
      expect(themeTokenFor(getter: 'lightTheme', styleKey: 'bodySmall:'),
          'textMutedLight');
      expect(themeTokenFor(getter: 'lightTheme', styleKey: 'hintStyle:'),
          'textMutedLight');
    });

    test('qorong\'i mavzu ulanishi', () {
      expect(themeTokenFor(getter: 'darkTheme', styleKey: 'bodyLarge:'),
          'textPrimaryDark');
      expect(themeTokenFor(getter: 'darkTheme', styleKey: 'bodyMedium:'),
          'textSecondaryDark');
      expect(themeTokenFor(getter: 'darkTheme', styleKey: 'bodySmall:'),
          'textSecondaryDark');
      expect(themeTokenFor(getter: 'darkTheme', styleKey: 'hintStyle:'),
          'textMutedDark');
    });

    test('yo\'q uslub / yo\'q token JIMGINA o\'tmaydi', () {
      // Agar ajratuvchi topa olmasa, `null` qaytarib "hammasi joyida" demasligi
      // KERAK — aks holda kimdir uslubni o'chirsa qulf o'chib qolardi.
      expect(
          () => themeTokenFor(getter: 'lightTheme', styleKey: 'yoqUslub:'),
          throwsStateError);
      expect(() => resolveToken('yoqToken'), throwsStateError);
    });
  });

  group('YORUG\' mavzu — matn ranglari', () {
    final surfaces = <String, Color>{
      'surfaceLight': AppColors.surfaceLight,
      'backgroundLight': AppColors.backgroundLight,
    };

    void expectAaOnAllSurfaces(String label, Color? color) {
      expect(color, isNotNull, reason: '$label mavzuda belgilanmagan');
      surfaces.forEach((surfaceName, surface) {
        final ratio = contrast(color!, surface);
        expect(ratio, greaterThanOrEqualTo(kAaText),
            reason: '$label ($color) $surfaceName ustida '
                '${ratio.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak');
      });
    }

    test('bodySmall AA dan o\'tadi', () {
      // BU AYNAN YIQILGAN JOY: 2.56:1. `bodySmall` — kartochka izohlari,
      // "N ta javob", sana, bo'lim tavsiflari.
      final token =
          themeTokenFor(getter: 'lightTheme', styleKey: 'bodySmall:');
      expectAaOnAllSurfaces(
          'lightTheme.bodySmall → AppColors.$token', resolveToken(token));
    });

    test('bodyMedium va bodyLarge AA dan o\'tadi', () {
      for (final styleKey in <String>['bodyMedium:', 'bodyLarge:']) {
        final token = themeTokenFor(getter: 'lightTheme', styleKey: styleKey);
        expectAaOnAllSurfaces(
            'lightTheme.$styleKey → AppColors.$token', resolveToken(token));
      }
    });

    test('TextField ko\'rsatmasi (hintStyle) AA dan o\'tadi', () {
      // Placeholder ham MATN: foydalanuvchi maydonga nima yozishini SHUNDAN
      // biladi. WCAG uni istisno qilmaydi.
      final token = themeTokenFor(getter: 'lightTheme', styleKey: 'hintStyle:');
      expectAaOnAllSurfaces(
          'lightTheme.hintStyle → AppColors.$token', resolveToken(token));
    });

    test('textMuted tokeni AA dan o\'tadi', () {
      // 26 dan ortiq joyda TO'G'RIDAN ishlatiladi (mavzu orqali emas).
      expectAaOnAllSurfaces('AppColors.textMutedLight', AppColors.textMutedLight);
      expectAaOnAllSurfaces(
          'AppColors.textSecondaryLight', AppColors.textSecondaryLight);
      expectAaOnAllSurfaces(
          'AppColors.textPrimaryLight', AppColors.textPrimaryLight);
    });
  });

  group('QORONG\'I mavzu — matn ranglari', () {
    final surfaces = <String, Color>{
      'surfaceDark': AppColors.surfaceDark,
      'backgroundDark': AppColors.backgroundDark,
      'cardDark': AppColors.cardDark,
    };

    void expectAaOnAllSurfaces(String label, Color? color) {
      expect(color, isNotNull, reason: '$label mavzuda belgilanmagan');
      surfaces.forEach((surfaceName, surface) {
        final ratio = contrast(color!, surface);
        expect(ratio, greaterThanOrEqualTo(kAaText),
            reason: '$label ($color) $surfaceName ustida '
                '${ratio.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak');
      });
    }

    test('bodySmall / bodyMedium / hintStyle AA dan o\'tadi', () {
      for (final styleKey in <String>[
        'bodySmall:',
        'bodyMedium:',
        'hintStyle:',
      ]) {
        final token = themeTokenFor(getter: 'darkTheme', styleKey: styleKey);
        expectAaOnAllSurfaces(
            'darkTheme.$styleKey → AppColors.$token', resolveToken(token));
      }
    });

    test('textMutedDark AA dan o\'tadi', () {
      expectAaOnAllSurfaces('AppColors.textMutedDark', AppColors.textMutedDark);
      expectAaOnAllSurfaces(
          'AppColors.textSecondaryDark', AppColors.textSecondaryDark);
    });
  });

  group('IKONKA sifatida ishlatilgan tokenlar (3:1)', () {
    test('textMutedLight filtrsiz ishlatilgan joylar uchun ham yetarli', () {
      // O'LCHANGAN HOLAT: `textMutedLight` bir necha ekranda `isDark`
      // tekshiruvisiz, ya'ni QORONG'I mavzuda HAM ishlatiladi — lekin faqat
      // IKONKA sifatida (bo'sh holat piktogrammasi, chevron, chat pufagi).
      // Matn uchun 4.5:1 talab qilinmaydi, grafik obyekt uchun 3:1 kifoya.
      //
      // Agar kimdir shu tokenni qorong'i mavzuda MATN uchun ishlatsa, bu test
      // uni ushlamaydi — shuning uchun to'g'ri yechim baribir `isDark ?
      // textMutedDark : textMutedLight` yozish.
      for (final entry in <String, Color>{
        'surfaceDark': AppColors.surfaceDark,
        'backgroundDark': AppColors.backgroundDark,
        'cardDark': AppColors.cardDark,
      }.entries) {
        final ratio = contrast(AppColors.textMutedLight, entry.value);
        expect(ratio, greaterThanOrEqualTo(kAaNonText),
            reason: 'textMutedLight ${entry.key} ustida '
                '${ratio.toStringAsFixed(2)}:1 — ikonka uchun '
                '$kAaNonText:1 kerak');
      }
    });

    test('chegara (border) ranglari fondan ajralib turadi', () {
      // Chegara — UI komponenti: 3:1 talab qilinadi. Bu ATAYLAB alohida
      // guruhda: dekorativ ajratgich (`divider*`) bu talabga kirmaydi va
      // shuning uchun tekshirilmaydi.
      expect(contrast(AppColors.borderLight, AppColors.surfaceLight),
          lessThan(kAaNonText),
          reason: 'MA\'LUM VA QABUL QILINGAN QARZ: borderLight (#E2E8F0) oq '
              'ustida 3:1 dan past. Bu kartochka konturi — mazmun uzatmaydi, '
              'chunki har bir kartochkada sarlavha matni bor. Agar chegara '
              'YAGONA ajratuvchi bo\'lib qolsa, bu qarzni to\'lash kerak. '
              'Test ATAYLAB "past" holatni qulflaydi: kimdir uni tuzatsa, '
              'shu izohni ham yangilashi shart.');
    });
  });

  group('YORLIQ ranglari — brend fonlar ustida', () {
    test('oq MATN qo\'yiladigan fonlar AA dan o\'tadi', () {
      // Hero karta, SOS banneri, markaziy tugma, xato SnackBar'i va
      // favqulodda "qo'ng'iroq qilish" tugmasi — hammasi oq MATN to'q fonda.
      for (final entry in <String, Color>{
        'primary': AppColors.primary,
        'primaryDark': AppColors.primaryDark,
        'crimsonDark': AppColors.crimsonDark,
        'emergencyStrong': AppColors.emergencyStrong,
        'indigoDark': AppColors.indigoDark,
      }.entries) {
        final ratio = contrast(const Color(0xFFFFFFFF), entry.value);
        expect(ratio, greaterThanOrEqualTo(kAaText),
            reason: 'oq matn ${entry.key} ustida '
                '${ratio.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak');
      }
    });

    test('emergency (#EF4444) MATN foni sifatida AA dan O\'TMAYDI', () {
      // ATAYLAB "o'tmaydi" holatini qulflaymiz. Bu token 28 joyda ishlatiladi
      // va HAMMASI grafik (ikonka, chegara, xato tinti) — grafik uchun 3:1
      // kifoya va u o'tadi. Ammo kimdir uni yana oq matn ostiga FON qilib
      // qo'ysa (ilgari uchta joyda shunday bo'lgan), bu test eslatib turadi:
      // to'g'ri token — `emergencyStrong`.
      final ratio = contrast(const Color(0xFFFFFFFF), AppColors.emergency);
      expect(ratio, greaterThanOrEqualTo(kAaNonText),
          reason: 'ikonka uchun ham yetmay qoldi');
      expect(ratio, lessThan(kAaText),
          reason: 'Agar bu yiqilsa — demak `emergency` endi AA\'dan o\'tadi '
              'va `emergencyStrong` tokeni ortiqcha bo\'lib qoldi: ikkisini '
              'birlashtirib, shu testni ham yangilang.');
    });
  });

  group('AKSENT TINTI ustidagi matn (ishonch raqamlari)', () {
    // `Tezkor Huquqlar` ekranidagi ishonch telefonlari kartochkasi fonni
    // `aksent@8%` (yorug') / `aksent@16%` (qorong'i) qilib bo'yaydi. Matn
    // ilgari AYNI aksentda yozilardi va real emulyator pikselida 2.10:1 gacha
    // tushardi. Bu yerda alfa 0..0.20 BUTUN oralig'i tekshiriladi: dizayner
    // tintni quyuqlashtirsa ham qulf ushlab turadi.
    Color over(Color tint, double alpha, Color page) => Color.from(
          alpha: 1,
          red: tint.r * alpha + page.r * (1 - alpha),
          green: tint.g * alpha + page.g * (1 - alpha),
          blue: tint.b * alpha + page.b * (1 - alpha),
        );

    double worstOverBand(Color text, Color tint, Color page) {
      var worst = 21.0;
      for (var step = 0; step <= 20; step++) {
        final ratio = contrast(text, over(tint, step / 100, page));
        if (ratio < worst) worst = ratio;
      }
      return worst;
    }

    void expectBandAa(String label, Color text, Color tint, Color page) {
      final worst = worstOverBand(text, tint, page);
      expect(worst, greaterThanOrEqualTo(kAaText),
          reason: '$label: tint alfasi 0..0.20 oralig\'ida eng yomon holat '
              '${worst.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak');
    }

    test('YORUG\' mavzu: raqam matni AA dan o\'tadi', () {
      const page = AppColors.backgroundLight;
      expectBandAa('1002', AppColors.primary, AppColors.primary, page);
      expectBandAa('102', AppColors.emergencyStrong, AppColors.crimson, page);
      expectBandAa('1096', AppColors.lexBlueStrong, AppColors.lexBlue, page);
      expectBandAa('1092', AppColors.emeraldStrong, AppColors.emerald, page);
    });

    test('QORONG\'I mavzu: raqam matni AA dan o\'tadi', () {
      const page = AppColors.backgroundDark;
      expectBandAa('1002', AppColors.indigoOnDark, AppColors.indigo, page);
      expectBandAa('102', AppColors.emergencyDark, AppColors.crimson, page);
      expectBandAa('1096', AppColors.lexBlueOnDark, AppColors.lexBlue, page);
      expectBandAa('1092', AppColors.emeraldOnDark, AppColors.emerald, page);
    });

    test('ESKI holat (aksentning O\'ZI matn sifatida) AA dan O\'TMAYDI', () {
      // Nuqsonni ATAYLAB qulflaymiz: kimdir `onTint` ni olib tashlab yana
      // `color` ni matnga bersa, quyidagi da'volar buzilib bu testni
      // yiqitadi — ya'ni regressiya JIMGINA o'tib ketmaydi.
      for (final entry in <String, Color>{
        '102 #EF4444': AppColors.crimson,
        '1096 #0284C7': AppColors.lexBlue,
        '1092 #10B981': AppColors.emerald,
      }.entries) {
        final worst =
            worstOverBand(entry.value, entry.value, AppColors.backgroundLight);
        expect(worst, lessThan(kAaText),
            reason: '${entry.key}: to\'yingan aksent o\'z tinti ustida endi '
                'AA\'dan o\'tayotgan ko\'rinadi — palitra o\'zgargan bo\'lsa, '
                '`emergency_rights_page.dart` dagi `onTint` yechimini va shu '
                'testni birga qayta baholang.');
      }
    });
  });

  group('AppTone — yorliq (badge) juftliklari', () {
    // `AppTone` har bir semantik holat uchun UCHTA rangni bog'laydi: tint/
    // chegara uchun aksent va matn uchun yorug'/qorong'i juftlik. Bu yerda
    // MATN jufti aksent tintining ustida tekshiriladi.
    //
    // MUHIM FARQ (yuqoridagi guruhdan): yuza IKKITA — karta VA sahifa foni.
    // Sabab: yorliq odatda KARTA ichida turadi, karta esa qorong'ida
    // (#1E293B) sahifadan (#0A192F) yorqinroq, ya'ni matn kontrasti PASTROQ.
    // Yuqoridagi guruh faqat sahifa fonini tekshiradi va shuning uchun
    // `emergencyDark`/`indigoOnDark` ni o'tkazadi — karta ustida esa ular
    // yiqiladi (pastdagi salbiy testda o'lchangan).
    Color over(Color tint, double alpha, Color page) => Color.from(
          alpha: 1,
          red: tint.r * alpha + page.r * (1 - alpha),
          green: tint.g * alpha + page.g * (1 - alpha),
          blue: tint.b * alpha + page.b * (1 - alpha),
        );

    double worstOn(Color text, Color tint, List<Color> pages) {
      var worst = 21.0;
      for (final page in pages) {
        for (var step = 0; step <= 20; step++) {
          final ratio = contrast(text, over(tint, step / 100, page));
          if (ratio < worst) worst = ratio;
        }
      }
      return worst;
    }

    const List<Color> lightSurfaces = <Color>[
      AppColors.surfaceLight,
      AppColors.backgroundLight,
    ];
    const List<Color> darkSurfaces = <Color>[
      AppColors.cardDark,
      AppColors.backgroundDark,
    ];

    const Map<String, AppTone> tones = <String, AppTone>{
      'danger': AppTone.danger,
      'success': AppTone.success,
      'warning': AppTone.warning,
      'info': AppTone.info,
      'brand': AppTone.brand,
      'accentIndigo': AppTone.accentIndigo,
      'critical': AppTone.critical,
      'neutral': AppTone.neutral,
    };

    test('YORUG\' mavzu: har bir tone AA dan o\'tadi', () {
      tones.forEach((String name, AppTone tone) {
        final worst =
            worstOn(tone.onTintLight, tone.accentLight, lightSurfaces);
        expect(worst, greaterThanOrEqualTo(kAaText),
            reason: 'AppTone.$name (yorug\'): alfa 0..0.20 va oq/#F8FAFC '
                'yuzalarida eng yomon ${worst.toStringAsFixed(2)}:1 — '
                'AA uchun $kAaText:1 kerak');
      });
    });

    test('QORONG\'I mavzu: har bir tone AA dan o\'tadi', () {
      tones.forEach((String name, AppTone tone) {
        final worst = worstOn(tone.onTintDark, tone.accentDark, darkSurfaces);
        expect(worst, greaterThanOrEqualTo(kAaText),
            reason: 'AppTone.$name (qorong\'i): alfa 0..0.20 va '
                '#1E293B/#0A192F yuzalarida eng yomon '
                '${worst.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak');
      });
    });

    test('`*OnTint` tokenlar NIMA UCHUN kerak — eski tokenlar yiqiladi', () {
      // Bu test ATAYLAB "o'tmaydi" holatini qulflaydi. Agar u yiqilsa —
      // demak palitra o'zgardi va `AppTone` juftliklarini qayta o'lchash
      // kerak (ehtimol qo'shimcha tokenlar ortiqcha bo'lib qoldi).
      final Map<String, double> measured = <String, double>{
        // `amberStrong` (#B45309) TEKIS oq ustida 5.02:1 — lekin amber
        // tintida 4.15:1. Shu sabab `amberOnTint` (#92400E) kiritildi.
        'amberStrong amber tintida':
            worstOn(AppColors.amberStrong, AppColors.amber, lightSurfaces),
        // `electricBlue` (#2563EB) tekis oq ustida 5.17:1 — ko'k tintida
        // 3.94:1. Shu sabab `blueOnTint` (#1D4ED8) kiritildi.
        'electricBlue ko\'k tintida': worstOn(
            AppColors.electricBlue, AppColors.electricBlue, lightSurfaces),
        // `emergencyDark` (#F87171) sahifa fonida 5.25:1, KARTA ustida
        // 4.38:1. Shu sabab `crimsonOnTintDark` (#FCA5A5) kiritildi.
        'emergencyDark karta ustida':
            worstOn(AppColors.emergencyDark, AppColors.crimson, darkSurfaces),
        // `indigoOnDark` (#818CF8) sahifa fonida 4.73:1, KARTA ustida
        // 3.95:1. Shu sabab `indigoOnTintDark` (#A5B4FC) kiritildi.
        'indigoOnDark karta ustida':
            worstOn(AppColors.indigoOnDark, AppColors.indigo, darkSurfaces),
      };

      measured.forEach((String label, double worst) {
        expect(worst, lessThan(kAaText),
            reason: '$label: ${worst.toStringAsFixed(2)}:1 — endi AA\'dan '
                'o\'tayotgan ko\'rinadi. Palitra o\'zgargan bo\'lsa, '
                '`AppTone` juftliklarini qayta o\'lchang.');
      });
    });
  });

  group('SnackBar mavzusi — BATCH 4', () {
    // `app_theme.dart` da `snackBarTheme` YO'Q edi: fon har bir chaqiruv
    // joyidan kelardi, matn rangi esa M3 ning `onInverseSurface` idan.
    // Endi fon markazda (`primaryLight` / `cardDark`), matn ATAYLAB oq va
    // harakat yorlig'i `amberLight` — chaqiruv joylari fonni faqat shu uch
    // "Strong" tokenga o'zgartiradi. Qulf shu TO'RT fon uchun.
    const Map<String, Color> snackBackgrounds = <String, Color>{
      'primaryLight (yorug\' standart)': AppColors.primaryLight,
      'cardDark (qorong\'i standart)': AppColors.cardDark,
      'emergencyStrong (xato)': AppColors.emergencyStrong,
      'emeraldStrong (muvaffaqiyat)': AppColors.emeraldStrong,
      'amberStrong (ogohlantirish)': AppColors.amberStrong,
    };

    test('oq MAZMUN matni barcha SnackBar fonlarida AA dan o\'tadi', () {
      snackBackgrounds.forEach((String name, Color bg) {
        final ratio = contrast(const Color(0xFFFFFFFF), bg);
        expect(ratio, greaterThanOrEqualTo(kAaText),
            reason: 'oq SnackBar matni $name ustida '
                '${ratio.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak. '
                'Chaqiruv joyi fonni o\'zgartirsa, shu ro\'yxatga qo\'shilishi '
                'SHART.');
      });
    });

    test('`amberLight` HARAKAT yorlig\'i barcha fonlarda AA dan o\'tadi', () {
      // NIMA UCHUN `amberOnTintDark` EMAS: u `emergencyStrong` ustida
      // 4.49:1 beradi — chegaradan past. `amberLight` (#FEF3C7) esa to'rt
      // fonning HAMMASIDA o'tadi.
      snackBackgrounds.forEach((String name, Color bg) {
        final ratio = contrast(AppColors.amberLight, bg);
        expect(ratio, greaterThanOrEqualTo(kAaText),
            reason: '`amberLight` harakat yorlig\'i $name ustida '
                '${ratio.toStringAsFixed(2)}:1 — AA uchun $kAaText:1 kerak');
      });
    });

    test('eski chaqiruv joyi fonlari ATAYLAB o\'tmaydi', () {
      // Bu uchtasi ilgani oq matn ostida FON bo'lgan (`question_detail_page`,
      // `community_forum_page`). Qulf: kimdir ularni qaytarsa test aytadi.
      final Map<String, double> tooWeak = <String, double>{
        'crimson': contrast(const Color(0xFFFFFFFF), AppColors.crimson),
        'emerald': contrast(const Color(0xFFFFFFFF), AppColors.emerald),
        'amber': contrast(const Color(0xFFFFFFFF), AppColors.amber),
      };
      tooWeak.forEach((String name, double ratio) {
        expect(ratio, lessThan(kAaText),
            reason: '$name endi oq matn bilan '
                '${ratio.toStringAsFixed(2)}:1 — AA\'dan o\'tayotgan '
                'ko\'rinadi. Palitra o\'zgargan bo\'lsa, "Strong" tokenlar '
                'hamon kerakmi degan savolni qayta baholang.');
      });
    });
  });

  group('TANLANGAN chip/CTA yuzalari — BATCH 4', () {
    test('oq 12 px bold yorliq `indigoDark` ustida AA dan o\'tadi', () {
      // `community_forum_page` `FilterChip`, `legal_experts_page`
      // `ChoiceChip`, `question_detail_page` `FilterChip` va FAB — hammasi
      // tanlangan holatda TO'LDIRILGAN yuza + oq yorliq.
      final ratio = contrast(const Color(0xFFFFFFFF), AppColors.indigoDark);
      expect(ratio, greaterThanOrEqualTo(kAaText),
          reason: 'oq yorliq `indigoDark` ustida '
              '${ratio.toStringAsFixed(2)}:1');
    });

    test('`indigo` to\'ldirilgan yuza + oq MATN ATAYLAB o\'tmaydi', () {
      // 12 px bold "yirik matn" EMAS (yirik = 18.66 px bold), shuning uchun
      // 4.47:1 yetmaydi. `indigo` faqat GRAFIK yuza sifatida qoladi
      // (masalan `legal_experts_page` sarlavha ikonkasi konteyneri).
      final ratio = contrast(const Color(0xFFFFFFFF), AppColors.indigo);
      expect(ratio, greaterThanOrEqualTo(kAaNonText),
          reason: 'grafik uchun ham yetmay qoldi');
      expect(ratio, lessThan(kAaText),
          reason: '`indigo` endi oq MATN uchun ham yetarli ko\'rinadi — '
              'shunda `indigoDark` almashtirishlari ortiqcha bo\'ladi, '
              'ikkisini birga qayta baholang.');
    });

    test('tanlangan yuza KONTURI qorong\'i sahifada 3:1 dan o\'tadi', () {
      // `indigoDark` fon `backgroundDark`/`surfaceDark` ustida 2.80:1 —
      // 1.4.11 dan PAST, ya'ni tanlangan chip'ning cheti ko'rinmaydi.
      // Yechim: qorong'ida chegara `indigoOnTintDark` da SAQLANADI.
      for (final page in <Color>[
        AppColors.backgroundDark,
        AppColors.surfaceDark,
      ]) {
        final fill = contrast(AppColors.indigoDark, page);
        expect(fill, lessThan(kAaNonText),
            reason: 'fon-yuza chegarasi ${fill.toStringAsFixed(2)}:1 — endi '
                '3:1 dan o\'tayotgan ko\'rinadi, chegara endi kerak emasmi?');
        final border = contrast(AppColors.indigoOnTintDark, page);
        expect(border, greaterThanOrEqualTo(kAaNonText),
            reason: 'chegara ${border.toStringAsFixed(2)}:1 — 1.4.11 uchun '
                '$kAaNonText:1 kerak');
      }
    });

    test('qorong\'i dialog CTA: to\'q yorliq yorqin fonda AA dan o\'tadi', () {
      // `ask_community_dialog.showAuthRequiredDialog`: `primary` fon
      // qorong'i dialog yuzasi (`surfaceDark`) bilan AYNI rang — 1.00:1,
      // ya'ni tugma KO'RINMASDI. Yechim: yorqin `indigoOnTintDark` fon +
      // to'q `primary` yorliq; yuza chegarasi ham AYNI juftlikdan keladi.
      final label = contrast(AppColors.primary, AppColors.indigoOnTintDark);
      expect(label, greaterThanOrEqualTo(kAaText),
          reason: 'yorliq ${label.toStringAsFixed(2)}:1');
      final surface = contrast(AppColors.indigoOnTintDark, AppColors.surfaceDark);
      expect(surface, greaterThanOrEqualTo(kAaNonText),
          reason: 'yuza chegarasi ${surface.toStringAsFixed(2)}:1');
      // Va eski holat ATAYLAB qulflanadi: `primary` = `surfaceDark`.
      expect(contrast(AppColors.primary, AppColors.surfaceDark), lessThan(1.05),
          reason: '`primary` va `surfaceDark` endi farq qiladi — palitra '
              'o\'zgargan bo\'lsa, bu izohni yangilang.');
    });
  });
}
