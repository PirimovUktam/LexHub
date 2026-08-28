/// XOM DATA RANGI -> TON KO'CHIRISHI — QULF.
///
/// NUQSON (qurilmada o'lchangan, `19_konstruktor_dark.png`): Hujjatlar
/// Konstruktori kartasidagi kategoriya badge'i qorong'i mavzuda BO'SH qora
/// to'rtburchak bo'lib ko'rinardi. Sabab: `template.color` Data qatlamidan
/// keladi (`document_templates_datasource.dart`,
/// `document_templates_local_datasource.dart`,
/// `document_template_model.dart`) va UI shu XOM rangni MATN hamda IKONKA
/// rangi qilib ishlatardi. `AppColors.primary` (#0F172A) badge foni
/// `surfaceDark` (#0F172A) ustida aynan 1.00:1 beradi.
///
/// Bu test IKKI narsani qulflaydi:
///   1. Data qatlamida ishlatilgan HAR BIR xom rang `AppTone.forRawAccent`
///      orqali AA'dan yuqori juftlik beradi (badge matni 4.5:1, ikonka 3:1).
///   2. Xom rangning O'ZI shu talabni BAJARMAYDI — ya'ni ko'chirish
///      haqiqatan zarur; "to'g'ridan-to'g'ri ishlatsak ham bo'ladi" degan
///      qaytish bloklanadi.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/tone.dart';

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

