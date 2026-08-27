/// `LegalAnalysisShimmer` — OVERFLOW guard.
///
/// MUAMMO (runtime evidence: `.runtime_evidence/s02.png` — Global Search
/// ekranida "BOTTOM OVERFLOWED BY 267 PIXELS"): `LegalAnalysisShimmer`
/// yalang'och `Column` qaytaradi. Balandligi CHEKLANGAN ota-widget ichida
/// (Scaffold body + klaviatura, `Expanded`, `SafeArea`) u sig'may qoladi.
///
/// Bu test IKKI narsani qulflaydi:
///   1. MEXANIZM — cheklangan balandlikda yalang'och shimmer HAQIQATAN
///      overflow beradi (detektor o'zi ishlashini isbotlaydi);
///   2. TUZATISH — `SingleChildScrollView` qobig'i overflow'ni yo'q qiladi;
///   3. REGRESSIYA — uch chaqiruv joyi yana `Padding`ga qaytmasligi.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';

/// Klaviatura chiqqanda qoladigan taxminiy body balandligi (s02.png holati).
const double _kSqueezedHeight = 260;

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: _kSqueezedHeight,
            child: child,
          ),
        ),
      ),
    );

void main() {
  group('LegalAnalysisShimmer overflow', () {
    testWidgets('MEXANIZM: yalang\'och shimmer cheklangan balandlikda overflow beradi',
        (tester) async {
      await tester.pumpWidget(_host(
        const Padding(
          padding: EdgeInsets.all(16),
          child: LegalAnalysisShimmer(),
        ),
      ));

      final error = tester.takeException();
      expect(
        error,
        isA<FlutterError>(),
        reason: 'Agar bu yiqilsa — shimmer balandligi o\'zgargan yoki '
            'detektor o\'lgan. Guard\'ni tiklamasdan o\'chirma.',
      );
      expect(error.toString(), contains('overflowed'));
    });

    testWidgets('TUZATISH: SingleChildScrollView qobig\'i overflow\'ni yo\'q qiladi',
        (tester) async {
      await tester.pumpWidget(_host(
        const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: LegalAnalysisShimmer(),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(LegalAnalysisShimmer), findsOneWidget);
    });
  });

  test('REGRESSIYA: balandligi cheklangan chaqiruv joylari scroll qobig\'ida', () {
    // Bu uch joyda shimmer'ning ota-widgeti QAT'IY balandlik beradi:
    //   search_page.dart        -> Scaffold body (klaviatura body'ni qisqartiradi)
    //   home_page.dart:~85      -> SafeArea ichida to'g'ridan-to'g'ri
    //   community_forum_page    -> Expanded ichida
    // `home_page.dart` ichidagi IKKINCHI chaqiruv (scroll qiladigan Column
    // ichida) va `legal_assistant_page.dart` chaqiruvi ATAYLAB tekshirilmaydi:
    // ular allaqachon scroll view ichida, ikkinchi scroll qobig'i esa
    // "unbounded height" xatosini keltirib chiqaradi. Ular `Padding` qobig'iga
    // ham o'ralmagan (`const LegalAnalysisShimmer()`), shuning uchun quyidagi
    // shablon ularni YOLG'ON aybdor sifatida tutmaydi.
    const constrained = <String>[
      'lib/features/search/presentation/pages/search_page.dart',
      'lib/features/community_forum/presentation/pages/community_forum_page.dart',
      'lib/features/home/presentation/pages/home_page.dart',
    ];

    final offenders = <String>[];
    final barePadding = RegExp(
      r'Padding\(\s*padding:[^)]*?\)\s*,\s*child:\s*LegalAnalysisShimmer\(\)',
      dotAll: true,
    );

    for (final path in constrained) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path topilmadi');
      final source = file.readAsStringSync();
      expect(
        source.contains('LegalAnalysisShimmer'),
        isTrue,
        reason: '$path da shimmer yo\'q — guard eskirgan',
      );
      if (barePadding.hasMatch(source)) offenders.add(path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Bu fayllarda shimmer yana yalang\'och Padding ichida: '
          '${offenders.join(", ")}',
    );
  });
}
