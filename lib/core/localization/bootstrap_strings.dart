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

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/localization/locale_store.dart';

class BootstrapStrings {
  BootstrapStrings._();

  /// FAQAT TEST uchun: til zanjirini majburan belgilaydi.
  ///
  /// Bootstrap matnlari `PlatformDispatcher.instance.locale`ga tayanadi, uni
  /// esa `flutter_test` almashtira olmaydi — `tester.platformDispatcher`
  /// (`TestPlatformDispatcher`) ALOHIDA obyekt, `PlatformDispatcher.instance`
  /// esa haqiqiy singleton. Shu seam bo'lmasa faqat test hostining tili
  /// (`en`) tekshirilardi va `uz` shoxi hech qachon ishga tushmasdi.
  /// Production kod bu qiymatni HECH QACHON o'rnatmaydi.
  @visibleForTesting
  static Locale? debugLocaleOverride;

  static const Map<String, Map<String, String>> _values = {
    'uz': {
      'fatalTitle': 'Kutilmagan xatolik yuz berdi',
      'fatalHint': "Iltimos, sahifani qayta yuklang yoki keyinroq urinib ko'ring.",
      'configTitle': 'Ilova sozlanmagan',
      'configBody': "Bu build ichida backend konfiguratsiyasi yo'q, shuning "
          "uchun ro'yxatdan o'tish, kirish va boshqa server funksiyalari "
          "ishlamaydi. Ilova ataylab to'xtatildi — noto'g'ri manzilga so'rov "
          "yubormaslik uchun.",
      'configKeysHint': "Kerakli kalitlar ro'yxati: env/dev.json.example",
    },
    'en': {
      'fatalTitle': 'An unexpected error occurred',
      'fatalHint': 'Please reload the screen or try again later.',
      'configTitle': 'The app is not configured',
      'configBody': 'This build carries no backend configuration, so sign-up, '
          'sign-in and every other server function will not work. The app '
          'stopped on purpose — so that it cannot send requests to the wrong '
          'address.',
      'configKeysHint': 'Required keys are listed in env/dev.json.example',
    },
  };

  static Locale get _locale {
    final override = debugLocaleOverride;
    if (override != null) return override;
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

  /// `ConfigurationErrorApp` uchun — `SupabaseConfig.validate()` yiqilganda
  /// ko'rsatiladi. Bu ekran DI'dan ham, `Supabase.initialize`dan ham OLDIN
  /// chiziladi, ya'ni `sl` hali bo'sh: `_locale` avtomatik tizim tiliga,
  /// undan keyin `uz`ga tushadi. Shu sababli bu matnlar ARB'da emas, SHU
  /// yerda turadi — ARB delegate'i o'sha paytda mavjud emas.
  static String get configTitle => _get('configTitle');
  static String get configBody => _get('configBody');
  static String get configKeysHint => _get('configKeysHint');
}