void main() {
  // Badge foni (`document_templates_page.dart`) va karta yuzasi.
  const badgeDark = AppColors.surfaceDark;
  const badgeLight = AppColors.backgroundLight;
  const cardDark = AppColors.cardDark;
  const cardLight = Colors.white;

  /// Data qatlamida HAQIQATAN biriktirilgan xom ranglar.
  const rawAccents = <String, Color>{
    'emerald': AppColors.emerald,
    'primary': AppColors.primary,
    'lexBlue': AppColors.lexBlue,
    'amberDark': AppColors.amberDark,
    'indigo': AppColors.indigo,
    'amber': AppColors.amber,
  };

  group('AppTone.forRawAccent — badge yorlig\'i AA', () {
    for (final e in rawAccents.entries) {
      test('${e.key}: badge matni ikki mavzuda ham >= 4.5:1', () {
        final tone = AppTone.forRawAccent(e.value);
        expect(_contrast(tone.on(true), badgeDark), greaterThanOrEqualTo(4.5),
            reason: '${e.key} qorong\'i badge');
        expect(_contrast(tone.on(false), badgeLight), greaterThanOrEqualTo(4.5),
            reason: '${e.key} yorug\' badge');
      });
    }
  });

  group('AppTone.forRawAccent — tint ustidagi ikonka (1.4.11 -> 3:1)', () {
    for (final e in rawAccents.entries) {
      test('${e.key}: ikonka tint ustida >= 3:1', () {
        final tone = AppTone.forRawAccent(e.value);
        final tintDark = Color.alphaBlend(tone.bg(true), cardDark);
        final tintLight = Color.alphaBlend(tone.bg(false), cardLight);
        expect(_contrast(tone.on(true), tintDark), greaterThanOrEqualTo(3.0),
            reason: '${e.key} qorong\'i tint');
        expect(_contrast(tone.on(false), tintLight), greaterThanOrEqualTo(3.0),
            reason: '${e.key} yorug\' tint');
      });
    }
  });

  test('XOM rangning O\'ZI yaramaydi — ko\'chirish ZARUR', () {
    final failing = <String>[];
    for (final e in rawAccents.entries) {
      final d = _contrast(e.value, badgeDark);
      final l = _contrast(e.value, badgeLight);
      if (d < 4.5 || l < 4.5) failing.add(e.key);
    }
    expect(failing.toSet(), rawAccents.keys.toSet(),
        reason: 'xom ranglardan biri endi o\'zi ham ikki mavzuda AA beradi — '
            'o\'lchovni va `forRawAccent` izohini yangila');
  });

  test('`primary` qorong\'i badge fonida aynan ko\'rinmas edi (1.00:1)', () {
    expect(_contrast(AppColors.primary, badgeDark), closeTo(1.0, 0.02));
    expect(
        _contrast(
            AppTone.forRawAccent(AppColors.primary).on(true), badgeDark),
        greaterThan(15.0));
  });

  test('noma\'lum rang neytral tonga tushadi (ko\'rinmas bo\'lib qolmaydi)',
      () {
    const unknown = Color(0xFF123456);
    final tone = AppTone.forRawAccent(unknown);
    expect(tone, same(AppTone.neutral));
    expect(_contrast(tone.on(true), badgeDark), greaterThanOrEqualTo(4.5));
    expect(_contrast(tone.on(false), badgeLight), greaterThanOrEqualTo(4.5));
  });

  test('rang kodlash SAQLANADI — semantik ranglar neytralga tushmaydi', () {
    expect(AppTone.forRawAccent(AppColors.emerald), same(AppTone.success));
    expect(AppTone.forRawAccent(AppColors.amber), same(AppTone.warning));
    expect(AppTone.forRawAccent(AppColors.amberDark), same(AppTone.warning));
    expect(AppTone.forRawAccent(AppColors.indigo), same(AppTone.accentIndigo));
    expect(AppTone.forRawAccent(AppColors.lexBlue), same(AppTone.info));
    expect(AppTone.forRawAccent(AppColors.crimson), same(AppTone.danger));
  });

  test('`document_templates_page.dart` xom rangni MATN/IKONKA qilmaydi', () {
    final src = File(
            'lib/features/document_builder/presentation/pages/document_templates_page.dart')
        .readAsStringSync();
    expect(src.contains('AppTone.forRawAccent(template.color)'), isTrue,
        reason: 'ton ko\'chirishi olib tashlangan');
    expect(src.contains('color: template.color'), isFalse,
        reason: 'xom rang yana to\'g\'ridan-to\'g\'ri ishlatilgan');
    expect(src.contains('template.color.withValues'), isFalse,
        reason: 'xom rang tint foni qilib qaytarilgan');
  });

  test('ton kartasi TO\'LIQ — keyin qo\'shilgan juftliklar ham qulflandi', () {
    expect(AppTone.forRawAccent(AppColors.emeraldDark), same(AppTone.success));
    expect(
        AppTone.forRawAccent(AppColors.indigoDark), same(AppTone.accentIndigo));
    expect(AppTone.forRawAccent(AppColors.lexBlueDark), same(AppTone.info));
    expect(AppTone.forRawAccent(AppColors.crimsonDark), same(AppTone.danger));
    expect(AppTone.forRawAccent(AppColors.emergency), same(AppTone.danger));
    expect(
        AppTone.forRawAccent(AppColors.emergencyStrong), same(AppTone.danger));
    expect(
        AppTone.forRawAccent(AppColors.riskCritical), same(AppTone.critical));
    expect(AppTone.forRawAccent(AppColors.electricBlue), same(AppTone.brand));
    // `AppColors.accent` == `amber` (QIYMAT bo'yicha) -> warning.
    expect(AppTone.forRawAccent(AppColors.accent), same(AppTone.warning));
  });

  /// OQ ustki qatlam uchun to'ldirma jadvali. `snackBarTheme`
  /// `contentTextStyle`ni IKKI mavzuda ham OQ 14 px w500 qilib QULFLAYDI,
  /// ya'ni SnackBar foni oq MATN uchun 4.5:1 berishi SHART. Bu guruh
  /// "qaysi to'ldirma mumkin" savoliga o'lchov bilan javob beradi.
  group('oq ustki qatlam uchun to\'ldirmalar', () {
    const failsAsText = <String, Color>{
      'crimson': AppColors.crimson, // 3.76
      'emerald': AppColors.emerald, // 2.54
      'emeraldDark': AppColors.emeraldDark, // 3.77
      'amberDark': AppColors.amberDark, // 3.19
      'indigo': AppColors.indigo, // 4.47
    };
    const okAsText = <String, Color>{
      'emergencyStrong': AppColors.emergencyStrong, // 6.47
      'emeraldStrong': AppColors.emeraldStrong, // 7.68
      'amberOnTint': AppColors.amberOnTint, // 7.09
      'indigoDark': AppColors.indigoDark, // 6.29
      'crimsonDark': AppColors.crimsonDark, // 4.83
      'primary': AppColors.primary, // 17.85
    };
    for (final e in failsAsText.entries) {
      test('${e.key}: oq MATN uchun YARAMAYDI', () {
        expect(_contrast(Colors.white, e.value), lessThan(4.5));
      });
    }
    for (final e in okAsText.entries) {
      test('${e.key}: oq MATN uchun AA beradi', () {
        expect(_contrast(Colors.white, e.value), greaterThanOrEqualTo(4.5));
      });
    }
  });
  /// FRAMEWORK TINTI — grep bilan TOPILMAYDIGAN sinf.
  ///
  /// `ListTile(selected: true)` sarlavha, tavsif va ikonkalarni
  /// `colorScheme.primary` bilan bo'yaydi. Bu rang widget MANBASIDA
  /// yozilmaydi, shuning uchun xom-rang sweep'i uni ko'rmaydi — nuqson
  /// faqat QURILMA pikselidan topildi (`04_til_dark.png`: tanlangan
  /// "O'zbekcha" sarlavhasi #6366F1, karta yuzasi #1E293B = 3.27:1, ya'ni
  /// TANLANGAN qator ekrandagi eng xira matn edi).
  group('`ListTile(selected:)` framework tinti', () {
    // Mavzuni sinovda QURIB bo'lmaydi: `AppTheme` `GoogleFonts` ga tayanadi,
    // u esa shriftni tarmoqdan/asset'dan yuklaydi va sinov muhitida
    // istisno tashlaydi. Shuning uchun qulf ikki qismdan: (1) MANBA
    // ulanishi, (2) SOF O'LCHOV.
    final src = File('lib/core/theme/app_theme.dart').readAsStringSync();
    final split = src.indexOf('static ThemeData get darkTheme');
    final lightBlock = src.substring(0, split);
    final darkBlock = src.substring(split);

    test('qorong\'i mavzu `listTileTheme` ni to\'yingan juftga ulaydi', () {
      expect(darkBlock.contains('selectedColor: AppColors.indigoOnTintDark'),
          isTrue,
          reason: 'qorong\'i `listTileTheme` olib tashlangan — framework yana '
              '`colorScheme.primary` (xom `indigo`) ga qaytadi');
      expect(_contrast(AppColors.indigoOnTintDark, AppColors.cardDark),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.indigoOnTintDark, AppColors.surfaceDark),
          greaterThanOrEqualTo(4.5));
    });

    test('ko\'chirish ZARUR — qorong\'i `colorScheme.primary` o\'zi yiqiladi',
        () {
      expect(darkBlock.contains('primary: AppColors.indigo,'), isTrue,
          reason: 'qorong\'i sxema `primary` si o\'zgargan — o\'lchovni yangila');
      // Sarlavha 16 px w700, tavsif 14 px — "yirik matn" EMAS, talab 4.5:1.
      expect(_contrast(AppColors.indigo, AppColors.cardDark), lessThan(4.5));
    });

    test('yorug\' tomon piksel O\'ZGARMAYDI', () {
      expect(lightBlock.contains('primary: AppColors.primary,'), isTrue);
      expect(lightBlock.contains('selectedColor: AppColors.primary'), isTrue,
          reason: 'yorug\' `listTileTheme` sxema `primary` sidan boshqa '
              'qiymatga o\'tgan — piksel o\'zgaradi');
      expect(_contrast(AppColors.primary, cardLight),
          greaterThanOrEqualTo(4.5));
    });
  });

  /// SnackBar / to'ldirilgan yuza fonlari uchun MANBA QULFI. Har bir qaytish
  /// (`backgroundColor: AppColors.crimson,` va h.k.) oq matnni AA'dan pastga
  /// tushiradi — yuqoridagi guruh buni o'lchov bilan ko'rsatadi.
  test('hech bir fayl oq matnli yuzaga zaif to\'ldirma bermaydi', () {
    const banned = <String>[
      'backgroundColor: AppColors.crimson,',
      'backgroundColor: AppColors.emerald,',
      'backgroundColor: AppColors.emeraldDark,',
      'backgroundColor: AppColors.emergency,',
      'backgroundColor: AppColors.amberDark,',
    ];
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final b in banned) {
        if (src.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty,
        reason: 'oq matn/glif uchun `emergencyStrong` (6.47), `emeraldStrong` '
            '(7.68), `amberOnTint` (7.09) yoki `crimsonDark` (4.83) ishlat');
  });

  test('`quick_access_grid.dart` xom rangni ikonkaga bermaydi', () {
    final src = File(
            'lib/features/home/presentation/widgets/quick_access_grid.dart')
        .readAsStringSync();
    expect(src.contains('AppTone.forRawAccent(item.color)'), isTrue);
    // Izohda `_lighten()` SO'ZI bor (nima uchun rad etilgani yozilgan),
    // shuning uchun qulf FUNKSIYA o'zini qidiradi, matnni emas.
    expect(src.contains('Color _lighten('), isFalse,
        reason: 'qorong\'i tomon uchun qo\'lbola yorug\'lantirish qaytgan');
  });

  group('`primary` == `surfaceDark` tuzog\'i — ko\'chirilgan saytlar', () {
    test('til tanlash: radio va ramka qorong\'ida ko\'rinmas edi', () {
      expect(_contrast(AppColors.primary, AppColors.surfaceDark),
          closeTo(1.0, 0.02));
      expect(_contrast(AppColors.primary, AppColors.cardDark), lessThan(3.0));
      expect(_contrast(AppTone.neutral.on(true), AppColors.surfaceDark),
          greaterThanOrEqualTo(3.0));
      expect(_contrast(AppTone.neutral.on(true), AppColors.cardDark),
          greaterThanOrEqualTo(3.0));
      // Yorug' tomon PIKSELMA-PIKSEL o'zgarmadi — ko'chirish xavfsiz.
      expect(AppTone.neutral.on(false), AppColors.textPrimaryLight);
      final src = File(
              'lib/features/settings/presentation/pages/language_settings_page.dart')
          .readAsStringSync();
      expect(src.contains('? AppColors.primary'), isFalse,
          reason: 'tanlangan holat yana xom `primary` ga qaytgan');
      expect(src.contains('AppColors.emerald)'), isFalse,
          reason: 'tasdiq ikonkasi yana xom `emerald` (yorug\'da 2.54:1)');
    });

    test('Kabinet TabBar: tanlangan yorliq qorong\'ida 4.00:1 edi', () {
      expect(_contrast(AppColors.indigo, AppColors.surfaceDark), lessThan(4.5));
      expect(_contrast(AppTone.accentIndigo.on(true), AppColors.surfaceDark),
          greaterThanOrEqualTo(4.5));
      final src = File(
              'lib/features/saved_cases/presentation/pages/documents_and_saved_hub_page.dart')
          .readAsStringSync();
      expect(src.contains('AppColors.indigo'), isFalse,
          reason: 'TabBar yorlig\'i yana xom `indigo` ga qaytgan');
    });

    test('auth brend gradienti: oq yorliq `indigo` ustida 4.47:1 edi', () {
      for (final p in <String>[
        'lib/features/auth/presentation/widgets/auth_gradient_button.dart',
        'lib/features/auth/presentation/pages/auth_gate_page.dart',
        'lib/features/auth/presentation/pages/login_page.dart',
      ]) {
        expect(
            File(p)
                .readAsStringSync()
                .contains('AppColors.primary, AppColors.indigo]'),
            isFalse,
            reason: '$p: gradient yana `indigo` da tugagan');
      }
    });

    test('shimmer spinneri tonga ulangan', () {
      final src =
          File('lib/core/theme/shimmer_loading.dart').readAsStringSync();
      expect(src.contains('AppTone.accentIndigo.on(isDark)'), isTrue);
      expect(
          src.contains('AlwaysStoppedAnimation<Color>(AppColors.indigo)'),
          isFalse,
          reason: 'spinner o\'z tinti ustida 3.01:1 ga qaytgan');
    });
  });
}
