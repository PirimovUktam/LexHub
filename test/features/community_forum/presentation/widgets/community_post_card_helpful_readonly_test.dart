// LEXHUB — SAVOLGA "FOYDALI" OVOZI: SOXTA MUVAFFAQIYAT QAYTMASLIGI QULFI.
//
// O'LCHANGAN NUQSON (§0 dalil: `.runtime_evidence/votes_schema_facts.out.json`,
// 2026-08-30T17:13:23Z): jonli `votes` jadvalida `answer_id` NOT NULL,
// DEFAULT'siz va `FOREIGN KEY (answer_id) REFERENCES answers(id)`. Ya'ni SAVOL
// id si bu jadvalga JISMONAN sig'maydi va `votePost` `23502` bilan yiqilardi;
// jadvalda 0 qator bor edi — ilova orqali birorta savol ovozi HECH QACHON
// yozilmagan.
//
// SHUNGA QARAMAY UI "muvaffaqiyat" ko'rsatardi: `_toggleHelpful()` DARHOL
// `setState` bilan sonni oshirib, thumb-up ni yoqib qo'yardi (server javobini
// KUTMASDAN), BLoC esa xatoni `(_) => null` bilan JIM YUTARDI. Foydalanuvchi
// yozilmagan ovozni ko'rar, sahifa qayta yuklanganda son eski qiymatiga
// qaytardi.
//
// BU TEST NIMANI QULFLAYDI:
//   1. kartochkada "foydali" uchun ALOHIDA bosiladigan element YO'Q (yagona
//      bosish yo'li — butun kartochkani tafsilotga olib boruvchi `InkWell`);
//   2. ko'rsatilgan son AYNAN `post.helpfulCount` (serverdan kelgan qiymat);
//   3. `isLikedByMe` server'dan `true` kelsa ham harakat paydo BO'LMAYDI.
//
// Regressiya (optimistik `setState` yoki `onLikeTap` qaytishi) bu testni QIZIL
// qiladi. Javobga ovoz berish (`voteAnswer`) BU TESTGA TEGISHLI EMAS — u
// haqiqatan ishlaydi va `community_write_session_rls_live_test.dart` 7-testida
// jonli o'lchanadi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/community_post_card.dart';

import '../../../../support/l10n_test_app.dart';

CommunityPost _post({int helpfulCount = 7, bool isLikedByMe = false}) {
  return CommunityPost(
    id: 'q1',
    title: 'Dam olish kunida ishlashga majburlashmoqda',
    anonymizedQuestion: 'Ish beruvchi dam olish kunida ishlashni talab qiladi.',
    category: 'Mehnat huquqi',
    aiSummary: '',
    helpfulCount: helpfulCount,
    answersCount: 2,
    createdAt: DateTime(2026, 8, 30),
    isLikedByMe: isLikedByMe,
  );
}

void main() {
  testWidgets('"foydali" soni BOSILADIGAN element EMAS', (tester) async {
    await tester.pumpWidget(l10nTestApp(
      Scaffold(body: CommunityPostCard(post: _post())),
    ));

    // Serverdan kelgan son KO'RINADI (yorliq bilan, ya'ni ekran o'quvchi
    // uchun ham ma'noli).
    final helpful = find.text('7 ta foydali');
    expect(helpful, findsOneWidget);

    // QULF: sonning YAGONA bosiladigan ajdodi — butun kartochkani tafsilot
    // sahifasiga olib boradigan `ModernContainer.onTap` (`InkWell`). Ilgari
    // shu yerda IKKINCHI `InkWell` bor edi (`onTap: _toggleHelpful`), ya'ni
    // hisob 2 chiqardi. Bu tekshiruv ikonka/matnga qayta biriktirilgan har
    // qanday bosish yo'lini USHLAYDI.
    expect(
      find.ancestor(of: helpful, matching: find.byType(InkWell)),
      findsOneWidget,
      reason: '"foydali" soniga BOSISH yo\'li qaytdi — ovoz jonli sxemada '
          'yozilmaydi, ya\'ni bu yana SOXTA muvaffaqiyat bo\'ladi.',
    );
    // `GestureDetector` ATAYLAB tekshirilmaydi: `InkWell` ning O'ZI ichida
    // `GestureDetector` quradi (o'lchandi — bu tekshiruv shu sababli
    // yiqilgan edi), ya'ni uning soni mustaqil signal EMAS.

    // To'ldirilgan (bosilgan) variant BUTUNLAY yo'q: u faqat soxta
    // "men ovoz berdim" holatini ko'rsatish uchun bor edi.
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_rounded), findsNothing);
  });

  testWidgets('`isLikedByMe` = true bo\'lsa ham bosish yo\'li paydo BO\'LMAYDI',
      (tester) async {
    // Server (yoki eski `votes.target_id` qatori) "men ovoz berdim" deb
    // qaytarsa ham UI'da harakat KO'RSATILMAYDI — chunki ovozni qaytarib
    // olish yo'li ham YO'Q.
    await tester.pumpWidget(l10nTestApp(
      Scaffold(
        body: CommunityPostCard(post: _post(helpfulCount: 3, isLikedByMe: true)),
      ),
    ));

    final helpful = find.text('3 ta foydali');
    expect(helpful, findsOneWidget);
    expect(
      find.ancestor(of: helpful, matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets('son SERVER qiymatidan keladi (mahalliy nusxa emas)',
      (tester) async {
    // Ilgari son `initState` da mahalliy nusxaga ko'chirilardi va
    // `didUpdateWidget` shartlari mos kelmasa EKRANDA ESKI qiymat qolardi.
    // Endi `build` to'g'ridan `post.helpfulCount` ni o'qiydi.
    await tester.pumpWidget(l10nTestApp(
      Scaffold(body: CommunityPostCard(post: _post(helpfulCount: 1))),
    ));
    expect(find.text('1 ta foydali'), findsOneWidget);

    await tester.pumpWidget(l10nTestApp(
      Scaffold(body: CommunityPostCard(post: _post(helpfulCount: 42))),
    ));
    expect(find.text('42 ta foydali'), findsOneWidget);
    expect(find.text('1 ta foydali'), findsNothing);
  });
}
