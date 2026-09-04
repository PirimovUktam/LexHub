/// BOSH SAHIFA "Jamoa" SKELETI — OVERFLOW QULFI.
///
/// JONLI DALIL (2026-09-04, debug web build, Playwright, `flt-semantics`
/// to'rtburchaklari + brauzer konsoli): yuklanish holati BARCHA telefon
/// kengliklarida o'ngga chiqib ketardi —
///   A RenderFlex overflowed by 216 pixels on the right.   (360 px ekran)
///   A RenderFlex overflowed by 186 pixels on the right.   (390 px)
///   A RenderFlex overflowed by 146 pixels on the right.   (430 px)
///
/// SABAB: YUKLANGAN holat gorizontal `ListView.separated` (`home_page.dart`
/// ~396), SKELET esa oddiy `Row` edi. Ikki karta 260 px + 12 px oraliq =
/// 544 px, sahifada esa 360 - 2*16 = 328 px bor.
///
/// Bu o'lcham QAT'IY PIKSELLARDAN keladi (`width: 260`), MATNDAN emas —
/// shuning uchun sinov shrifti bu qulfga TA'SIR QILMAYDI va 216 px raqami
/// aynan takrorlanadi (§0).
///
/// `_CommunityLoadingRow` PRIVATE, ya'ni import qilinmaydi: MEXANIZM va
/// TUZATISH geometriyaning NUSXASIDA tekshiriladi, haqiqiy kod bilan aloqa
/// esa REGRESSIYA manba qulfi orqali ushlanadi.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `home_page.dart` dagi o'lchamlar: karta 260 px, oraliq `AppSpacing.md` = 12,
/// tasma balandligi 148 px, kartalar soni 2.
const double _kCardWidth = 260;
const double _kGap = 12;
const double _kStripHeight = 148;

/// 360 px ekran - sahifaning 16 px chap/o'ng padding'i.
const double _kAvailableWidth = 328;

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _kAvailableWidth,
            height: _kStripHeight,
            child: child,
          ),
        ),
      ),
    );

Widget _card() => Container(width: _kCardWidth, color: Colors.grey);

void main() {
  group('Jamoa skeleti', () {
    testWidgets('MEXANIZM: yalang\'och `Row` 328 px da 216 px chiqib ketadi',
        (tester) async {
      await tester.pumpWidget(_host(
        Row(
          children: [
            _card(),
            const SizedBox(width: _kGap),
            _card(),
            const SizedBox(width: _kGap),
          ],
        ),
      ));

      final error = tester.takeException();
      expect(
        error,
        isA<FlutterError>(),
        reason: 'Agar bu yiqilsa — karta o\'lchami yoki sahifa padding\'i '
            'o\'zgargan. Detektorni tiklamasdan o\'chirma.',
      );
      // 260 + 12 + 260 + 12 = 544;  544 - 328 = 216. JONLI o'lchov bilan
      // AYNI raqam (360 px ekran).
      expect(error.toString(), contains('overflowed by 216 pixels'));
    });

    testWidgets('TUZATISH: gorizontal `ListView.separated` chiqib ketMAYDI',
        (tester) async {
      await tester.pumpWidget(_host(
        ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: _kGap),
          itemBuilder: (_, __) => _card(),
        ),
      ));

      expect(tester.takeException(), isNull);
      // Ikkinchi karta sig'masa ham CHIZILADI (`cacheExtent`), lekin xato
      // BERMAYDI — sig'magan qismi siljitiladi.
      expect(find.byType(Container), findsNWidgets(2));
    });

    test('REGRESSIYA: `_CommunityLoadingRow` yana `Row` ga qaytmasin', () {
      // Naqshlar BIR SATRLI -> `core.autocrlf=true` toza clone'da ham
      // moslashadi (`test/support/source_lock_portability_test.dart`).
      const path = 'lib/features/home/presentation/pages/home_page.dart';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path topilmadi');

      final source = file.readAsStringSync();
      final classAt = source.indexOf('class _CommunityLoadingRow');
      expect(classAt, greaterThan(-1),
          reason: '`_CommunityLoadingRow` yo\'q — skelet qayta yozilgan, '
              'qulfni yangila');

      final nextClass = source.indexOf('\nclass ', classAt + 1);
      final block = source.substring(
          classAt, nextClass == -1 ? source.length : nextClass);

      for (final needle in const <String>[
        'ListView.separated(',
        'scrollDirection: Axis.horizontal',
      ]) {
        expect(
          block.contains(needle),
          isTrue,
          reason: '`_CommunityLoadingRow` ichida `$needle` YO\'Q. Skelet '
              'yuklangan holat kabi SILJIYDIGAN tasma bo\'lishi kerak: '
              'yalang\'och `Row` barcha telefon kengliklarida chiqib ketadi '
              '(yuqoridagi MEXANIZM testi, jonli o\'lchov 216/186/146 px).',
        );
      }
    });
  });
}
