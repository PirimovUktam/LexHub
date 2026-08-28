/// CHUQURLIK (depth) tokenlari — soya va hoshiya retseptlari.
///
/// NIMA UCHUN BU FAYL BOR: kartochkalar "yassi oq quti" bo'lib ko'rinardi,
/// chunki M3 `elevation` LexHub'da ishlatilmaydi (`elevation: 0` hamma
/// joyda) va har bir ekran o'z `BoxShadow` ini qo'lda yozardi — natijada
/// soyalar bir-biriga o'xshamasdi.
///
/// O'LCHANGAN CHEKLOV: qorong'i mavzuda soya deyarli KO'RINMAYDI (fon
/// #0A192F, soya qora — kontrast yo'q). Shuning uchun qorong'ida chuqurlik
/// SOYA bilan emas, HOSHIYA yorqinligi va ichki gradient bilan beriladi.
/// Yorug' mavzuda esa teskari: hoshiya nozik, soya ish bajaradi.
library;

import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';

/// Soya to'plamlari. Hammasi `elevation: 0` ustiga qo'lda quriladi.
class AppShadows {
  AppShadows._();

  /// Karta uchun standart soya (faqat YORUG' mavzu).
  ///
  /// Ikki qatlam: keng va juda xira (ambient) + qisqa va aniqroq (kontakt).
  /// Bir qatlamli soya "stikker" effekti beradi.
  static List<BoxShadow> card(bool isDark) {
    if (isDark) return const <BoxShadow>[];
    return <BoxShadow>[
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Aksent rangidagi "ambient glow" — hero karta, ko'tarilgan tugma.
  ///
  /// DIQQAT: alfa 0.10..0.38 oralig'ida qoldiriladi. Undan yuqori qiymat
  /// soyani MAZMUN ko'rinishiga olib keladi va matn ostiga tushib
  /// kontrastni buzadi.
  static List<BoxShadow> glow(Color accent, {double alpha = 0.28}) {
    return <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: alpha),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

/// Hairline hoshiya ranglari.
class AppBorders {
  AppBorders._();

  /// Karta konturi.
  ///
  /// NIMA UCHUN qorong'ida OQ, yorug'da `borderLight`: oq fon ustiga
  /// `Colors.white.withValues(...)` hoshiya qo'yish KO'RINMAYDI — bu
  /// "glassmorphism" retseptlarida eng ko'p qilinadigan xato. Yorug'
  /// mavzuda kontur to'q tomondan beriladi.
  static Color hairline(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : AppColors.borderLight;

  /// Aksentli kontur — holat kartochkalari uchun.
  static Color accent(Color accent) => accent.withValues(alpha: 0.25);
}

/// Qorong'i mavzuda chuqurlik beruvchi ichki gradient.
///
/// Soya qorong'ida ishlamagani uchun yuqori qirradan pastga qarab juda
/// nozik oq yorug'lik beriladi — yuza "yuqoridan yoritilgan" bo'lib
/// ko'rinadi. Yorug' mavzuda `null` qaytadi (kerak emas).
LinearGradient? innerSheen(bool isDark) {
  if (!isDark) return null;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.white.withValues(alpha: 0.05),
      Colors.white.withValues(alpha: 0.0),
    ],
  );
}

