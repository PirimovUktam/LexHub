// LexHub — widget testlar uchun l10n bilan jihozlangan `MaterialApp`.
//
// `context.l10n` (`AppL10n.of(context)`) `Localizations` scope talab qiladi.
// Delegatlar ulanmagan `MaterialApp(home: ...)` bilan pump qilingan har qanday
// sahifa "Null check operator used on a null value" bilan yiqiladi — bu
// haqiqiy ilova xatosi EMAS, test setup'idagi kamchilik (ilovada delegatlar
// `main.dart` da ulangan). Shu sababli barcha widget testlar shu helperdan
// foydalanadi.
//
// `locale` parametri §16 lokalizatsiya regress testlari uchun ochiq qoldirildi:
// bir xil sahifani `uz` (default) va `en` da pump qilib solishtirish mumkin.

import 'package:flutter/material.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// `theme` — layout qulflari uchun. Berilmasa `MaterialApp` ning O'Z sukut
/// mavzusi ishlatiladi (ilgarigi xatti-harakat, o'zgarmadi). HAQIQIY
/// `AppTheme.lightTheme` ni faqat mavzuning O'ZI layoutga ta'sir qilgan joyda
/// bering: masalan `outlinedButtonTheme`/`elevatedButtonTheme` tugmaga
/// `minimumSize: Size.fromHeight(50)` = `minWidth: INFINITY` beradi
/// (`app_theme.dart:179`), ya'ni mavzusiz pump qilingan test bu sinf
/// xatolarini UMUMAN ko'rmaydi
/// (`test/widget/themed_button_unbounded_width_test.dart`).
Widget l10nTestApp(
  Widget home, {
  Locale locale = const Locale('uz'),
  NavigatorObserver? navigatorObserver,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    navigatorObservers: [
      if (navigatorObserver != null) navigatorObserver,
    ],
    home: home,
  );
}
