import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/presentation/pages/question_detail_page.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../../../support/l10n_test_app.dart';

/// P0 UI/RBAC GUARD — "Advokat sifatida javob berish" chip'i
///
/// MUHIM CHEKLOV (CLAIM != EVIDENCE): bu widget test. U ekspert huquqi REAL
/// `profiles.role` dan olinishini ISBOTLAMAYDI (Supabase bu yerda
/// initialize qilinmagan). U ANIQ bitta invariantni qo'riqlaydi:
///
///   Ekspert huquqi TASDIQLANMAGUNCHA chip RENDER QILINMAYDI (fail-closed).
///
/// P0 EDI: chip shartsiz render bo'lardi va `role = 'citizen'` foydalanuvchi
/// ham o'zini "Litsenziyaga ega advokat" deb belgilab javob yuborardi.
/// Real device + real Supabase tasdig'i:
///   `test/integration/verify_community_answer_live_test.dart` (gated).
void main() {
  late AppL10n l10n;

  setUpAll(() async {
    // Assertion'lar l10n KALITLARI bo'yicha yoziladi — shunda tarjima
    // matni o'zgarsa test yolg'on qizil bermaydi, lekin kalit yo'qolsa
    // (yoki chip qaytib kelsa) darhol yiqiladi.
    l10n = await AppL10n.delegate.load(const Locale('uz'));
  });

  CommunityPost buildPost({List<QuestionAnswer> answers = const []}) {
    return CommunityPost(
      id: 'q-1',
      title: 'Ishdan bo\'shatish tartibi qanday?',
      anonymizedQuestion: 'Meni ogohlantirmasdan ishdan bo\'shatdilar.',
      category: 'Mehnat huquqi',
      aiSummary: 'Mehnat shartnomasini bekor qilish tartibi.',
      authorName: 'Fuqaro',
      createdAt: DateTime(2026, 8, 22, 6, 14, 59),
      answers: answers,
    );
  }

  Future<void> pumpPage(WidgetTester tester, CommunityPost post) async {
    await tester.pumpWidget(l10nTestApp(QuestionDetailPage(post: post)));
    // `_loadExpertEligibility()` async — Supabase initialize qilinmagani
    // uchun u xato bilan tugaydi va huquq `false` bo'lib QOLADI (fail-closed).
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('huquq tasdiqlanmagan holatda ekspert chip\'i KO\'RINMAYDI',
      (tester) async {
    await pumpPage(tester, buildPost());

    // NON-VACUITY: chip'ning AYNAN o'sha Row'idagi qo'shnisi render bo'lgan,
    // ya'ni `findsNothing` "bu joy umuman qurilmagan" degani EMAS.
    expect(find.text(l10n.communityPiiNotice), findsOneWidget,
        reason: 'chip joylashgan Row render bo\'lganini tasdiqlaydi');

    expect(find.text(l10n.answerAsLawyerChip), findsNothing,
        reason: 'P0: chip shartsiz render bo\'lsa, citizen ham o\'zini '
            'advokat deb belgilab javob yuboradi');
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('javob yozish maydoni HAMMAGA ochiq qoladi', (tester) async {
    await pumpPage(tester, buildPost());

    // Ekspert chip'i yashirilishi oddiy javob yozishni TO'SMASLIGI kerak —
    // aks holda fix bir bug'ni ikkinchisiga aylantirgan bo'lardi.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('mavjud javob matni sahifada ko\'rinadi', (tester) async {
    // READ regressiyasi (`content` vs `body`) UI darajasida.
    await pumpPage(
      tester,
      buildPost(answers: [
        QuestionAnswer(
          id: 'a-1',
          authorName: 'Oʻktam',
          content: 'Mehnat kodeksining 173-moddasiga qarang.',
          createdAt: DateTime(2026, 8, 22, 7),
        ),
      ]),
    );

    expect(find.text('Mehnat kodeksining 173-moddasiga qarang.'), findsOneWidget,
        reason: 'javob matni bo\'sh ko\'rinsa, foydalanuvchi javobni '
            'yo\'qolgan deb hisoblaydi');
  });
}
