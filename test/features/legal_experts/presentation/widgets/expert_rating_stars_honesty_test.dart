// LexHub — `ExpertRatingStars` HALOLLIK QULFI (§6: to'qima qiymat YO'Q).
//
// O'LCHANGAN XAVF (2026-08-30, `tool/probe_expert_guard.py` ning birinchi
// ijrosi ochib berdi): bazada `expert_profiles.rating` ustuni
// `DEFAULT 5.00 NOT NULL` (`20260819_base_schema.sql:101`), `reviews_count`
// esa `0`. Ya'ni HAR BIR yangi advokat profili bazada "5.00 ball, 0 baho"
// holatida tug'iladi. Loyihada bahoni HISOBLAYDIGAN mexanizm hali YO'Q,
// demak jonli qatorlarning HAMMASI 5.00 da turadi.
//
// Bu qiymat foydalanuvchiga KO'RINMAYDI, chunki widget `reviewsCount <= 0`
// bo'lganda umuman chizilmaydi. LEKIN bu kafolat FAQAT shu shartda yashaydi
// — u olib tashlansa, ilovada bir kechada "5.0 ★ (0 baho)" degan SOXTA
// ijtimoiy isbot paydo bo'ladi va buni hech kim sezmaydi (bazada xato yo'q,
// testlar yashil). Shu test o'sha shartni QULFLAYDI.
//
// Model qatlami allaqachon qulflangan
// (`legal_expert_model_test.dart` — bo'sh `rating` -> `0.0`); bu yerda
// PRESENTATION qatlami qulflanadi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/expert_rating_stars.dart';

import '../../../../support/l10n_test_app.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double rating,
    required int reviewsCount,
  }) async {
    await tester.pumpWidget(
      l10nTestApp(
        Scaffold(
          body: ExpertRatingStars(
            rating: rating,
            reviewsCount: reviewsCount,
          ),
        ),
      ),
    );
  }

  group('1. BAHO YO\'Q — hech narsa ko\'rsatilmaydi', () {
    testWidgets('bazadagi DEFAULT holat (5.00 / 0) EKRANGA CHIQMAYDI',
        (tester) async {
      await pump(tester, rating: 5.0, reviewsCount: 0);

      expect(find.byType(Icon), findsNothing,
          reason: 'yulduz chizilsa "0 baho" bilan 5 yulduz ko\'rinardi');
      expect(find.textContaining('5.0'), findsNothing,
          reason: 'raqamli baho ham chiqmasligi kerak');
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('manfiy `reviewsCount` ham chizmaydi', (tester) async {
      await pump(tester, rating: 4.9, reviewsCount: -3);
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('2. BAHO BOR — halol ko\'rsatiladi', () {
    testWidgets('5 ta yulduz + raqam + baho soni', (tester) async {
      await pump(tester, rating: 4.5, reviewsCount: 12);

      // Har doim AYNAN 5 ta yulduz (to'la/yarim/bo'sh) chiziladi.
      expect(find.byType(Icon), findsNWidgets(5));
      expect(find.text('4.5'), findsOneWidget);
      // `Icon` ning O'ZI ham ichida `ExcludeSemantics` yaratadi (o'lchangan:
      // widget ostida 6 ta — 1 ta bizning, 5 ta yulduzlarning), shuning
      // uchun sanash emas, AJDOD zanjiri tekshiriladi: yulduzlar bizning
      // `ExcludeSemantics` ichida turishi SHART.
      expect(
          find.ancestor(
            of: find.byType(Icon).first,
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason: 'yulduzlar ekran o\'quvchisida takrorlanmasligi kerak');
    });

    testWidgets('5 dan katta qiymat BANDGA tushadi (5.0)', (tester) async {
      await pump(tester, rating: 7.3, reviewsCount: 4);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(5));
    });
  });
}
