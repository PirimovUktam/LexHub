// LexHub — SERVER MODEL ZANJIRI QULFI (Dart tomondan).
//
// NIMA UCHUN BU FAYL BOR: `model_chain_test.ts` (Deno) haqiqiy runtime
// testi, LEKIN u AVTOMATIK ISHLAMAYDI — repoda CI yo'q (`.github/workflows`
// mavjud emas, 2026-09-04 da tekshirildi) va `deno test` ni faqat qo'lda
// ishga tushiriladi. Doimiy ishlatiladigan yagona darvoza — `flutter test`.
// Shuning uchun shart SHU YERDA ham qulflanadi: kimdir `429` ni zanjirdan
// olib tashlasa, `flutter test` QIZIL bo'ladi.
//
// BU TEST NIMA EMAS: bu RUNTIME isbot EMAS (CLAUDE.md §0) — u faqat manba
// matnini o'qiydi. Runtime isbot ikki joyda:
//   1. `deno test supabase/functions/legal-ai/model_chain_test.ts` -> 9/9;
//   2. production probe: `tool/probe_legal_ai_latency.py`.
//
// O'LCHANGAN MUAMMO (2026-09-04, production, `LEGAL_AI_DEBUG_UPSTREAM=1`):
// `upstream_status = 429`, `upstream_model = gemini-3.6-flash`,
// "You exceeded your current quota". `callGemini` zanjirni faqat
// 503/404/504 da surardi, ya'ni kvotasi BOR zaxira model SINALMASDI va
// foydalanuvchi `ai_quota` -> "AI EMAS" deterministik javob olardi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _chain = 'supabase/functions/legal-ai/model_chain.ts';
const _index = 'supabase/functions/legal-ai/index.ts';
const _denoTest = 'supabase/functions/legal-ai/model_chain_test.ts';

String _read(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path topilmadi.');
  return f.readAsStringSync();
}

/// Faqat KOD satrlari — `///` va `//` izohlari tashlanadi.
///
/// MUHIM: izohlar aynan shu muammoni tushuntirish uchun `429`, `503` kabi
/// raqamlarni ishlatadi. Ularni skanerlash testni SOXTA yashil qilardi —
/// izoh o'chirilmasa kod buzilgan bo'lsa ham o'tib ketardi.
String _codeOnly(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('server zaxira model zanjiri — 429 (kvota) da HAM o\'tadi', () {
    test('`model_chain.ts` da 429 KOD ichida bor', () {
      final code = _codeOnly(_read(_chain));
      expect(
        code.contains('status === 429'),
        isTrue,
        reason: 'Gemini bepul kvotasi HAR MODEL uchun ALOHIDA (o\'lchangan '
            '2026-09-04). 429 zanjirdan olib tashlansa, asosiy model kvotasi '
            'tugagach foydalanuvchi zaxira modelda kvota BOR bo\'lsa ham '
            '"AI EMAS" javob oladi.',
      );
      for (final status in const ['503', '404', '504']) {
        expect(code.contains('status === $status'), isTrue,
            reason: '$status zanjirdan tushib qolgan — ilgari o\'lchangan '
                'nosozliklar (Google spike, model nomi, timeout) qaytadi.');
      }
    });

    test('`index.ts` qarorni SHU MODULDAN oladi (nusxa shart YO\'Q)', () {
      final code = _codeOnly(_read(_index));
      expect(code.contains("from './model_chain.ts'"), isTrue,
          reason: 'Import yo\'q — modul chetlab o\'tilgan.');
      expect(code.contains('shouldTryNextModel(last.status)'), isTrue,
          reason: 'Zanjir qarori `callGemini` ichida qayta yozilgan bo\'lsa, '
              'Deno testi qulflagan mantiq AMALDA ishlatilmaydi.');
      // ANTI-VAKUUM: eski inline shart QAYTIB kelmasin.
      expect(
        code.contains('last.status !== 503 && last.status !== 404'),
        isFalse,
        reason: 'Eski inline shart qaytgan — `model_chain.ts` bilan ikkilanish '
            'paydo bo\'ladi va biri ikkinchisidan ajralib ketadi.',
      );
    });

    test('Deno testi mavjud va 429 holatini TEKSHIRADI', () {
      final code = _read(_denoTest);
      expect(code.contains('shouldTryNextModel(429), true'), isTrue,
          reason: 'Runtime testidan 429 keysi olib tashlangan — bu qulf '
              'MANBASIZ qoladi.');
    });
  });
}
