import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/theme/app_theme.dart';

import '../support/source_scan.dart';

/// TEMALI TUGMA CHEKSIZ KENGLIKDA — QULF.
///
/// JONLI DALIL (2026-09-04, debug web build, Playwright, haqiqiy shrift;
/// `.runtime_evidence/dialog_error_dump.txt`): ariza oynasi telefonda
/// UMUMAN chizilmasdi — ekranda faqat modal qorayishi qolardi.
///   BoxConstraints forces an infinite width.
///   The offending constraints were:
///     BoxConstraints(w=Infinity, 44.0<=h<=Infinity)
///   ElevatedButton:.../apply_expert_dialog.dart:408:25
///   creator: ConstrainedBox <- _InputPadding <- Semantics <- ElevatedButton
///            <- Row <- BlocListener <- BlocBuilder <- Column <- Form
///
/// SABAB (freymvork manbasidan): `Size.fromHeight(52)` =
/// `Size(double.infinity, 52)` (`sky_engine/lib/ui/geometry.dart:366`), ya'ni
/// mavzu tugmaga `minWidth: INFINITY` beradi. `Column` ichida bu ZARARSIZ —
/// `RenderConstrainedBox` `additionalConstraints.enforce(constraints)` qiladi
/// va cheksiz minWidth otaning CHEKLI maxWidth'iga qisqaradi ("to'liq
/// kenglik" idiomasi). Lekin `Row` flex BO'LMAGAN bolaga `maxWidth: infinity`
/// beradi -> qisqarish bo'lmaydi -> `box.dart:610` assert ishga tushadi.
///
/// Ya'ni nosozlik SHARTI = temali tugma + kenglikni CHEKLAMAYDIGAN ota.
/// Bu MATN O'LCHAMIGA BOG'LIQ EMAS, shuning uchun test shrifti bu qulfni
/// buzmaydi (§0: matnga tayanadigan piksel dalillari shubhali).
void main() {
  group('mavzu shakli', () {
    // NIMA UCHUN `testWidgets`, oddiy `test` EMAS: `AppTheme.lightTheme` ichida
    // `GoogleFonts.plusJakartaSansTextTheme()` chaqiriladi va u shriftni
    // TARMOQDAN olishga urinadi. Oddiy `test` da bu urinish HAQIQIY async'da
    // yiqiladi, xato test TUGAGANDAN KEYIN keladi va suite'ni qizil qiladi
    // (o'lchandi: shu fayl `test` bilan `+1 -1` berdi, stack —
    // `google_fonts_base.dart:288 _httpFetchFontAndSaveToDevice`).
    // `testWidgets` esa FakeAsync zonasida yuradi: fetch hech qachon
    // yakunlanmaydi, ya'ni xato KELMAYDI. Ayni sabab
    // `color_contrast_test.dart:53-58` da yozilgan.
    testWidgets('MEXANIZM MANBASI: mavzu `minWidth = infinity` beradi',
        (tester) async {
      late ThemeData theme;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (context) {
          theme = Theme.of(context);
          return const SizedBox.shrink();
        }),
      ));

      for (final entry in <String, ButtonStyle?>{
        'elevatedButtonTheme': theme.elevatedButtonTheme.style,
        'filledButtonTheme': theme.filledButtonTheme.style,
        'outlinedButtonTheme': theme.outlinedButtonTheme.style,
      }.entries) {
        final size = entry.value?.minimumSize?.resolve(const <WidgetState>{});
        expect(size, isNotNull, reason: '${entry.key}: minimumSize yo\'q');
        expect(
          size!.width,
          double.infinity,
          reason: '${entry.key}: `Size.fromHeight(...)` olib tashlangan bo\'lsa '
              'bu qulf ESKIRGAN — quyidagi MEXANIZM testi ham o\'z ma\'nosini '
              'yo\'qotadi, ikkovini birga qayta ko\'rib chiq.',
        );
      }
    });
  });

  /// Mavzuli qobiq — `chip_label_overflow_test.dart` dagi konvensiya: mavzu
  /// HAQIQIY (`AppTheme.lightTheme`), sinov uchun soxta mavzu emas.
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );

  /// `FlutterError.onError` VAQTINCHA egallanadi: layout yiqilganda bitta
  /// freymda BIR NECHTA xato chiqadi va `tester.takeException()` ularni
  /// "Multiple exceptions (N) were detected" xabariga ALMASHTIRADI
  /// (`flutter_test/src/binding.dart:1785`) — ya'ni haqiqiy sabab matni
  /// YO'QOLADI. Shuning uchun xatolar to'g'ridan-to'g'ri yig'iladi.
  Future<List<String>> pumpAndCollect(WidgetTester tester, Widget child) async {
    final captured = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => captured.add(details.exception.toString());
    try {
      await tester.pumpWidget(host(child));
    } finally {
      FlutterError.onError = previous;
    }
    return captured;
  }

  group('MEXANIZM — kenglikni CHEKLAMAYDIGAN ota', () {
    testWidgets('temali `ElevatedButton` `Row` ichida layout\'ni YIQITADI',
        (tester) async {
      final errors = await pumpAndCollect(
        tester,
        Row(
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Ariza')),
          ],
        ),
      );

      expect(errors, isNotEmpty, reason: 'nosozlik QAYTA HOSIL BO\'LMADI');
      expect(
        errors.first,
        contains('BoxConstraints forces an infinite width'),
        reason: 'jonli dumpdagi AYNI assert kutiladi (`box.dart:610`)',
      );
    });

    testWidgets('`OverflowBar` YOLG\'IZ yetarli emas — tugma CHO\'ZILADI',
        (tester) async {
      // `OverflowBar` bolalarga `constraints.loosen()` beradi, ya'ni maxWidth
      // CHEKLI -> cheksiz minWidth `enforce` bilan qisqaradi va assert
      // CHIQMAYDI. Lekin natija — tugma BUTUN qatorni egallaydi. Shu sababli
      // ariza oynasida IKKI o'zgarish ham kerak bo'ldi: yolg'iz `OverflowBar`
      // "Bekor qilish" ni har doim pastga tushirib yuborardi.
      final errors = await pumpAndCollect(
        tester,
        SizedBox(
          width: 300,
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Ariza')),
            ],
          ),
        ),
      );

      expect(errors, isEmpty);
      expect(tester.getSize(find.byType(ElevatedButton)).width, 300.0);
    });
  });

  group('TUZATISH — qo\'llangan shakl', () {
    testWidgets('`minimumSize: Size(64, 52)` `Row` ichida xato BERMAYDI',
        (tester) async {
      final errors = await pumpAndCollect(
        tester,
        Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(64, 52)),
              onPressed: () {},
              child: const Text('Ariza'),
            ),
          ],
        ),
      );

      expect(errors, isEmpty, reason: 'tuzatish ISHLAMADI: ${errors.join(" | ")}');
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    // O'LCHANGAN kengliklar: dialog ichidagi MAVJUD joy (haqiqiy shrift,
    // Playwright, `.runtime_evidence/apply_dialog_*.png`) — 360 px ekranda
    // 232 px, 390 -> 262 px, 430 -> 302 px.
    for (final width in const <double>[232, 262, 302]) {
      testWidgets('amallar qatorining YAKUNIY shakli ${width.toInt()} px da toza',
          (tester) async {
        final errors = await pumpAndCollect(
          tester,
          SizedBox(width: width, child: _actionsShape()),
        );

        // `OverflowBar` sig'masa bolalarni VERTIKAL joylaydi, ya'ni overflow
        // TUZILISH bo'yicha mumkin emas — bu da'vo shriftga BOG'LIQ EMAS.
        expect(errors, isEmpty, reason: '${width.toInt()} px: ${errors.join(" | ")}');
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
      });
    }

    testWidgets('NEGATIV NAZORAT: ayni ikki tugma `Row` da sig\'maydi',
        (tester) async {
      // NIMA UCHUN PIKSEL SONI YO'Q (§0): sinov shrifti har belgini em kvadrat
      // deb o'lchaydi, ya'ni HAQIQIY shriftdan KENG. Bu test faqat SINFNI
      // qulflaydi — "`Row` bu ikki tugma uchun to'g'ri idish emas". Haqiqiy
      // shriftdagi 15 px kamomad JONLI probe'da o'lchandi (360 px, uz).
      final errors = await pumpAndCollect(
        tester,
        SizedBox(
          width: 232,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () {}, child: const Text('Bekor qilish')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(64, 52)),
                onPressed: () {},
                child: const Text('Ariza yuborish'),
              ),
            ],
          ),
        ),
      );

      expect(errors, isNotEmpty);
      expect(errors.join('\n'), contains('overflowed'));
    });
  });

  group('REGRESSIYA — tuzatish manbadan QAYTMASIN', () {
    // Naqshlar BIR SATRLI: `core.autocrlf=true` bo'lgan toza clone'da ham
    // moslashadi (`test/support/source_lock_portability_test.dart` meta-qulfi).
    // Izohlar OLIB TASHLANADI — qulf FAQAT kodga tayanishi kerak.
    for (final entry in const <String, List<String>>{
      'lib/features/legal_experts/presentation/widgets/apply_expert_dialog.dart':
          <String>['minimumSize: const Size(64, 52)', 'OverflowBar('],
      'lib/features/consultations/presentation/pages/my_consultations_page.dart':
          <String>['minimumSize: const Size(64, 50)'],
    }.entries) {
      test('${entry.key.split('/').last} qulfi', () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: '${entry.key} topilmadi');
        final code = stripLineComments(file.readAsStringSync());

        for (final needle in entry.value) {
          expect(
            code.contains(needle),
            isTrue,
            reason: '`$needle` YO\'Q. Mavzu tugmaga `minWidth = infinity` '
                'beradi (yuqoridagi MEXANIZM testi), bu tugmalar esa kenglikni '
                'cheklamaydigan otada turadi — olib tashlansa ekran YANA '
                'chizilmaydi. Jonli dalil: `.runtime_evidence/'
                'dialog_error_dump.txt`.',
          );
        }
      });
    }
  });
}

/// Ariza oynasidagi amallar qatorining YAKUNIY shakli
/// (`apply_expert_dialog.dart:408`) — ayni parametrlar bilan.
Widget _actionsShape() => OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: 8,
      overflowAlignment: OverflowBarAlignment.end,
      overflowSpacing: 8,
      children: [
        TextButton(onPressed: () {}, child: const Text('Bekor qilish')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(64, 52)),
          onPressed: () {},
          child: const Text('Ariza yuborish'),
        ),
      ],
    );
