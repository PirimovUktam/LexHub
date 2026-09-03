// BOSH SAHIFADAGI TIL TANLAGICHI — QULF.
//
// NIMA QULFLANADI (talab: "bosh sahifada yuqorida, ko'zga chiroyli, oson
// tezda ko'rinadigan, foydalanishga qulay"):
//   1. MEXANIZM — tanlagich HAQIQATAN daraxtda va telefon kengligida
//      OVERFLOW BERMAYDI (`uz` va `en` da);
//   2. HOLAT — `AppLocales.supported` dagi HAR bir til uchun segment bor va
//      faqat JORIY til `selected` (registrdan quriladi, qo'lda yozilmaydi);
//   3. AMAL — segmentni bosish tilni HAQIQATAN almashtiradi (`LocaleCubit`
//      state'i o'zgaradi) va matn YANGI tilda ko'rinadi;
//   4. XATO YO'LI — saqlash yiqilsa til O'ZGARMAYDI va foydalanuvchi REAL
//      xato xabarini ko'radi (yolg'on "muvaffaqiyatli" YO'Q);
//   5. TEGINISH MAYDONI — har bir segment 44x44 (WCAG 2.5.5 / 2.5.8) va
//      YUQORIDAN ham chegaralangan: pastki chegaraning O'ZI vakuum edi —
//      probe segmentni EKRAN balandligida (44x740) o'lchadi va `>= 44` shu
//      buzuq holatda ham o'tardi (`_kSegmentMaxSide` izohi);
//   6. SKRINREADER — yorliq TABIIY nom ("O'zbekcha"), "UZ" EMAS.
//
// CHEGARA (§0): bu `flutter test` muhitida o'lchanadi — haqiqiy shrift YO'Q,
// har bir belgi kvadrat (em) sifatida o'lchanadi, ya'ni matn kengligi SUN'IY
// OSHADI. Shuning uchun "overflow yo'q" natijasi QURILMADA kafolat emas
// (qurilmada matn TORROQ bo'ladi, ya'ni test ANIQROQ shartda o'tadi), lekin
// rang, holat, teginish maydoni va semantika shriftga BOG'LIQ EMAS.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/features/home/presentation/widgets/language_quick_switch.dart';

import '../../support/l10n_test_app.dart';
import '../../support/locale_test_cubit.dart';

/// Eng tor qo'llab-quvvatlanadigan telefon — bu yerda sig'sa, kattada ham.
const Size _kPhone = Size(360, 740);

/// Teginish maydonining YUQORI chegarasi.
///
/// NIMA UCHUN BOR (o'lchangan sabab, taxmin emas): faqat `>= 44` shartining
/// O'ZI VAKUUM edi. Vaqtinchalik probe bu widgetning BIRINCHI shaklini
/// `44x640 / 44x740 / 44x844 / 44x932` deb o'lchadi — `AnimatedContainer`
/// `alignment` berilganda mavjud bo'shliqni TO'LDIRADI, ya'ni segment EKRAN
/// balandligiga cho'zilgan edi va `>= 44` shu holatda ham O'TARDI. Yuqori
/// chegara aynan shu sinf nuqsonini qaytib kelishidan qulflaydi.
///
/// 56 — Material'ning eng katta ro'yxat elementi balandligi tartibi: undan
/// baland segment "cho'zilib ketgan" degani. O'lchangan haqiqiy qiymat 44.0.
const double _kSegmentMaxSide = 56;

Future<void> _pump(
  WidgetTester tester,
  LocaleCubit cubit, {
  String locale = 'uz',
  Size size = _kPhone,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    BlocProvider<LocaleCubit>.value(
      value: cubit,
      // Ilovadagi shakl: sahifa chetidan `AppSpacing.lg` (16) bo'shliq va
      // O'NGGA tekislash (`home_page.dart`).
      child: l10nTestApp(
        const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: LanguageQuickSwitch(),
              ),
            ),
          ),
        ),
        locale: Locale(locale),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Segmentning teginish maydoni — `InkWell` qutisi.
Iterable<Size> _segmentSizes(WidgetTester tester) =>
    tester.widgetList<InkWell>(find.byType(InkWell)).map(
          (w) => tester.getSize(find.byWidget(w)),
        );

