// LexHub — "AI" DA'VOSI HALOLLIGI (CLAUDE.md §0: CLAIM != EVIDENCE).
//
// MUAMMO (o'lchangan): UI bir nechta joyda javobni "AI tahlili" deb
// atardi, LEKIN matn model tomonidan YARATILMAGAN edi:
//
//   1. `legal_assistant_remote_datasource.dart:156` — proxy javob bermasa
//      (`ai_quota`, `ai_timeout`, `unauthenticated`, `ai_not_configured`)
//      javob `_generateGroundedUzbekLegalResponse` dan keladi va
//      `source: LegalResponse.sourceDeterministic` bilan belgilanadi
//      (o'sha faylning 326-qatori). Ya'ni model chaqirilmagan.
//   2. `community_forum_remote_datasource.dart` — `ai_summary` ustuniga
//      savol YARATILGANDA kategoriya SHABLONI yoziladi ("Ushbu savol
//      $category doirasida ko'rib chiqiladi..."). Hech qanday model
//      ishtirok etmaydi, lekin UI uni "AI tahlil xulosasi" deb ko'rsatardi.
//   3. `home_header_widget.dart` — badge "AI Tahlil" deb turardi, panel
//      `onTap`i esa `SearchPage`ni ochadi (oddiy qidiruv).
//
// BU TEST NIMANI QULFLAYDI: ARB qiymatlarida "AI" da'vosi FAQAT javob
// manbasini ochiq aytadigan ikki kalitda qolishi mumkin. Boshqa har qanday
// kalit "AI" so'zini ishlatsa test YIQILADI — ya'ni chalg'ituvchi yorliq
// qayta kirib kelmaydi.
//
// MUHIM: `@kalit` ichidagi `description` maydonlari SKANERLANMAYDI — ular
// ishlab chiquvchi uchun izoh, UI'ga chiqmaydi va aynan shu muammoni
// tushuntirish uchun "AI" so'zini ishlatishi KERAK.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Qiymatida "AI" da'vosi bo'lishi TO'G'RI bo'lgan kalitlar.
///
/// Bu ikki kalit — `legal_assistant_page.dart:411-424` dagi manba badge'i.
/// Ularning YAGONA vazifasi javob modeldan keldimi yoki qurilmadagi
/// deterministik qonun bazasidan keldimi — shuni AYTIB berish.
const _aiClaimAllowed = <String, String>{
  'legalSourceLlm': 'Manba badge: javob HAQIQATAN model tahlili bo\'lganda.',
  'legalSourceDeterministic':
      'Manba badge: javob AI EMAS ekanini ochiq aytadi.',
};

/// Bir so'zli, katta harfli `AI` — so'z chegaralari bilan.
///
/// Registrga sezgir (case-sensitive) ataylab: o'zbek va ingliz tilida
/// mustaqil `ai` so'zi yo'q, shuning uchun faqat `AI` shakli qidiriladi.
/// So'z chegarasi `AIDS`, `SAIL`, `MAIL` kabi so'zlarni CHIQARIB tashlaydi.
final _aiWord = RegExp(r'\bAI\b');

/// Ko'p harfli model/AI atamalari — registrga sezgir EMAS.
const _aiPhrases = <String>[
  "sun'iy intellekt",
  'sun’iy intellekt', // typografik apostrof varianti
  'artificial intelligence',
  'chatbot',
  'gemini',
  'chatgpt',
  'neyron tarmoq',
];

/// Bu qiymatlar UI'da BOSHQA ko'rinmasligi kerak. `flutter gen-l10n`
/// ishga tushirilmasa generatsiya qilingan fayllarda ular QOLIB KETADI va
/// ARB tuzatilgan bo'lsa ham foydalanuvchi eski, yolg'on matnni ko'radi.
const _retiredUiStrings = <String>[
  'AI Tahlil',
  'AI tahlil xulosasi',
  'LexHub AI tezkor xulosasi',
  'AI maslahat olish',
  'LexHub AI does not replace',
  'AI analysis',
  'AI analysis summary',
  'LexHub AI quick summary',
  'Get AI advice',
];

