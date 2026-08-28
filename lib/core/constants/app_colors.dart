import 'package:flutter/material.dart';

/// App-wide Design Tokens and Color Palette tailored for a trustworthy, Clean-Tech legal app
class AppColors {
  AppColors._();

  // Primary Trust - Deep Navy
  static const Color primary = Color(0xFF0F172A); // Slate 900
  static const Color primaryDark = Color(0xFF0A192F); // Deepest Navy
  static const Color primaryLight = Color(0xFF1E293B); // Slate 800
  static const Color primaryContainer = Color(0xFF334155);

  // Royal Indigo - User Summary & Highlights
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoLight = Color(0xFFEEF2FF);
  static const Color indigoDark = Color(0xFF4F46E5);

  // Emerald Green - Verified Legal Grounding & Low Risk
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFFD1FAE5);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color riskLow = Color(0xFF10B981);
  static const Color riskLowBg = Color(0xFFD1FAE5);

  // Amber Warning - Medium Risk & Cautions
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color amberDark = Color(0xFFD97706);
  static const Color riskMedium = Color(0xFFF59E0B);
  static const Color riskMediumBg = Color(0xFFFEF3C7);

  // Crimson Red - Emergency Red Flags & High Risk
  static const Color crimson = Color(0xFFEF4444);
  static const Color crimsonLight = Color(0xFFFEE2E2);
  static const Color crimsonDark = Color(0xFFDC2626);
  static const Color crimsonDarkBg = Color(0xFF2D1518);
  static const Color emergency = Color(0xFFEF4444);

  /// FAVQULODDA FONI — oq matn/ikonka QO'YILADIGAN yuza uchun YAGONA to'g'ri
  /// token.
  ///
  /// NIMA UCHUN ALOHIDA: `emergency` (#EF4444, Red 500) oq matn ostida
  /// 3.76:1 kontrast beradi — grafik obyekt uchun yetarli (3:1), ammo MATN
  /// uchun WCAG AA (4.5:1) dan PAST. Nuqson uchta joyda o'lchandi: bosh
  /// sahifadagi SOS banneri gradienti, xato SnackBar foni va favqulodda
  /// bannerdagi "qo'ng'iroq qilish" tugmasi — ya'ni odam hibsga olinganda
  /// o'qiydigan eng muhim boshqaruv elementi.
  ///
  /// #B91C1C (Red 700) oq matn ostida 6.47:1 beradi va baribir "shoshilinch
  /// qizil" bo'lib qoladi. `emergency` esa ikonka/chegara/xato tinti uchun
  /// qoldirildi (28 joyda ishlatiladi, ularning hammasi grafik).
  /// Qulf: `test/core/theme/color_contrast_test.dart`.
  static const Color emergencyStrong = Color(0xFFB91C1C);
  static const Color emergencyLight = Color(0xFFFEE2E2);

  /// AKSENT TINTI USTIDA O'QILADIGAN MATN/IKONKA RANGLARI.
  ///
  /// NIMA UCHUN BULAR KERAK: bir qancha kartochka fonini `aksent@8..16%`
  /// qilib bo'yaydi va MATNNI ham SHU aksentning to'liq to'yingan variantida
  /// yozadi. O'lchov (real emulyator pikselidan, `Tezkor Huquqlar` ekrani):
  /// `102` #EF4444 tint ustida 3.01:1, `1096` #0284C7 → 3.28:1,
  /// `1092` #10B981 → 2.10:1 — WCAG AA (15 px BOLD matn "katta" hisoblanmaydi,
  /// talab 4.5:1) qo'pol buzilgan. Qorong'ida ham: `1002` 3.59:1, `102`
  /// 4.35:1, `1096` 3.87:1. Ya'ni hibsda odam o'qishi kerak bo'lgan ISHONCH
  /// RAQAMI eng past kontrastli matn edi.
  ///
  /// Yechim: fon tinti va chegara AKSENTDA qoladi (rang kodlash saqlanadi),
  /// matn va ikonka esa shu aksentning kontrastli variantiga o'tadi. Qiymatlar
  /// tint alfasi 0..0.20 oralig'ida ham AA'dan o'tadigan qilib tanlandi
  /// (o'lchangan haqiqiy alfa ~0.12), shuning uchun dizayner tintni
  /// quyuqlashtirsa ham buzilmaydi.
  /// Qulf: `test/core/theme/color_contrast_test.dart`.
  static const Color emeraldStrong = Color(0xFF065F46); // yorug': min 6.12:1
  static const Color lexBlueStrong = Color(0xFF075985); // yorug': min 5.63:1
  static const Color indigoOnDark = Color(0xFF818CF8); // qorong'i: min 4.72:1
  static const Color lexBlueOnDark = Color(0xFF38BDF8); // qorong'i: min 6.47:1
  static const Color emeraldOnDark = Color(0xFF34D399); // qorong'i: min 6.53:1

  static const Color emergencyDark = Color(0xFFF87171); // Light crimson for dark mode
  static const Color emergencyBorder = Color(0xFFFCA5A5);
  static const Color riskHigh = Color(0xFFEF4444);
  static const Color riskHighBg = Color(0xFFFEE2E2);
  static const Color riskCritical = Color(0xFF9333EA); // Purple critical
  static const Color riskCriticalBg = Color(0xFFF3E8FF);
  static const Color riskCriticalDark = Color(0xFFC084FC); // Light purple for dark mode

  // Lex.uz Credibility Blue
  static const Color lexBlue = Color(0xFF0284C7);
  static const Color lexBlueLight = Color(0xFFE0F2FE);
  static const Color lexBlueDark = Color(0xFF0369A1);

  // Regal Gold / Accent
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDark = Color(0xFFD97706);

  // Neutral Light
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  // O'LCHANGAN TUZATISH — ilgari bu Slate 400 (#94A3B8) edi va WCAG AA'ni
  // BUZARDI: oq (#FFFFFF) ustida 2.56:1, `backgroundLight` (#F8FAFC) ustida
  // 2.45:1 — talab esa oddiy matn uchun 4.5:1. Mavzudagi `bodySmall` va
  // `hintStyle` SHU tokenni oladi, ya'ni nuqson 65+ joyda bir vaqtda
  // ko'rinardi (emulyatorda tasdiqlangan).
  //
  // Slate 500 (#64748B): oq ustida 4.76:1, `backgroundLight` ustida 4.55:1 —
  // ikkalasi ham AA'dan o'tadi va uch pog'onali ierarxiya SAQLANADI
  // (primary #0F172A > secondary #475569 4.76 < 7.58 > muted #64748B).
  //
  // Bu token qorong'i mavzuda ham FILTRSIZ ishlatilgan ~8 joy bor (hammasi
  // IKONKA). #64748B `surfaceDark` ustida 3.75:1 beradi — grafik obyekt/UI
  // komponenti uchun talab 3:1, ya'ni ular ham o'tadi.
  // Qulf: `test/core/theme/color_contrast_test.dart`.
  static const Color textMutedLight = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Neutral Dark
  static const Color backgroundDark = Color(0xFF0A192F);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1); // Slate 300 - High Contrast
  static const Color textMutedDark = Color(0xFF94A3B8); // Slate 400 - Clear Readable
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);

  // Dark Alert & Badge Backgrounds
  static const Color emergencyDarkBg = Color(0xFF2D1518);
  static const Color emergencyDarkBorder = Color(0xFF5C2329);
  static const Color emeraldDarkBg = Color(0xFF0D281E);
  static const Color emeraldDarkBorder = Color(0xFF165B40);
  static const Color amberDarkBg = Color(0xFF2C2009);
  static const Color amberDarkBorder = Color(0xFF6B4D0E);
  static const Color lexBlueDarkBg = Color(0xFF0C243C);
  static const Color lexBlueDarkBorder = Color(0xFF134E7B);
  static const Color indigoDarkBg = Color(0xFF1E1B4B);
  static const Color indigoDarkBorder = Color(0xFF3730A3);
}
