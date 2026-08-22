// LexHub — LOCALIZATION'DAN OLDIN kerak bo'ladigan qisqa matnlar.
//
// Nima uchun alohida: `ErrorWidget.builder` va global error handler'lar
// `main()` boshida, DI va `MaterialApp` hali qurilmagan paytda o'rnatiladi.
// Ular ichida `AppL10n.of(context)` ishlamaydi (localization delegate'lari
// yo'q). Shuning uchun faqat SHU bir nechta matn uchun mustaqil, juda kichik
// lug'at ishlatiladi — ekran-ekran hack emas, aniq chegaralangan bootstrap.
//
// Til manbasi tartibi:
//   1. `LocaleCubit` (foydalanuvchi tanlovi) — DI tayyor bo'lsa;
//   2. `LocaleStore` (diskdagi tanlov) — Cubit hali yo'q bo'lsa;
//   3. tizim tili;
//   4. `AppLocales.fallback` (uz).

import 'dart:ui';

import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/localization/locale_store.dart';

class BootstrapStrings {
  BootstrapStrings._();

  static const Map<String, Map<String, String>> _values = {
    'uz': {
      'fatalTitle': 'Kutilmagan xatolik yuz berdi',
      'fatalHint': "Iltimos, sahifani qayta yuklang yoki keyinroq urinib ko'ring.",
    },
    'en': {
      'fatalTitle': 'An unexpected error occurred',
      'fatalHint': 'Please reload the screen or try again later.',
    },
  };

  static Locale get _locale {
    if (sl.isRegistered<LocaleCubit>()) return sl<LocaleCubit>().state;
    if (sl.isRegistered<LocaleStore>()) return sl<LocaleStore>().read();
    return AppLocales.fromCode(PlatformDispatcher.instance.locale.languageCode) ??
        AppLocales.fallback;
  }

  static String _get(String key) =>
      _values[_locale.languageCode]?[key] ??
      _values[AppLocales.fallback.languageCode]![key]!;

  static String get fatalTitle => _get('fatalTitle');
  static String get fatalHint => _get('fatalHint');
}
