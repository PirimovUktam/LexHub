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

Widget l10nTestApp(
  Widget home, {
  Locale locale = const Locale('uz'),
  NavigatorObserver? navigatorObserver,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    navigatorObservers: [
      if (navigatorObserver != null) navigatorObserver,
    ],
    home: home,
  );
}
