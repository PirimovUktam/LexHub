import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/master_system_prompt.dart';

/// DRIFT QO'RIQCHISI: master system prompt IKKI joyda yashaydi —
///   1. `lib/core/legal_safety/master_system_prompt.dart` (client, debug yo'li)
///   2. `supabase/functions/legal-ai/master_prompt.ts` (server, release yo'li)
///
/// NIMA UCHUN NUSXA BOR: model chaqiruvi serverga ko'chirildi (kalit APK'ga
/// tushmasligi uchun), lekin debug build'da hali `GeminiLegalService` ham
/// ishlaydi. Ikkala yo'l BIR XIL xavfsizlik qoidalari bilan ishlashi shart:
/// gallyutsinatsiyaga nol tolerantlik, prompt injection himoyasi, favqulodda
/// holat protokoli, advokat o'rnini bosmaslik.
///
/// NIMA UCHUN TEST KERAK: Dart tomonda matn o'zgarsa va `.ts` yangilanmasa,
/// release'dagi AI ESKI qoidalar bilan javob berardi va buni hech kim
/// sezmasdi. Bu test aynan shu jimgina farqni yiqitadi.
void main() {
  group('Legal AI master prompt parity (Dart ↔ Edge Function)', () {
    final tsFile = File('supabase/functions/legal-ai/master_prompt.ts');

    test('`master_prompt.ts` mavjud', () {
      expect(
        tsFile.existsSync(),
        isTrue,
        reason: 'Server-side nusxa yo\'q — proxy master prompt\'siz ishlaydi',
      );
    });

    test('ikkala matn AYNAN bir xil', () {
      final raw = tsFile.readAsStringSync();

      // Template literal ichini ajratamiz: `export const MASTER_SYSTEM_PROMPT = `...`;`
      //
      // DIQQAT: fayl boshidagi izohda ham backtick bor (`MANBA: ...`), shuning
      // uchun ANIQ deklaratsiyadan boshlaymiz — aks holda test izoh matnini
      // prompt deb o'qib, soxta "drift" ko'rsatadi.
      const anchor = 'MASTER_SYSTEM_PROMPT = `';
      final anchorAt = raw.indexOf(anchor);
      expect(
        anchorAt,
        isNonNegative,
        reason: '`export const MASTER_SYSTEM_PROMPT = `...`` deklaratsiyasi topilmadi',
      );
      final start = anchorAt + anchor.length - 1;
      final end = raw.lastIndexOf('`');
      expect(
        end > start,
        isTrue,
        reason: 'Template literal yopilmagan',
      );

      final tsPrompt = _normalize(raw.substring(start + 1, end));
      final dartPrompt = _normalize(MasterSystemPrompt.prompt);

      if (tsPrompt != dartPrompt) {
        // Farqni topib ko'rsatamiz — "teng emas" degan xabar yetarli emas.
        final tsLines = tsPrompt.split('\n');
        final dartLines = dartPrompt.split('\n');
        final limit = tsLines.length < dartLines.length ? tsLines.length : dartLines.length;
        final diffs = <String>[];
        for (var i = 0; i < limit && diffs.length < 5; i++) {
          if (tsLines[i] != dartLines[i]) {
            diffs.add(
              '${i + 1}-qator:\n'
              '  dart: "${dartLines[i]}"\n'
              '  ts  : "${tsLines[i]}"',
            );
          }
        }
        if (dartLines.length != tsLines.length) {
          diffs.add(
            'Qatorlar soni: dart=${dartLines.length}, ts=${tsLines.length}',
          );
        }
        fail('Master prompt DRIFT aniqlandi.\n${diffs.join('\n')}');
      }
    });

    test('server nusxasida kritik xavfsizlik bloklari saqlangan', () {
      final tsPrompt = tsFile.readAsStringSync();
      // Bu marker'lar yo'q bo'lsa — kimdir promptni "qisqartirgan".
      const markers = [
        'GALLYUTSINATSIYALARGA NOL TOLERANTLIK',
        'PROMPT INJECTION HIMOYASI',
        'FAVQULODDA HUQUQIY HOLATLAR PROTOKOLI',
        'ADVOKAT O\'RNINI BOSMASLIK',
        'DUAL-LAYER JAVOB BERISH STRUKTURASI',
      ];
      for (final marker in markers) {
        expect(tsPrompt, contains(marker), reason: '"$marker" bloki yo\'q');
      }
    });
  });
}

/// Faqat MAZMUNGA ta'sir qilmaydigan farqlarni e'tiborsiz qoldiramiz:
///   * CRLF ↔ LF (git `core.autocrlf` ga bog'liq, muallif niyati emas);
///   * qator OXIRIDAGI bo'sh joy (ko'p editor saqlashda o'zi kesib tashlaydi).
/// Qolgan HAR QANDAY farq — haqiqiy drift va test yiqiladi.
String _normalize(String value) => value
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .map((line) => line.replaceFirst(RegExp(r'[ \t]+$'), ''))
    .join('\n')
    .trim();
