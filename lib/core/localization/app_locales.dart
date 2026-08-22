// LexHub — qo'llab-quvvatlanadigan tillar REGISTRI.
//
// Bu fayl til tizimining YAGONA manbasi. Yangi til qo'shish uchun faqat
// ikki qadam kerak (arxitektura shu tarzda ochiq qoldirilgan):
//   1. `lib/l10n/arb/app_<code>.arb` faylini to'liq tarjima bilan yaratish;
//   2. quyidagi [AppLocales.supported] ro'yxatiga `Locale('<code>')` qo'shish.
// Boshqa hech qanday joyda o'zgartirish TALAB QILINMAYDI (ekran-ekran hack yo'q).
//
// MUHIM CHEKLOV: bu yerda faqat UI tillari. Backend qiymatlari
// (`profiles.role` -> citizen/lawyer/verified_expert/admin, kategoriya UUID va
// slug'lari) TARJIMA QILINMAYDI — ular DB kontrakti.

import 'package:flutter/widgets.dart';

class AppLocales {
  AppLocales._();

  /// O'zbek tili — DEFAULT.
  static const Locale uzbek = Locale('uz');

  /// Ingliz tili.
  static const Locale english = Locale('en');

  /// Rus tili — HOZIRCHA FAQAT ARXITEKTURA UCHUN.
  ///
  /// Ataylab [supported] ichida YO'Q: to'liq `app_ru.arb` bo'lmaguncha uni
  /// yoqish foydalanuvchiga yarim o'zbek / yarim rus interfeys ko'rsatadi.
  /// Tarjima tayyor bo'lgan kunda bu qiymat [supported]ga ko'chiriladi.
  static const Locale russian = Locale('ru');

  /// Tarjima topilmasa qaytiladigan til.
  static const Locale fallback = uzbek;

  /// Foydalanuvchi TANLASHI mumkin bo'lgan tillar (Sozlamalar -> Til).
  static const List<Locale> supported = <Locale>[uzbek, english];

  /// Arxitektura tayyor, lekin hali yoqilmagan tillar.
  static const List<Locale> planned = <Locale>[russian];

  /// Til nomi HAR DOIM o'sha tilning o'zida ko'rsatiladi (xalqaro amaliyot):
  /// ingliz interfeysida ham "O'zbekcha" deb turadi, chunki bu tanlovni
  /// tushunmaydigan tilda yozish foydalanuvchini qamab qo'yadi.
  static String nativeName(Locale locale) {
    switch (locale.languageCode) {
      case 'uz':
        return "O'zbekcha";
      case 'en':
        return 'English';
      case 'ru':
        return 'Русский';
      default:
        return locale.languageCode;
    }
  }

  /// Tilning ingliz tilidagi nomi (diagnostika / log uchun).
  static String englishName(Locale locale) {
    switch (locale.languageCode) {
      case 'uz':
        return 'Uzbek';
      case 'en':
        return 'English';
      case 'ru':
        return 'Russian';
      default:
        return locale.languageCode;
    }
  }

  static bool isSupported(Locale locale) =>
      supported.any((l) => l.languageCode == locale.languageCode);

  /// Saqlangan / tizim kodidan `Locale` yasaydi.
  ///
  /// Noma'lum yoki buzilgan qiymat uchun `null` qaytaradi — chaqiruvchi
  /// [fallback]ga o'zi qaror qiladi (jimgina noto'g'ri tilga o'tmaslik uchun).
  static Locale? fromCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    // 'en_US', 'uz-Latn-UZ' kabi qiymatlardan ham til kodini ajratadi.
    final languageCode = normalized.split(RegExp(r'[_-]')).first;
    for (final locale in supported) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
  }
}
