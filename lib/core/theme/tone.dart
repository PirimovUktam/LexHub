/// SEMANTIK RANG JUFTLIKLARI (tone) — "tintli fon + to'yingan matn" retsepti.
///
/// NIMA UCHUN BU FAYL BOR: loyihada eng ko'p takrorlangan vizual naqsh —
/// `aksent@8..20%` fon + `aksent` chegara + AKSENTNING O'ZI matn rangi. Bu
/// naqsh chiroyli, lekin oxirgi qismi WCAG AA'ni BUZADI: o'lchov `Tezkor
/// Huquqlar` ekranida 2.10:1 gacha tushgan (talab 4.5:1).
///
/// Shuning uchun bu yerda har bir semantik holat uchun UCHTA rang qulflanadi:
/// fon/chegara uchun AKSENT, matn/ikonka uchun esa shu aksentning YORUG' va
/// QORONG'I mavzudagi kontrastli jufti. Rang kodlash (qizil = xavf, yashil =
/// tasdiq) saqlanadi, o'qilishi esa isbotlanadi.
///
/// O'LCHOV USULI: matn rangi aksent tintining USTIDA, alfa 0.00→0.20 bo'ylab
/// ENG YOMON nuqtada o'lchandi (yorug'da oq VA `backgroundLight`, qorong'ida
/// `cardDark` VA `backgroundDark` — to'rt yuzaning hammasi). Alfa monoton
/// ta'sir qilgani uchun band chetlari o'tsa, orasidagi hamma qiymat o'tadi.
/// Haqiqiy alfa 0.08..0.18 oralig'ida, ya'ni zaxira mavjud — dizayner tintni
/// quyuqlashtirsa ham buzilmaydi.
///
/// Qulf: `test/core/theme/color_contrast_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';

@immutable
class AppTone {
  const AppTone({
    required this.accentLight,
    required this.accentDark,
    required this.onTintLight,
    required this.onTintDark,
  });

  /// Fon tinti va chegara uchun aksent — YORUG' mavzu.
  final Color accentLight;

  /// Fon tinti va chegara uchun aksent — QORONG'I mavzu.
  final Color accentDark;

  /// Shu tint USTIDA o'qiladigan matn/ikonka — yorug' mavzu.
  final Color onTintLight;

  /// Shu tint USTIDA o'qiladigan matn/ikonka — qorong'i mavzu.
  final Color onTintDark;

  /// XAVF / FAVQULODDA. Yorug': min 4.78:1, qorong'i: min 6.38:1.
  static const AppTone danger = AppTone(
    accentLight: AppColors.crimson,
    accentDark: AppColors.crimson,
    onTintLight: AppColors.emergencyStrong,
    onTintDark: AppColors.crimsonOnTintDark,
  );

  /// TASDIQLANGAN / MUVAFFAQIYAT. Yorug': min 6.12:1, qorong'i: min 5.41:1.
  static const AppTone success = AppTone(
    accentLight: AppColors.emerald,
    accentDark: AppColors.emerald,
    onTintLight: AppColors.emeraldStrong,
    onTintDark: AppColors.emeraldOnDark,
  );

  /// OGOHLANTIRISH / MUDDAT. Yorug': min 5.86:1, qorong'i: min 7.07:1.
  static const AppTone warning = AppTone(
    accentLight: AppColors.amber,
    accentDark: AppColors.amber,
    onTintLight: AppColors.amberOnTint,
    onTintDark: AppColors.amberOnTintDark,
  );

  /// MANBA / HAVOLA (lex.uz ishonchi). Yorug': min 5.61:1, qorong'i: 5.44:1.
  static const AppTone info = AppTone(
    accentLight: AppColors.lexBlue,
    accentDark: AppColors.lexBlue,
    onTintLight: AppColors.lexBlueStrong,
    onTintDark: AppColors.lexBlueOnDark,
  );

  /// ASOSIY AKSENT (electric blue). Yorug': min 4.86:1, qorong'i: 6.23:1.
  static const AppTone brand = AppTone(
    accentLight: AppColors.electricBlue,
    accentDark: AppColors.electricBlueOnDark,
    onTintLight: AppColors.blueOnTint,
    onTintDark: AppColors.blueOnTintDark,
  );

  /// FOYDALANUVCHI XULOSASI (indigo). Yorug': min 4.67:1, qorong'i: 5.91:1.
  static const AppTone accentIndigo = AppTone(
    accentLight: AppColors.indigo,
    accentDark: AppColors.indigo,
    onTintLight: AppColors.indigoDark,
    onTintDark: AppColors.indigoOnTintDark,
  );

