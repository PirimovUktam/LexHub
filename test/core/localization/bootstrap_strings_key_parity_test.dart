// LEXHUB — `BootstrapStrings` KALIT PARITETI (§20 null-xavfsizlik).
//
// NIMA UCHUN BU FAYL BOR: `BootstrapStrings._get()` ichida IKKI null-assertion
// bor (`lib/core/localization/bootstrap_strings.dart:70-71`):
//
//     _values[_locale.languageCode]?[key] ??
//     _values[AppLocales.fallback.languageCode]![key]!;
//
// Bugun bu yiqilmaydi (const map'da `uz` bor va beshta getter faqat `uz` da
// MAVJUD kalitni so'raydi), lekin himoya KODDA emas, ODAM DIQQATIDA turadi:
// keyin qo'shilgan oltinchi matn faqat `en` ga yozilsa, `[key]!` NULL bo'ladi
// va "Null check operator used on a null value" AYNAN `ErrorWidget.builder`
// ichida — ya'ni BOSHQA xatoni ko'rsatish paytida — otiladi. Bu esa asl xatoni
// butunlay yashiradi.
//
// Bu test IKKI QATLAMDA o'lchaydi:
//   A. STATIK — manba matnidan `_values` kalitlari va `_get('...')` chaqiruvlari
//      ajratiladi: `uz` va `en` kalit to'plami AYNAN teng, har bir `_get` kaliti
//      ikkalasida ham bor, ishlatilmagan kalit yo'q.
//   B. XULQ — beshta getter uz/en da bo'sh emas va BIR-BIRIDAN FARQ QILADI
//      (farq qilmasa demak tarjima yo'q va jimgina `uz` ga tushib ketilgan).
//
// `dart:mirrors` Flutter'da yo'q, shuning uchun getterlar ro'yxati qo'lda
// yozilgan — A qismidagi SON tekshiruvi shu ro'yxat eskirsa yiqiladi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/bootstrap_strings.dart';

const _sourcePath = 'lib/core/localization/bootstrap_strings.dart';

/// `'kalit': ...` shaklidagi map yozuvlari (qiymat matni EMAS, faqat kalit).
final _entryKey = RegExp(r"^\s*'([a-zA-Z][a-zA-Z0-9_]*)':\s", multiLine: true);
final _getCall = RegExp(r"_get\('([a-zA-Z][a-zA-Z0-9_]*)'\)");

/// `_values` ichidagi bitta til blokining kalitlarini qaytaradi.
///
/// Blok chegarasi `'<til>': {` dan keyingi mos yopuvchi `}` gacha SANALADI —
/// regexp bilan "boshdan oxirigacha" izlash boshqa tilning kalitlarini ham
/// qamrab olardi.
Set<String> _keysOfLocale(String source, String locale) {
  final start = source.indexOf("'$locale': {");
  expect(start, greaterThan(-1), reason: "`'$locale': {` topilmadi");
  var depth = 0;
  var i = source.indexOf('{', start);
  final open = i;
  for (; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) break;
    }
  }
  final block = source.substring(open, i);
  return _entryKey.allMatches(block).map((m) => m.group(1)!).toSet();
}

void main() {
  late String source;

  setUpAll(() {
    final file = File(_sourcePath);
    expect(file.existsSync(), isTrue,
        reason: '$_sourcePath topilmadi — test paket ildizidan ishga '
            'tushirilishi kerak.');
    source = file.readAsStringSync();
  });

  tearDown(() => BootstrapStrings.debugLocaleOverride = null);

  group('A. STATIK — kalit to\'plamlari', () {
    test('skaner haqiqatan topdi (bo\'sh o\'tish IMKONSIZ)', () {
      expect(_keysOfLocale(source, 'uz').length, greaterThanOrEqualTo(5),
          reason: 'o\'lchangan 2026-08-30: 5 bootstrap matni');
      expect(_getCall.allMatches(source).length, greaterThanOrEqualTo(5));
    });

    test('`uz` va `en` kalit to\'plami AYNAN teng', () {
      final uz = _keysOfLocale(source, 'uz');
      final en = _keysOfLocale(source, 'en');
      expect(en.difference(uz), isEmpty,
          reason: '`en` da bor, `uz` da YO\'Q kalit: `_get()` ichidagi '
              '`_values[fallback]![key]!` NULL bo\'lib ErrorWidget ichida '
              'yiqiladi.');
      expect(uz.difference(en), isEmpty,
          reason: '`uz` da bor, `en` da YO\'Q kalit: ingliz tilida jimgina '
              'o\'zbekcha matn ko\'rsatiladi (§18).');
    });

    test('har bir `_get()` kaliti ikkala tilda ham MAVJUD', () {
      final uz = _keysOfLocale(source, 'uz');
      final en = _keysOfLocale(source, 'en');
      final used = _getCall.allMatches(source).map((m) => m.group(1)!).toSet();
      expect(used.difference(uz), isEmpty, reason: 'uz da yo\'q kalit so\'raldi');
      expect(used.difference(en), isEmpty, reason: 'en da yo\'q kalit so\'raldi');
      expect(uz.difference(used), isEmpty,
          reason: 'Hech qaysi getter so\'ramaydigan kalit — o\'lik matn.');
    });
  });

  group('B. XULQ — beshta getter ikki tilda', () {
    /// (nom, uz ni qaytaruvchi, en ni qaytaruvchi) — A qismi bu ro'yxat
    /// eskirganini SON orqali tutadi.
    final getters = <String, String Function()>{
      'fatalTitle': () => BootstrapStrings.fatalTitle,
      'fatalHint': () => BootstrapStrings.fatalHint,
      'configTitle': () => BootstrapStrings.configTitle,
      'configBody': () => BootstrapStrings.configBody,
      'configKeysHint': () => BootstrapStrings.configKeysHint,
    };

    test('getter ro\'yxati manbadagi kalit soni bilan bir xil', () {
      expect(getters.length, _keysOfLocale(source, 'uz').length,
          reason: 'Yangi bootstrap matni qo\'shildi, bu test esa uni '
              'TEKSHIRMAYDI — ro\'yxatga qo\'shilishi shart.');
    });

    for (final entry in getters.entries) {
      test('${entry.key}: uz va en bo\'sh emas va FARQ QILADI', () {
        BootstrapStrings.debugLocaleOverride = AppLocales.uzbek;
        final uz = entry.value();
        BootstrapStrings.debugLocaleOverride = AppLocales.english;
        final en = entry.value();

        expect(uz.trim(), isNotEmpty, reason: '${entry.key}: uz bo\'sh');
        expect(en.trim(), isNotEmpty, reason: '${entry.key}: en bo\'sh');
        expect(en, isNot(uz),
            reason: '${entry.key}: en va uz AYNAN bir xil — demak `en` '
                'kaliti yo\'q va `_get()` jimgina `uz` ga tushdi.');
      });
    }
  });
}
