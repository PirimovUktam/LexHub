// ARIZA OYNASIDA OSHKORALIK OGOHLANTIRISHI — RAZILIK QULFI.
//
// O'LCHANGAN NUQSON (2026-09-03): `public_expert_profiles_view` `p.phone` ni
// beradi (`20260829000500_expert_license_visibility_and_lock.sql:63`) va shu
// view'ga `anon` uchun SELECT berilgan (`:85`). Ya'ni ariza TASDIQLANGANDAN
// keyin foydalanuvchining SHAXSIY telefon raqami tizimga KIRMAGAN mehmonga
// ham ko'rinadi, ilova esa uni ko'rsatadi va undan qo'ng'iroq qiladi
// (`expert_profile_modal.dart:426-429`, `tel:` havolasi).
//
// Ariza oynasi bu haqda HECH NIMA demasdi — `expertApplyIntro` faqat
// "Tasdiqlangan mutaxassislar ro'yxatiga kiritilasiz" deydi. Ya'ni razılık
// XABARDORLIKSIZ olinardi.
//
// NIMA UCHUN VIEW O'ZGARTIRILMADI: ochiq katalog ATAYLAB shunday
// (`20260829000500:77-79` litsenziya raqamini "ochiq ma'lumot" deb
// hujjatlaydi), jonli test uni qulflaydi va ilova ikki maydonni HAM
// ko'rsatadi — ustunni olib tashlash ishlaydigan funksiyani JIMGINA
// bo'shatardi (model `?? ''` fallback qiladi, xato bermaydi). Shuning uchun
// tuzatish FAQAT xabardorlik tomonida.
//
// ISBOT DARAJASI (§0): bu WIDGET testi — matn EKRANDA render bo'lishini
// o'lchaydi. U server xulqini isbotlamaydi; view holati alohida o'lchangan
// (rol `postgres`, `.runtime_evidence/views_security_invoker_scan.sql`).

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_legal_experts_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/apply_expert_dialog.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// HECH BIR metodi chaqirilmasligi SHART bo'lgan repozitoriy.
///
/// `UnimplementedError` ATAYLAB — jim `Right([])` qaytarsa, test tarmoqqa
/// chiqqanini SEZMASDAN o'tib ketardi (§20).
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

Widget _dialogApp(Locale locale) => l10nTestApp(
      BlocProvider<LegalExpertsBloc>(
        create: (_) => LegalExpertsBloc(
          getLegalExpertsUseCase: GetLegalExpertsUseCase(_UnusedRepository()),
        ),
        child: const Scaffold(body: ApplyExpertDialog()),
      ),
      locale: locale,
    );

/// Test yuzasini KENGAYTIRADI — sabab O'LCHANGAN va bu o'zgarishga ALOQASI
/// YO'Q.
///
/// Standart 800x600 test yuzasida `uz` tilida MUTAXASSISLIK dropdown'i o'ngga
/// chiqib ketadi: `A RenderFlex overflowed by 5.5 pixels on the right`
/// (`InputDecorator` ichidagi `Row`). Bu HEAD holatida — ogohlantirish qutisi
/// YO'Q vaqtda — ham AYNAN takrorlandi (2026-09-03 o'lchovi), `en` tilida esa
/// chiqmaydi: sabab dropdown elementlarining o'zbekcha matni uzunroq. Ya'ni
/// AVVALDAN BOR nuqson, alohida qayd etilgan.
///
/// ASSERTION YUMSHATILMAYDI: quyidagi tekshiruvlar qat'iy
/// `findsOneWidget`/`findsNothing` bo'lib qoladi. Faqat aloqasiz nuqson bu
/// testni ushlab qolmasligi uchun yuza kattalashtiriladi.
void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late AppL10n uz;
  late AppL10n en;

  setUpAll(() async {
    uz = await AppL10n.delegate.load(const Locale('uz'));
    en = await AppL10n.delegate.load(const Locale('en'));
  });

  group('1. MATN MAZMUNI — ogohlantirish AYNAN nimani aytadi', () {
    // Bu guruh render testini VAKUUMDAN saqlaydi: `findsOneWidget` bo'sh yoki
    // aloqasiz satr uchun ham o'tardi.
    test('har ikki tilda TELEFON aniq aytiladi', () {
      expect(uz.expertApplyPublicNotice.toLowerCase(), contains('telefon'),
          reason: 'ogohlantirish telefon raqami haqida GAPIRMAYDI — razılık '
              'xabardor emas');
      expect(en.expertApplyPublicNotice.toLowerCase(), contains('phone'));
    });

    test('KIM ko\'rishi aytiladi — mehmon / kirmagan foydalanuvchi', () {
      // Eng muhim fakt: `anon` ham ko'radi. "Ro'yxatda ko'rinadi" YETARLI
      // EMAS — foydalanuvchi buni "faqat a'zolar ko'radi" deb o'qishi mumkin.
      expect(uz.expertApplyPublicNotice.toLowerCase(), contains('mehmon'));
      expect(en.expertApplyPublicNotice.toLowerCase(), contains('signed in'));
    });

    test('MUTLAQ KAFOLAT bermaydi (himoyalanadigan so\'z yo\'q)', () {
      // Loyiha qoidasi: absolute guarantee YO'Q, defensible wording.
      for (final text in <String>[
        uz.expertApplyPublicNotice.toLowerCase(),
        en.expertApplyPublicNotice.toLowerCase(),
      ]) {
        expect(text, isNot(contains('100%')));
        expect(text, isNot(contains('kafolat')));
        expect(text, isNot(contains('guarantee')));
      }
    });

    test('litsenziya HUJJATI e\'lon qilinmasligi ham aytiladi', () {
      // O'LCHANGAN fakt: `license_document_url` view'dan ATAYLAB chiqarilgan
      // va bu qulflangan (`expert_verification_invariant_test.dart`). Ya'ni bu
      // tinchlantiruvchi jumla — HAQIQAT, marketing emas.
      expect(uz.expertApplyPublicNotice.toLowerCase(), contains('hujjat'));
      expect(en.expertApplyPublicNotice.toLowerCase(), contains('document'));
    });
  });

  group('2. EKRANDA RENDER — foydalanuvchi ko\'radi', () {
    testWidgets('uz: ogohlantirish YUBORISH tugmasi bilan BIR oynada',
        (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_dialogApp(const Locale('uz')));
      await tester.pumpAndSettle();

      expect(find.text(uz.expertApplyPublicNotice), findsOneWidget,
          reason: 'ogohlantirish ekranda YO\'Q');
      // Ogohlantirish tugmadan OLDIN ko'rinishi kerak — ikkisi ham AYNI
      // oynada topilishi buni isbotlaydi (foydalanuvchi yuborishdan oldin
      // matnni ko'radi, alohida ekranga o'tish shart emas).
      expect(find.text(uz.expertApplySubmit), findsOneWidget);
    });

    testWidgets('en: tarjima tushib qolmagan', (tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_dialogApp(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text(en.expertApplyPublicNotice), findsOneWidget);
      // O'zbekcha matn ingliz UI'da CHIQMASLIGI kerak (fallback nuqsoni).
      expect(find.text(uz.expertApplyPublicNotice), findsNothing);
    });
  });
}
