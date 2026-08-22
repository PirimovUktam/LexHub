// LexHub — TIL TANLOVI QAYTA ISHGA TUSHGANDA SAQLANADI (P2 English UI audit).
//
// Talab: "Saqlangan til app restart'dan keyin ham saqlanishi kerak."
//
// Bu test ISHONCHNI KODNI O'QIB emas, HAQIQIY Hive box'iga YOZIB va
// box'ni YOPIB, QAYTA OCHIB oladi — ya'ni "restart" simulyatsiyasi
// diskdagi ma'lumot orqali qilinadi (vaqtinchalik katalogda, production
// ma'lumotiga tegmaydi).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/locale_store.dart';

void main() {
  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('lexhub_locale_test');
    Hive.init(tmp.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  tearDown(() async {
    if (Hive.isBoxOpen(LocaleStore.boxName)) {
      await Hive.box<String>(LocaleStore.boxName).clear();
      await Hive.box<String>(LocaleStore.boxName).close();
    }
  });

  Future<LocaleStore> openStore() async =>
      LocaleStore(await Hive.openBox<String>(LocaleStore.boxName));

  group('LocaleStore — til tanlovi persistensiyasi', () {
    test('saqlanmagan holatda fallback = uz', () async {
      final store = await openStore();
      expect(store.read().languageCode, 'uz');
      expect(AppLocales.fallback.languageCode, 'uz');
    });

    test('en saqlanadi va BOX YOPILIB QAYTA OCHILGANDA ham en qoladi',
        () async {
      final store = await openStore();
      await store.write(const Locale('en'));
      // "App restart": box yopiladi, keyin qaytadan ochiladi.
      await Hive.box<String>(LocaleStore.boxName).close();

      final reopened = await openStore();
      expect(reopened.read().languageCode, 'en',
          reason: 'Til tanlovi restart\'dan keyin saqlanmadi.');
    });

    test('uz ga qaytarish ham saqlanadi', () async {
      final store = await openStore();
      await store.write(const Locale('en'));
      await store.write(const Locale('uz'));
      await Hive.box<String>(LocaleStore.boxName).close();

      final reopened = await openStore();
      expect(reopened.read().languageCode, 'uz');
    });

    test('noma\'lum kod saqlangan bo\'lsa fallback (uz) qaytadi', () async {
      final box = await Hive.openBox<String>(LocaleStore.boxName);
      await box.put(LocaleStore.localeKey, 'ru');
      expect(LocaleStore(box).read().languageCode, 'uz',
          reason: 'ru UI\'da qo\'llab-quvvatlanmaydi — fallback bo\'lishi kerak.');
    });
  });
}