Map<String, dynamic> _readArb(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path topilmadi.');
  var raw = f.readAsStringSync();
  if (raw.startsWith('﻿')) raw = raw.substring(1);
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Faqat foydalanuvchiga KO'RINADIGAN qiymatlar (`@` metadata emas).
Map<String, String> _uiValues(Map<String, dynamic> arb) {
  final out = <String, String>{};
  arb.forEach((k, v) {
    if (!k.startsWith('@') && v is String) out[k] = v;
  });
  return out;
}

List<String> _aiClaims(Map<String, String> values, String locale) {
  final hits = <String>[];
  values.forEach((k, v) {
    if (_aiClaimAllowed.containsKey(k)) return;
    if (_aiWord.hasMatch(v)) {
      hits.add('$locale: $k = "$v"  (<- "AI" so\'zi)');
      return;
    }
    final lower = v.toLowerCase();
    for (final phrase in _aiPhrases) {
      if (lower.contains(phrase)) {
        hits.add('$locale: $k = "$v"  (<- "$phrase")');
        return;
      }
    }
  });
  hits.sort();
  return hits;
}

void main() {
  late Map<String, String> uz;
  late Map<String, String> en;

  setUpAll(() {
    uz = _uiValues(_readArb('lib/l10n/arb/app_uz.arb'));
    en = _uiValues(_readArb('lib/l10n/arb/app_en.arb'));
  });

  group('§0 — UI "AI" da\'vosi qilmaydi (ruxsat etilgan ikki kalitdan tashqari)',
      () {
    test('app_uz.arb qiymatlarida asossiz "AI" YO\'Q', () {
      final hits = _aiClaims(uz, 'uz');
      expect(
        hits,
        isEmpty,
        reason: 'Bu yorliqlar javobni "AI" deb ko\'rsatadi, lekin javob '
            'deterministik ham bo\'lishi mumkin '
            '(`legal_assistant_remote_datasource.dart:156`). Yorliqni '
            'haqiqiy harakatga moslashtiring yoki manba badge\'idan '
            'foydalaning:\n${hits.join('\n')}',
      );
    });

    test('app_en.arb qiymatlarida asossiz "AI" YO\'Q', () {
      final hits = _aiClaims(en, 'en');
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('`_aiClaimAllowed` eskirmagan — ikki kalit ham bor va MANBANI aytadi',
        () {
      final stale = <String>[];
      _aiClaimAllowed.forEach((k, _) {
        if (!uz.containsKey(k)) {
          stale.add('$k (app_uz.arb da yo\'q)');
        } else if (!_aiWord.hasMatch(uz[k]!)) {
          stale.add('$k (uz qiymatida endi "AI" yo\'q — ro\'yxatdan olib '
              'tashlansin)');
        }
        if (!en.containsKey(k)) {
          stale.add('$k (app_en.arb da yo\'q)');
        } else if (!_aiWord.hasMatch(en[k]!)) {
          stale.add('$k (en qiymatida endi "AI" yo\'q)');
        }
      });
      expect(stale, isEmpty, reason: stale.join('\n'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GEN-L10N FRESHNESS: ARB tuzatilib, `flutter gen-l10n` ishga
  // tushirilmasa foydalanuvchi ESKI matnni ko'radi. Bu testsiz bu nuqson
  // release'gacha sezilmaydi (analyze ham, boshqa testlar ham topmaydi).
  // ══════════════════════════════════════════════════════════════════════
  group('generatsiya qilingan l10n eski "AI" matnini saqlamaydi', () {
    for (final path in <String>[
      'lib/l10n/gen/app_localizations_uz.dart',
      'lib/l10n/gen/app_localizations_en.dart',
    ]) {
      test(path, () {
        final f = File(path);
        expect(f.existsSync(), isTrue,
            reason: '$path topilmadi — `flutter gen-l10n` ishga tushirilsin.');
        final src = f.readAsStringSync();
        final found = _retiredUiStrings.where(src.contains).toList();
        expect(
          found,
          isEmpty,
          reason: 'Bu matnlar ARB\'dan OLIB TASHLANGAN, lekin generatsiya '
              'qilingan faylda qolgan. `flutter gen-l10n` ishga '
              'tushirilsin:\n${found.join('\n')}',
        );
      });
    }
  });
}
