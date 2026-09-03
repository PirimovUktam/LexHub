// LexHub — widget testlar uchun `LocaleCubit` (Hive'ga TEGMAYDI).
//
// NIMA UCHUN BOR: ilovada `LocaleCubit` `MaterialApp` USTIDA beriladi
// (`main.dart:174`), ya'ni til tanlagichi bo'lgan HAR QANDAY sahifani pump
// qiladigan test shu provider'ni ham berishi kerak. Haqiqiy `LocaleStore`
// esa Hive box talab qiladi — navigatsiya testiga disk I/O qo'shish
// ortiqcha va sekin.
//
// Bu dublyor XOTIRADA saqlaydi, lekin JIM EMAS: [failWrite] `true` bo'lsa
// `write` HAQIQIY exception tashlaydi, ya'ni "saqlash yiqildi" yo'lini
// (`switchAppLocale` dagi SnackBar) test o'lchashi mumkin.

import 'package:flutter/widgets.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/localization/locale_store.dart';

class FakeLocaleStore implements LocaleStore {
  FakeLocaleStore({Locale? initial, this.failWrite = false})
      : _locale = initial ?? AppLocales.fallback;

  Locale _locale;

  /// `true` bo'lsa [write] tashlaydi — "saqlab bo'lmadi" yo'lini o'lchash uchun.
  final bool failWrite;

  @override
  Locale read() => _locale;

  @override
  Future<void> write(Locale locale) async {
    if (failWrite) throw StateError('test: saqlash ataylab yiqitildi');
    _locale = locale;
  }
}

/// Test uchun `LocaleCubit` — xotiradagi store ustida.
LocaleCubit testLocaleCubit({Locale? initial, bool failWrite = false}) =>
    LocaleCubit(
      store: FakeLocaleStore(initial: initial, failWrite: failWrite),
    );
