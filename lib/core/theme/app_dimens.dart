/// LEXHUB DIZAYN TOKENLARI — masofa, radius va ikonka o'lchamlari.
///
/// NIMA UCHUN BU FAYL BOR: rang tokenlari (`AppColors`) allaqachon markazda
/// edi, lekin MASOFA va RADIUS har bir ekranda qo'lda yozilardi
/// (`EdgeInsets.all(18)`, `Gap(22)`, `BorderRadius.circular(16)`, ...).
/// O'lchov: `grep -c "Gap(\|circular(" lib/features` ~400 dan ortiq joy —
/// ya'ni "kartalar orasidagi masofani 4 px kamaytiraylik" degan o'zgarish
/// 400 joyni qo'lda tahrirlashni talab qilardi va natijada ekranlar
/// bir-biridan chetlab ketardi (16 / 18 / 22 aralash).
///
/// QOIDA: yangi UI kodida raqam YOZILMAYDI — shu tokenlardan olinadi.
/// Mavjud ekranlar ATAYLAB birdaniga ko'chirilmaydi: har bir tegilgan ekran
/// o'z navbatida ko'chiriladi (katta "hamma joyni almashtirish" refaktori
/// §20 SCOPE FREEZE ga ziddir va regressiya xavfi yuqori).
library;

/// Vertikal/gorizontal masofa shkalasi (4 ga karrali).
class AppSpacing {
  AppSpacing._();

  /// 4 — ikonka bilan matn orasidagi eng zich masofa.
  static const double xxs = 4;

  /// 6 — badge ichidagi masofa.
  static const double xs = 6;

  /// 8 — bir guruh ichidagi elementlar.
  static const double sm = 8;

  /// 12 — karta ichidagi bloklar orasi.
  static const double md = 12;

  /// 16 — ekran chetidan bo'shliq (standart `padding`).
  static const double lg = 16;

  /// 20 — karta ichidagi katta `padding`.
  static const double xl = 20;

  /// 24 — bo'limlar orasidagi masofa.
  static const double xxl = 24;

  /// 32 — ekranning eng ostidagi zaxira (bottom nav ustida).
  static const double bottomSafe = 32;
}

/// Burchak radiuslari.
///
/// `AppTheme` da qulflangan qiymatlar bilan bir xil: karta 18, tugma va
/// input 16 (`app_theme.dart`). Bu yerda ular NOM oladi.
class AppRadius {
  AppRadius._();

  /// 6 — kichik badge/chip.
  static const double xs = 6;

  /// 10 — ikonka konteyner.
  static const double sm = 10;

  /// 12 — o'rta blok.
  static const double md = 12;

  /// 16 — tugma va input (`AppTheme` bilan bir xil).
  static const double lg = 16;

  /// 18 — karta (`ModernContainer` standarti).
  static const double card = 18;

  /// 22 — hero/banner kabi katta yuza.
  static const double xl = 22;

  /// 999 — to'liq yumaloq (pill) qidiruv maydoni va chip.
  static const double pill = 999;
}

/// Ikonka o'lchamlari.
class AppIconSize {
  AppIconSize._();

  /// 14 — matn yonidagi izoh ikonkasi.
  static const double xs = 14;

  /// 18 — sarlavha yonidagi strelka.
  static const double sm = 18;

  /// 22 — tezkor kirish plitkasi.
  static const double md = 22;

  /// 26 — pastki navigatsiyaning ko'tarilgan tugmasi.
  static const double lg = 26;

  /// 48 — bo'sh holat / xato ekranidagi katta ikonka.
  static const double empty = 48;
}
