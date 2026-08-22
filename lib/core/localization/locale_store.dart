// LexHub — tanlangan tilni QURILMADA saqlash.
//
// Talab: til tanlovi ilova qayta ishga tushganda ham saqlanib qolishi kerak.
// `shared_preferences` ATAYLAB ishlatilmadi: u `pubspec.yaml`da faqat
// `dev_dependencies` ichida (test uchun), ya'ni release build'da mavjud emas.
// Hive esa haqiqiy `dependencies` va DI'da allaqachon ishga tushirilgan
// (`Hive.initFlutter()`), shuning uchun mavjud persistent layer ishlatiladi.

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:lexhub/core/localization/app_locales.dart';

/// Til tanlovi uchun persistent store.
///
/// Hech qanday `catch (_)` YO'Q: yozish xatosi chaqiruvchiga qaytadi, chunki
/// "til o'zgardi" deb ko'rsatib, aslida saqlamaslik = yolg'on success.
class LocaleStore {
  const LocaleStore(this._box);

  /// Umumiy sozlamalar box'i (til, keyinchalik boshqa UI sozlamalari).
  /// Legal-cases box'idan ALOHIDA: turli mas'uliyat, turli hayot davri.
  static const String boxName = 'lexhub_settings';
  static const String localeKey = 'app_locale';

  final Box<String> _box;

  /// Saqlangan til. Yo'q yoki noma'lum bo'lsa — [AppLocales.fallback] (uz).
  Locale read() =>
      AppLocales.fromCode(_box.get(localeKey)) ?? AppLocales.fallback;

  /// Til kodini saqlaydi (`uz`, `en`). Faqat qo'llab-quvvatlanadigan til.
  Future<void> write(Locale locale) {
    assert(
      AppLocales.isSupported(locale),
      'Qo\'llab-quvvatlanmaydigan til saqlanmoqda: ${locale.languageCode}',
    );
    return _box.put(localeKey, locale.languageCode);
  }
}
