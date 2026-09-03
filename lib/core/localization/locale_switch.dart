// LexHub — TIL ALMASHTIRISH amali (YAGONA nusxa).
//
// NIMA UCHUN BU FAYL BOR: bu amal ilgari FAQAT
// `language_settings_page.dart` ichida, private `_select` sifatida yashagan.
// Endi til ikki joydan almashtiriladi (Sozlamalar ekrani va bosh sahifadagi
// tezkor tanlagich), ya'ni nusxa ko'chirilsa ikki NOZIK xatti-harakat
// takrorlanishi kerak bo'lardi:
//
//   1. XATO YO'LI — `LocaleCubit.select()` avval SAQLAYDI, keyin `emit`
//      qiladi. Saqlash yiqilsa til O'ZGARMAYDI, shuning uchun foydalanuvchiga
//      REAL xato ko'rsatiladi. Bu yerda `catch (_)` bor, lekin u JIM EMAS:
//      xato darhol SnackBar bo'lib chiqadi va funksiya `return` qiladi
//      (yolg'on "muvaffaqiyatli" YO'Q).
//   2. TIMING — muvaffaqiyat xabari `lookupAppL10n(locale)` bilan
//      YASALADI, `context.l10n` bilan EMAS (sabab pastda, o'lchangan defekt).
//
// Nusxa ko'chirish o'rniga bir joyda saqlanadi: ikkinchi chaqiruv joyi shu
// ikki xususiyatni AVTOMATIK oladi.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';

/// Ilova tilini [locale] ga almashtiradi va natijani foydalanuvchiga aytadi.
///
/// Til allaqachon [locale] bo'lsa — hech narsa qilmaydi (SnackBar ham yo'q).
Future<void> switchAppLocale(BuildContext context, Locale locale) async {
  final messenger = ScaffoldMessenger.of(context);
  final cubit = context.read<LocaleCubit>();
  if (locale.languageCode == cubit.state.languageCode) return;
  try {
    await cubit.select(locale);
  } catch (_) {
    // Saqlash yiqilsa til O'ZGARMAYDI (LocaleCubit avval yozadi, keyin
    // emit qiladi) — shuning uchun foydalanuvchiga REAL xato ko'rsatiladi,
    // yolg'on "muvaffaqiyatli" xabari EMAS.
    //
    // `context.l10n` bu YERDA to'g'ri: til o'zgarmagani uchun xabar HAM
    // eski (hozirgi) tilda bo'lishi kerak.
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.languageSaveFailed),
        // O'LCHANGAN: `snackBarTheme` matnni OQ qilib qulflaydi — `crimson`
        // ustida 3.76:1 (AA'dan past). `emergencyStrong`: 6.47:1.
        backgroundColor: AppColors.emergencyStrong,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  if (!context.mounted) return;
  // P2 (real qurilmada aniqlangan): ilgari bu yerda `context.l10n`
  // ishlatilgan va SnackBar YANGI til o'rniga ESKI tilda chiqqan —
  // English tanlangandan keyin ham "Til o'zgartirildi: English" deb
  // ko'rsatilgan. Sabab: `Localizations` delegate'i ASINXRON yuklanadi,
  // shuning uchun `cubit.select()` dan keyingi ayni microtask'da
  // `AppL10n.of(context)` hali ESKI (uz) obyektni qaytaradi; `Text(...)`
  // esa satrni darhol hisoblab, eski matnni "muzlatib" qo'yadi.
  //
  // Yechim: tanlangan locale uchun tarjimani TO'G'RIDAN-TO'G'RI olamiz
  // (`lookupAppL10n` — generatsiya qilingan sinxron funksiya), ya'ni
  // kadr/timing'ga tayanmaymiz.
  final selectedL10n = lookupAppL10n(locale);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        selectedL10n.languageChangedTo(AppLocales.nativeName(locale)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
