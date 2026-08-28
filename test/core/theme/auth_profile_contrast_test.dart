/// AUTH VA PROFIL EKRANLARI KONTRASTI — QULF (Batch 5).
///
/// Bu testlar qurilmada O'LCHANGAN va SKRINSHOTDA tasdiqlangan nuqsonlarni
/// qulflaydi (`41_profile_light.png`, `42_profile_dark.png`, `37_dup_t4.png`):
///
///   1. Profil avatari: bosh harf `primary` (#0F172A) `cardDark` (#1E293B)
///      ustida — piksel o'lchovi 1.22:1, harf KO'RINMASDI.
///   2. "Xavfsizlik & RLS himoyasi" plitkasi: fon `primary@0.1`, ikonka
///      `primary`. Qorong'i mavzuda karta yuzasi ham #0F172A — piksel
///      o'lchovi plitka va fonni AYNAN bir xil qaytardi (1.00:1), ikonka
///      butunlay yo'q edi.
///   3. Rol badge'i (`indigo` tint ustida `indigo` matn): yorug' 3.85:1,
///      qorong'i 2.89:1.
///   4. Reputatsiya badge'i (`amber` tint ustida `amberDark`): yorug' 2.84:1.
///   5. "Tizimdan chiqish" (`crimson` matn+chegara): yorug' 3.60:1.
///   6. Xato SnackBar'i (oq matn `crimson` ustida): 3.76:1 — qurilmada
///      "Ushbu email bilan allaqachon ro'yxatdan o'tilgan." xabari.
///   7. "Ro'yxatdan o'ting" / "Kirish" havolasi (`indigo`): 4.27 / 3.94:1.
///
/// HAMMASI 14 px yoki 12 px w700 — WCAG "large text" (14 pt = 18.66 px bold)
/// EMAS, ya'ni talab 4.5:1. Ikonka va chegara uchun 1.4.11 -> 3:1.
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

String _src(String path) => File(path).readAsStringSync();

