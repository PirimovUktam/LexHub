import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/theme/app_theme.dart';

/// CHIP YORLIG'I QIRQILISHI — QULF.
///
/// Qurilmada (emulator-5554, release APK) o'lchangan nuqson: `FilterChip`
/// yorlig'ining OXIRGI harfi so'nib yo'qolardi — "Barchasi" → "Barchas",
/// "Mehnat huquqi" → "Mehnat huquq".
///
/// Sabab freymvorkda: `RawChip` yorliqni (a) `DefaultTextStyle(overflow:
/// TextOverflow.fade, maxLines: 1, softWrap: false)` ichiga o'raydi va
/// (b) BIRINCHI o'lchovda olingan kenglikka TENG `maxWidth` bilan QAYTA
/// layout qiladi. Ya'ni yorliq har doim aynan o'z kengligida siqiladi —
/// ikki o'lchov orasidagi 0.x px farq darhol oxirgi glifni so'ndiradi.
///
/// Shuning uchun QAT'IY katalogdan keladigan chip yorliqlarida
/// `overflow: TextOverflow.visible` MAJBURIY. Foydalanuvchi kiritgan
/// matndan (masalan `search_page.dart` dagi oxirgi qidiruvlar) tuzilgan
/// yorliqlar bundan MUSTASNO — u yerda fade ATAYLAB saqlanadi.
void main() {
  group('RawChip yorliq layout tuzog\'i', () {
    testWidgets('yorliq aynan o\'z kengligida siqiladi va fade majburlanadi',
        (tester) async {
      const label = 'Mehnat huquqi';
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  selected: false,
                  label: const Text(label, style: TextStyle(fontSize: 12)),
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final paragraph =
          tester.renderObject<RenderParagraph>(find.text(label));
      // Freymvork xatti-harakati: fade + bir qatorga majburlash.
      expect(paragraph.overflow, TextOverflow.fade);
      expect(paragraph.softWrap, isFalse);
      // Va yorliqqa berilgan `maxWidth` aynan o'lchangan kenglik:
      // zaxira NOL, ya'ni har qanday 0.x px farq glifni yo'qotadi.
      expect(paragraph.constraints.maxWidth, closeTo(paragraph.size.width, 0.01));
    });

    testWidgets('overflow: visible berilganda fade O\'CHADI', (tester) async {
      const label = 'Mehnat huquqi';
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  selected: false,
                  label: const Text(label,
                      overflow: TextOverflow.visible,
                      style: TextStyle(fontSize: 12)),
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final paragraph =
          tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.overflow, TextOverflow.visible);
    });
  });

  group('Qat\'iy katalogli chip yorliqlari fade\'siz bo\'lishi SHART', () {
    // Fayl → shu fayldagi qulflangan `TextOverflow.visible` soni.
    const expected = <String, int>{
      'lib/features/community_forum/presentation/pages/community_forum_page.dart': 1,
      'lib/features/community_forum/presentation/pages/question_detail_page.dart': 1,
      'lib/features/citizen_services/presentation/pages/citizen_services_page.dart': 1,
      'lib/features/document_builder/presentation/pages/document_templates_page.dart': 1,
      'lib/features/home/presentation/pages/faq_questions_page.dart': 2,
      'lib/features/legal_assistant/presentation/pages/legal_assistant_page.dart': 1,
      'lib/features/legal_experts/presentation/pages/legal_experts_page.dart': 1,
      'lib/features/search/presentation/pages/search_page.dart': 1,
    };

    for (final entry in expected.entries) {
      test(entry.key, () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: 'fayl yo\'q: ${entry.key}');
        final matches = RegExp(r'overflow:\s*TextOverflow\.visible')
            .allMatches(file.readAsStringSync())
            .length;
        expect(matches, entry.value,
            reason: 'chip yorlig\'idagi fade qulfi buzilgan: ${entry.key}');
      });
    }
  });
}