  /// KRITIK DARAJA (purple). Yorug': min 6.18:1, qorong'i: 7.16:1.
  static const AppTone critical = AppTone(
    accentLight: AppColors.riskCritical,
    accentDark: AppColors.riskCritical,
    onTintLight: AppColors.purpleOnTint,
    onTintDark: AppColors.purpleOnTintDark,
  );

  /// NEYTRAL — rang kodlashsiz yorliq. Yorug': min 11.18:1, qorong'i: 9.83:1.
  static const AppTone neutral = AppTone(
    accentLight: AppColors.primary,
    accentDark: AppColors.textMutedDark,
    onTintLight: AppColors.textPrimaryLight,
    onTintDark: AppColors.textPrimaryDark,
  );

  /// XOM AKSENT -> TON. Data qatlamidan kelgan `Color` ni xavfsiz tonga
  /// ko'chiradi.
  ///
  /// NIMA UCHUN BOR: `document_templates_datasource.dart` har bir shablonga
  /// `Color` biriktiradi (`emerald`, `primary`, `indigo`, `amber`, `lexBlue`)
  /// va UI shu XOM rangni MATN hamda IKONKA rangi qilib ishlatardi. Bu
  /// mavzuga qaramaydi, natijada:
  ///
  ///   Badge yorlig'i (10 px w700) — matn = xom rang:
  ///     `primary`   qorong'ida `surfaceDark` ustida  1.00:1  (KO'RINMASDI —
  ///                 qurilmada tasdiqlangan: `19_konstruktor_dark.png`)
  ///     `amber`     yorug'da `backgroundLight` ustida 2.05:1
  ///     `emerald`   yorug'da                         2.42:1
  ///     `amberDark` yorug'da                         3.04:1
  ///     `lexBlue`   yorug'da 3.91:1 / qorong'ida     4.36:1
  ///     `indigo`    qorong'ida 4.00:1 / yorug'da     4.27:1
  ///   Ya'ni OLTI xom rangdan BIRORTASI ham ikki mavzuda AA (4.5:1) bermaydi.
  ///
  ///   Ikonka tili (grafik, 1.4.11 -> 3:1) — ikonka = xom rang, fon = xom
  ///   rang@0.12:
  ///     `primary` qorong'ida 1.19:1, `amber` yorug'da 1.96:1,
  ///     `emerald` yorug'da 2.27:1, `amberDark` yorug'da 2.81:1,
  ///     `indigo` qorong'ida 2.89:1 — hammasi 3:1 dan PAST.
  ///
  /// Data/Domain qatlami O'ZGARMAYDI — rang FAQAT render paytida ko'chiriladi.
  /// Ko'chirishdan keyin eng yomon qiymat 5.56:1 (qulf:
  /// `test/core/theme/raw_accent_tone_test.dart`).
  ///
  /// Noma'lum rang [neutral] ga tushadi: rang kodlashni yo'qotadi, lekin
  /// HECH QACHON ko'rinmas bo'lib qolmaydi.
  static AppTone forRawAccent(Color raw) {
    if (raw == AppColors.emerald || raw == AppColors.emeraldDark) {
      return success;
    }
    if (raw == AppColors.amber || raw == AppColors.amberDark) return warning;
    if (raw == AppColors.indigo || raw == AppColors.indigoDark) {
      return accentIndigo;
    }
    // `lexBlueDark` va `crimsonDark` QO'SHILDI: `quick_access_grid.dart`
    // plitkalari aynan shu ikki xom rangni ishlatadi. Ular ilgari `neutral` ga
    // tushardi, ya'ni "Saqlangan" ko'k va "Favqulodda" qizil ikonkasi
    // qora/oq bo'lib qolib RANG KODLASHNI yo'qotardi (ikonka o'qilardi, lekin
    // shoshilinch signal ketardi).
    if (raw == AppColors.lexBlue || raw == AppColors.lexBlueDark) return info;
    if (raw == AppColors.crimson ||
        raw == AppColors.emergency ||
        raw == AppColors.crimsonDark ||
        raw == AppColors.emergencyStrong) {
      return danger;
    }
    if (raw == AppColors.riskCritical) return critical;
    if (raw == AppColors.electricBlue) return brand;
    return neutral;
  }

  Color accent(bool isDark) => isDark ? accentDark : accentLight;

  Color on(bool isDark) => isDark ? onTintDark : onTintLight;

  /// Fon tinti. Standart alfa qorong'ida yuqori — to'q fonda 8% tint
  /// KO'RINMAYDI (o'lchov: `#EF4444@0.08` `#0A192F` ustida deyarli farqsiz).
  Color bg(bool isDark, {double? alpha}) =>
      accent(isDark).withValues(alpha: alpha ?? (isDark ? 0.16 : 0.10));

  /// Hairline chegara — tintni "quti" qiladi, soyaga tayanmaydi.
  Color border(bool isDark) => accent(isDark).withValues(alpha: 0.25);
}