/// Faylning FAQAT kod qatorlari — `//` izohlari olib tashlanadi.
///
/// Manba qulflari izohlardagi o'lchov eslatmalariga ILINMASLIGI kerak: nuqson
/// izohida eski rang atay yozilgan ("`Colors.white30` ... 2.65:1"), lekin
/// KODDA u qaytmasligi shart.
String _codeOnly(String path) => _src(path)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  const cardLight = Colors.white;
  const cardDark = AppColors.surfaceDark;
  const avatarRingLight = Color(0xFFE2E8F0);
  const avatarRingDark = AppColors.cardDark;

  group('profil avatari — bosh harf', () {
    test('qorong\'i mavzuda harf halqa ustida >= 4.5:1', () {
      expect(_contrast(AppColors.textPrimaryDark, avatarRingDark),
          greaterThanOrEqualTo(4.5));
    });

    test('yorug\' mavzu o\'zgarmadi', () {
      expect(_contrast(AppColors.primary, avatarRingLight),
          greaterThanOrEqualTo(4.5));
    });

    test('ESKI qiymat haqiqatan yiqilardi (1.22:1)', () {
      expect(_contrast(AppColors.primary, avatarRingDark), closeTo(1.22, 0.05));
    });
  });

  group('RLS plitkasi — neytral ton', () {
    test('ikonka plitka tinti ustida ikki mavzuda >= 4.5:1', () {
      final tintLight =
          Color.alphaBlend(AppTone.neutral.bg(false, alpha: 0.10), cardLight);
      final tintDark =
          Color.alphaBlend(AppTone.neutral.bg(true, alpha: 0.10), cardDark);
      expect(_contrast(AppTone.neutral.on(false), tintLight),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppTone.neutral.on(true), tintDark),
          greaterThanOrEqualTo(4.5));
    });

    test('ESKI naqsh qorong\'ida AYNAN ko\'rinmas edi (1.00:1)', () {
      final oldTint = Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.10), cardDark);
      expect(_contrast(AppColors.primary, oldTint), closeTo(1.0, 0.02));
    });
  });

  group('badge\'lar — rol va reputatsiya', () {
    test('rol badge\'i matni ikki mavzuda >= 4.5:1', () {
      final tintLight =
          Color.alphaBlend(AppTone.accentIndigo.bg(false, alpha: 0.12), cardLight);
      final tintDark =
          Color.alphaBlend(AppTone.accentIndigo.bg(true, alpha: 0.12), cardDark);
      expect(_contrast(AppTone.accentIndigo.on(false), tintLight),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppTone.accentIndigo.on(true), tintDark),
          greaterThanOrEqualTo(4.5));
    });

    test('reputatsiya badge\'i matni ikki mavzuda >= 4.5:1', () {
      final tintLight =
          Color.alphaBlend(AppTone.warning.bg(false, alpha: 0.15), cardLight);
      final tintDark =
          Color.alphaBlend(AppTone.warning.bg(true, alpha: 0.15), cardDark);
      expect(_contrast(AppTone.warning.on(false), tintLight),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppTone.warning.on(true), tintDark),
          greaterThanOrEqualTo(4.5));
    });

    test('ESKI badge qiymatlari yiqilardi', () {
      final indigoTintLight =
          Color.alphaBlend(AppColors.indigo.withValues(alpha: 0.12), cardLight);
      final amberTintLight =
          Color.alphaBlend(AppColors.amber.withValues(alpha: 0.15), cardLight);
      expect(_contrast(AppColors.indigo, indigoTintLight), lessThan(4.5));
      expect(_contrast(AppColors.amberDark, amberTintLight), lessThan(4.5));
    });
  });

  group('xavf rangi — SnackBar va chiqish tugmasi', () {
    test('oq matn xato SnackBar\'i ustida >= 4.5:1', () {
      expect(_contrast(Colors.white, AppColors.emergencyStrong),
          greaterThanOrEqualTo(4.5));
    });

    test('ESKI SnackBar foni yiqilardi (3.76:1)', () {
      expect(_contrast(Colors.white, AppColors.crimson), lessThan(4.5));
    });

    test('"Tizimdan chiqish" ikki mavzuda >= 4.5:1', () {
      expect(_contrast(AppColors.emergencyStrong, AppColors.backgroundLight),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.emergencyDark, AppColors.backgroundDark),
          greaterThanOrEqualTo(4.5));
    });

    test('ESKI chiqish rangi yorug\'da yiqilardi (3.60:1)', () {
      expect(_contrast(AppColors.crimson, AppColors.backgroundLight),
          lessThan(4.5));
    });
  });

  group('auth havolalari', () {
    test('havola matni ikki mavzuda >= 4.5:1', () {
      expect(_contrast(AppColors.indigoDark, AppColors.backgroundLight),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.indigoOnTintDark, AppColors.backgroundDark),
          greaterThanOrEqualTo(4.5));
    });

    test('ESKI havola rangi ikki mavzuda ham yiqilardi', () {
      expect(_contrast(AppColors.indigo, AppColors.backgroundLight),
          lessThan(4.5));
      expect(
          _contrast(AppColors.indigo, AppColors.backgroundDark), lessThan(4.5));
    });
  });

  group('auth maydoni — hint (placeholder) matni', () {
    const fillDark = AppColors.cardDark;
    const fillLight = Color(0xFFF8FAFC);

    test('hint ikki mavzuda >= 4.5:1 (placeholder ham MATN)', () {
      expect(_contrast(AppColors.textSecondaryDark, fillDark),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.textSecondaryLight, fillLight),
          greaterThanOrEqualTo(4.5));
    });

    test('hint kiritilgan matndan XIRAROQ qoladi — ierarxiya buzilmadi', () {
      expect(_contrast(AppColors.textSecondaryDark, fillDark),
          lessThan(_contrast(AppColors.textPrimaryDark, fillDark)));
      expect(_contrast(AppColors.textSecondaryLight, fillLight),
          lessThan(_contrast(AppColors.textPrimaryLight, fillLight)));
    });

    test('ESKI qiymatlar yiqilardi (2.65:1 / 1.88:1)', () {
      expect(_contrast(Color.alphaBlend(Colors.white30, fillDark), fillDark),
          closeTo(2.65, 0.05));
      expect(_contrast(Color.alphaBlend(Colors.black26, fillLight), fillLight),
          closeTo(1.88, 0.05));
    });

    test('fokus chegarasi grafik sifatida 3:1 dan o\'tadi — o\'zgartirilmadi',
        () {
      // 1.4.11: fokus konturi MATN emas, talab 3:1. `indigo` maydon foni
      // ustida 3.27:1, karta yuzasi ustida 4.00:1 — ikkisi ham o'tadi.
      expect(_contrast(AppColors.indigo, fillDark), greaterThanOrEqualTo(3.0));
      expect(_contrast(AppColors.indigo, AppColors.surfaceDark),
          greaterThanOrEqualTo(3.0));
    });

    test('manba qulfi — alfa asosidagi hint qaytmaydi', () {
      // Izohlarda eski qiymatlar O'LCHOV sifatida atay eslatilgan, shuning
      // uchun qulf faqat HAQIQIY kodni tekshiradi.
      final code = _codeOnly(
          'lib/features/auth/presentation/widgets/auth_text_field.dart');
      expect(code.contains('Colors.white30'), isFalse);
      expect(code.contains('Colors.black26'), isFalse);
      expect(code.contains('AppColors.textSecondaryDark'), isTrue);
    });
  });

  group('manba qulfi — qaytish bloklanadi', () {
    test('profil sahifasi xom aksentni matn/ikonka qilmaydi', () {
      final src = _codeOnly(
          'lib/features/auth/presentation/pages/profile_tab_page.dart');
      expect(src.contains('color: AppColors.indigo)'), isFalse);
      expect(src.contains('color: AppColors.amberDark'), isFalse);
      expect(src.contains('color: AppColors.crimson'), isFalse);
      expect(src.contains('AppColors.primary.withValues(alpha: 0.1)'), isFalse);
      expect(src.contains('AppTone.neutral'), isTrue);
      expect(src.contains('AppTone.accentIndigo'), isTrue);
      expect(src.contains('AppTone.warning'), isTrue);
    });

    test('auth sahifalari SnackBar foni sifatida `crimson` ishlatmaydi', () {
      for (final p in const [
        'lib/features/auth/presentation/pages/register_page.dart',
        'lib/features/auth/presentation/pages/login_page.dart',
      ]) {
        final src = _codeOnly(p);
        expect(src.contains('backgroundColor: AppColors.crimson'), isFalse,
            reason: p);
        expect(src.contains('backgroundColor: AppColors.emergencyStrong'), isTrue,
            reason: p);
        expect(src.contains('color: AppColors.indigo,'), isFalse, reason: p);
      }
    });
  });
}
