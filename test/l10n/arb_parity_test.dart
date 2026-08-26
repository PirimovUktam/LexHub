// LexHub — ARB PARITETI: ingliz tili TO'LIQ ikkinchi UI tili (P2 audit).
//
// Talab: "English tanlanganda BARCHA navigation, buttons, labels, dialogs,
// SnackBar, errors, empty states, settings, profile, community, AI, auth
// matnlari ingliz tilida bo'lishi kerak."
//
// Buni ta'minlashning MEXANIK sharti: `app_en.arb` da `app_uz.arb` dagi
// HAR BIR kalit bo'lishi kerak. Kalit tushib qolsa `flutter gen-l10n`
// uni o'zbekcha shablon qiymati bilan to'ldiradi — ya'ni ingliz UI'da
// o'zbekcha matn ko'rinadi va buni hech kim sezmaydi.
//
// Shu sababli bu test IKKI TOMONLAMA pariteti va TARJIMA QILINMAGAN
// (aynan bir xil) qiymatlar ro'yxatini QULFLAYDI.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `uz` va `en` da AYNAN bir xil bo'lishi TO'G'RI bo'lgan kalitlar.
///
/// Har biri — atoqli nom, xalqaro qisqartma yoki namuna ismi; tarjima
/// qilinsa MA'NO buziladi yoki shovqin bo'ladi.
const _identicalAllowed = <String, String>{
  'appName': 'Brend nomi.',
  'roleAdmin': 'Ikki tilda ham "Admin".',
  'roleModerator': 'Ikki tilda ham "Moderator".',
  'expertTelegram': 'Platforma nomi (Telegram).',
  'hotlineOmbudsman': 'Lavozim nomi xalqaro (Ombudsman).',
  'searchLexUzBadge': 'Rasmiy manba nomi (lex.uz) + belgi.',
  'faqBannerBadge': 'Raqamli badge (TOP 20+).',
  'authHintFullName': 'Namuna ISM — tarjima qilinmaydi.',
};

Map<String, dynamic> _readArb(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path topilmadi.');
  // BOM bo'lsa `jsonDecode` yiqiladi — tozalanadi.
  var raw = f.readAsStringSync();
  if (raw.startsWith('﻿')) raw = raw.substring(1);
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  late Map<String, dynamic> uz;
  late Map<String, dynamic> en;
  late Set<String> uzKeys;
  late Set<String> enKeys;

  setUpAll(() {
    uz = _readArb('lib/l10n/arb/app_uz.arb');
    en = _readArb('lib/l10n/arb/app_en.arb');
    uzKeys = uz.keys.where((k) => !k.startsWith('@')).toSet();
    enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
  });

  group('§16 — ARB pariteti (uz <-> en)', () {
    test('en da tushib qolgan kalit YO\'Q', () {
      final missing = (uzKeys.difference(enKeys)).toList()..sort();
      expect(missing, isEmpty,
          reason: 'Bu kalitlar `app_en.arb` da yo\'q — ingliz UI\'da '
              'o\'zbekcha matn ko\'rinadi:\n${missing.join('\n')}');
    });

    test('uz da bo\'lmagan ortiqcha en kaliti YO\'Q', () {
      final extra = (enKeys.difference(uzKeys)).toList()..sort();
      expect(extra, isEmpty,
          reason: 'Bu kalitlar shablon (`app_uz.arb`) da yo\'q — o\'lik '
              'tarjima:\n${extra.join('\n')}');
    });

    test('tarjima qilinmagan (aynan bir xil) qiymatlar ro\'yxati QULFLANGAN',
        () {
      final identical = <String>[];
      for (final k in uzKeys.intersection(enKeys)) {
        if (uz[k] == en[k] && !_identicalAllowed.containsKey(k)) {
          identical.add('$k = "${uz[k]}"');
        }
      }
      identical.sort();
      expect(identical, isEmpty,
          reason: 'Bu kalitlar ingliz tiliga TARJIMA QILINMAGAN. Tarjima '
              'qiling yoki ataylab bir xil bo\'lsa `_identicalAllowed`ga '
              'SABABI bilan qo\'shing:\n${identical.join('\n')}');
    });

    test('`_identicalAllowed` eskirmagan', () {
      final stale = <String>[];
      _identicalAllowed.forEach((k, _) {
        if (!uzKeys.contains(k)) {
          stale.add('$k (ARB\'da yo\'q)');
        } else if (uz[k] != en[k]) {
          stale.add('$k (endi tarjima qilingan)');
        }
      });
      expect(stale, isEmpty,
          reason: 'Ro\'yxatdan olib tashlansin:\n${stale.join('\n')}');
    });

    test('ikki ARB ham bo\'sh qiymat saqlamaydi', () {
      final empty = <String>[];
      for (final k in uzKeys) {
        if ((uz[k] as String).trim().isEmpty) empty.add('uz: $k');
      }
      for (final k in enKeys) {
        if ((en[k] as String).trim().isEmpty) empty.add('en: $k');
      }
      expect(empty, isEmpty, reason: empty.join('\n'));
    });
  });
}
