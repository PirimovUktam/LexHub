// ARIZA OYNASI — MUTAXASSISLIK DROPDOWN'I OVERFLOW QULFI.
//
// O'LCHANGAN NUQSON (2026-09-03, `.runtime_evidence/dropdown_overflow_probe.txt`):
// `DropdownButtonFormField` da `isExpanded` STANDART `false` bo'lganda
// `DropdownButton` o'z kengligini ENG UZUN element bo'yicha talab qiladi —
// hech narsa TANLANMAGAN bo'lsa ham. Natijada ariza oynasi OCHILISHIDA
// maydon o'z idishidan keng bo'lib `RenderFlex overflowed ... on the right`
// beradi: 360x740, 390x844, 430x932 kengliklarida `uz` da HAM, `en` da HAM;
// 800x600 test yuzasida esa faqat `uz` da 5.5 px (shu sababli u ilgari
// "o'zbekcha matn uzunroq" degan CHALG'ITUVCHI xulosa bergan — haqiqiy sabab
// KENGLIK).
//
// CHEGARA (§0): `flutter test` haqiqiy shrift ishlatmaydi — har bir belgi
// kvadrat (em) deb o'lchanadi, ya'ni matn kengligi SUN'IY OSHADI. Shuning
// uchun aynan piksel qiymatlari QURILMA qiymati emas va qurilmada tasdiqlash
// NOT VERIFIED. Nuqsonning O'ZI esa shriftga bog'liq emas: `isExpanded: false`
// maydon kengligini IDISHDAN MUSTAQIL, element matnidan kelib chiqib talab
// qiladi.
//
// NIMA UCHUN 700x800 VA TELEFON KENGLIGI EMAS: shu oynada IKKINCHI, ALOHIDA
// va HALI TUZATILMAGAN nuqson bor — amallar qatori (`apply_expert_dialog.dart`
// dagi `Row`, `mainAxisAlignment: end`) mavzudagi tugma to'ldirmasi bilan test
// shriftida 418.4 px (`en`) / 446.6 px (`uz`) talab qiladi va 360..430 px
// ekranda o'zi ham overflow beradi. U SHRIFTGA BOG'LIQ (qurilmada
// tasdiqlanmagan) va bu o'zgarishga ALOQASI YO'Q, shuning uchun ATAYLAB
// tuzatilmadi va alohida xabar qilindi. 700x800 tanlandi: oynaning ichki
// kengligi 572 px — amallar qatori (max 446.6) SIG'ADI, dropdown'ning eski
// talabi (677.5 px) esa SIG'MAYDI. Ya'ni bu yuza AYNAN dropdown nuqsonini
// o'lchaydi.
//
// ASSERTION YUMSHATILMAYDI: 1-test yuzaning HAQIQATAN tor ekanini isbotlaydi,
// aks holda 2-4 testlar bo'sh bo'lib qolardi.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_legal_experts_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/apply_expert_dialog.dart';

import '../../support/l10n_test_app.dart';

/// Oynaning ichki kengligi 572 px bo'ladigan yuza — sabab yuqorida.
const Size _kLogicalSize = Size(700, 800);

/// Real ro'yxatdagi ENG UZUN variant (35 belgi). `_specializations` maxfiy,
/// shuning uchun MEXANIZM testida aynan shu qiymat takrorlanadi.
const String _kLongestOption = 'Yo\'l harakati va Ma\'muriy jarimalar';

/// HECH BIR metodi chaqirilmasligi SHART bo'lgan repozitoriy — jim `Right([])`
/// qaytarsa, test tarmoqqa chiqqanini SEZMASDAN o'tib ketardi (§20).
class _UnusedRepository implements LegalExpertsRepository {
  @override
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async =>
      throw UnimplementedError('ro\'yxat bu testda so\'ralmaydi');

  @override
  Future<Either<Failure, LegalExpert>> getExpertById(String id) async =>
      throw UnimplementedError('advokat bu testda so\'ralmaydi');

  @override
  Future<Either<Failure, Map<String, dynamic>>> applyForVerification({
    required String specialization,
    required int experienceYears,
    required String licenseNumber,
    String? licenseDocumentUrl,
    String? workplace,
    String? education,
    double consultationFee = 0.0,
  }) async =>
      throw UnimplementedError('bu test ariza YUBORMAYDI');

  @override
  Future<Either<Failure, List<ExpertApplication>>>
      getPendingApplications() async =>
          throw UnimplementedError('moderatsiya bu testda yo\'q');

  @override
  Future<Either<Failure, Map<String, dynamic>>> verifyExpertApplication({
    required String userId,
    required bool approve,
    String? rejectionReason,
  }) async =>
      throw UnimplementedError('tasdiqlash bu testda yo\'q');
}