void main() {
  testWidgets('1. telefon kengligida OVERFLOW YO\'Q (uz va en)',
      (tester) async {
    for (final locale in const ['uz', 'en']) {
      final cubit = testLocaleCubit(initial: Locale(locale));
      addTearDown(cubit.close);
      await _pump(tester, cubit, locale: locale);

      expect(tester.takeException(), isNull,
          reason: '$locale: tanlagichda layout xatosi bor');
      // Daraxt HAQIQATAN qurilgani — aks holda yuqoridagi tekshiruv BO'SH
      // daraxtda ham o'tardi.
      expect(find.byType(LanguageQuickSwitch), findsOneWidget);
      expect(
        tester.getSize(find.byType(LanguageQuickSwitch)).width,
        lessThanOrEqualTo(_kPhone.width - 32),
        reason: '$locale: tanlagich sahifa bo\'shlig\'idan chiqib ketdi',
      );
    }
  });

  testWidgets('2. HAR bir qo\'llab-quvvatlangan til uchun segment bor va '
      'faqat JORIYSI tanlangan', (tester) async {
    final cubit = testLocaleCubit(initial: AppLocales.english);
    addTearDown(cubit.close);
    await _pump(tester, cubit, locale: 'en');

    // Registr BO'SH bo'lib qolsa quyidagi tekshiruvlar ma'nosiz bo'ladi.
    expect(AppLocales.supported.length, greaterThanOrEqualTo(2),
        reason: 'registrda kamida ikki til bo\'lishi kerak');

    for (final locale in AppLocales.supported) {
      final code = locale.languageCode.toUpperCase();
      expect(find.text(code), findsOneWidget,
          reason: '$code segmenti yo\'q — ro\'yxat registrdan qurilmagan');
    }

    final selected = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.selected == true)
        .toList();
    expect(selected.length, 1,
        reason: 'tanlangan segment aynan BITTA bo\'lishi kerak');
    expect(selected.single.properties.label, AppLocales.nativeName(AppLocales.english),
        reason: 'skrinreader TABIIY nomni o\'qishi kerak, "EN" ni emas');
  });

  testWidgets('3. bosish tilni HAQIQATAN almashtiradi', (tester) async {
    final cubit = testLocaleCubit(initial: AppLocales.uzbek);
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    expect(cubit.state.languageCode, 'uz');

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(cubit.state.languageCode, 'en',
        reason: 'segment bosildi, lekin `LocaleCubit` state o\'zgarmadi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('4. SAQLASH YIQILSA til o\'zgarmaydi va REAL xato ko\'rinadi',
      (tester) async {
    final cubit = testLocaleCubit(initial: AppLocales.uzbek, failWrite: true);
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(cubit.state.languageCode, 'uz',
        reason: 'saqlash yiqilgan, lekin state o\'zgargan — YOLG\'ON success');
    // Xato xabari HOZIRGI (o'zgarmagan) tilda ko'rinadi.
    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'xato JIMGINA yo\'qoldi — foydalanuvchi hech narsa ko\'rmadi');
    expect(find.text('Tilni saqlab bo\'lmadi. Qaytadan urinib ko\'ring.'),
        findsOneWidget);
  });

  testWidgets('5. har bir segmentning teginish maydoni 44x44 va CHO\'ZILMAGAN',
      (tester) async {
    final cubit = testLocaleCubit();
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    final sizes = _segmentSizes(tester).toList();
    expect(sizes.length, AppLocales.supported.length,
        reason: 'segmentlar `InkWell` bilan bosiladi deb hisoblangan — '
            'shakl o\'zgargan bo\'lsa bu o\'lchov VAKUUM');
    for (final size in sizes) {
      expect(size.width, greaterThanOrEqualTo(kLanguageTapTarget),
          reason: 'teginish maydoni tor: $size');
      expect(size.height, greaterThanOrEqualTo(kLanguageTapTarget),
          reason: 'teginish maydoni past: $size');
      // YUQORI chegara — `_kSegmentMaxSide` izohidagi O'LCHANGAN nuqson
      // (segment ekran balandligiga cho'zilgan) qaytib kelmasligi uchun.
      expect(size.height, lessThanOrEqualTo(_kSegmentMaxSide),
          reason: 'segment CHO\'ZILDI: $size — `AnimatedContainer` bo\'sh '
              'joyni to\'ldirgan bo\'lishi mumkin (qat\'iy balandlik yo\'q)');
      expect(size.width, lessThanOrEqualTo(_kSegmentMaxSide),
          reason: 'segment KENGAYDI: $size');
    }

    // Pill BALANDLIGI ham qulflanadi: segment cho'zilsa u ham cho'ziladi,
    // ya'ni bu tekshiruv nuqsonni IKKI tomondan ushlaydi.
    expect(
      tester.getSize(find.byType(LanguageQuickSwitch)).height,
      lessThanOrEqualTo(_kSegmentMaxSide),
      reason: 'tanlagich pill\'i bosh sahifada haddan tashqari baland',
    );
  });

  testWidgets('6. tanlangan yorliq BIR QATOR va qirqilmagan', (tester) async {
    final cubit = testLocaleCubit();
    addTearDown(cubit.close);
    await _pump(tester, cubit);

    for (final locale in AppLocales.supported) {
      final para = tester.renderObject<RenderParagraph>(
        find.text(locale.languageCode.toUpperCase()),
      );
      expect(para.maxLines, 1, reason: 'yorliq bir qatorga bog\'lanmagan');
      expect(para.didExceedMaxLines, isFalse,
          reason: '${locale.languageCode} yorlig\'i qirqildi — segment tor');
    }
  });
}