Future<void> _pumpDialog(WidgetTester tester, String locale) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = _kLogicalSize;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(l10nTestApp(
    BlocProvider<LegalExpertsBloc>(
      create: (_) => LegalExpertsBloc(
        getLegalExpertsUseCase: GetLegalExpertsUseCase(_UnusedRepository()),
      ),
      child: const Scaffold(body: ApplyExpertDialog()),
    ),
    locale: Locale(locale),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('1. MEXANIZM: `isExpanded` YO\'Q shakl shu yuzada overflow beradi',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = _kLogicalSize;
    addTearDown(tester.view.reset);

    // Tuzatishdan OLDINGI shakl: oynaning AYNI to'ldirmasi + AYNI eng uzun
    // element, lekin `isExpanded` berilmagan.
    await tester.pumpWidget(l10nTestApp(
      Scaffold(
        body: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Mutaxassislik sohasi *',
                prefixIcon: Icon(Icons.gavel_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: _kLongestOption,
                  child: Text(_kLongestOption),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ));

    final error = tester.takeException();
    expect(
      error,
      isA<FlutterError>(),
      reason: 'Yuza yetarlicha tor emas — quyidagi tekshiruvlar BO\'SH bo\'lib '
          'qoladi. `_kLogicalSize` ni kichraytir.',
    );
    expect(error.toString(), contains('overflowed'));
  });

  for (final locale in const ['uz', 'en']) {
    testWidgets('2. $locale: oyna OCHILISHIDA overflow YO\'Q', (tester) async {
      await _pumpDialog(tester, locale);

      expect(tester.takeException(), isNull,
          reason: 'ariza oynasi ochilishida layout xatosi bor');
      // Oyna HAQIQATAN qurilgani — aks holda yuqoridagi tekshiruv bo'sh
      // daraxtda ham o'tardi.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });
  }

  testWidgets('3. ENG UZUN variant TANLANGANDA ham overflow YO\'Q va maydon '
      'BIR QATOR qoladi', (tester) async {
    await _pumpDialog(tester, 'uz');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'ro\'yxat ochilishida layout xatosi bor');

    final items = tester
        .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>))
        .toList();
    expect(items.length, 7,
        reason: 'ro\'yxat ochilmadi — tanlash bosqichi VAKUUM bo\'lardi');

    final longest = items
        .map((i) => (i.child as Text).data!)
        .reduce((a, b) => b.length > a.length ? b : a);
    await tester.tap(find.text(longest).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'eng uzun variant tanlangandan keyin layout xatosi bor');

    // Maydon bir qatorda qolishi (o'lchangan balandlik 56.0). BU `isExpanded`
    // qulfi — `selectedItemBuilder` balandlikka TA'SIR QILMAYDI (pastda).
    final height =
        tester.getSize(find.byType(DropdownButtonFormField<String>)).height;
    expect(height, lessThanOrEqualTo(60.0),
        reason: 'maydon bir qatordan oshdi (balandlik $height)');

    // Tanlangan qiymat AYNAN maydonda ko'rinadi.
    expect(find.text(longest), findsOneWidget);

    // `selectedItemBuilder` QULFI — O'LCHANGAN, taxmin emas.
    //
    // Muhim tuzatish: ilgari bu yerda "builder bo'lmasa matn O'RALADI va
    // balandlik ikki qatorga o'sadi" deb yozilgandi. MUTATSIYA buni RAD ETDI
    // (builder olib tashlanganda test O'TIB KETDI), keyin o'lchov sababini
    // ko'rsatdi (`.runtime_evidence/dropdown_overflow_probe.txt`, 2-bo'lim):
    // `isExpanded: true` bo'lganda matn qutisi IKKI shaklda ham AYNI
    // (492/352/222/182 x 24.0) va xato YO'Q. Yagona farq — QIRQISH USULI:
    //   builder BILAN : maxLines=1, overflow=ellipsis  -> "...Ma'muri…"
    //   BUILDERSIZ    : maxLines=null, overflow=clip   -> harf O'RTASIDAN kesiladi
    // Shuning uchun qulf balandlik emas, AYNAN shu ikki xossani o'lchaydi.
    final para = tester.renderObject<RenderParagraph>(find.text(longest));
    expect(para.maxLines, 1,
        reason: 'tanlangan matn bir qatorga bog\'lanmagan');
    expect(para.overflow, TextOverflow.ellipsis,
        reason: 'matn ellipsis bilan emas, harf o\'rtasidan QIRQILADI');
  });
}

