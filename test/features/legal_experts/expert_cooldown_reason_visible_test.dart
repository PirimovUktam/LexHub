// SOVUTISH DAVRI: SABAB VA VAQT HAR TILDA KO'RINADI.
//
// NUQSON (2026-08-30): rad etish SABABI va qayta topshirish VAQTI faqat
// server xato MATNI ichida edi. `errorStateText` server matnini FAQAT `uz`
// uchun ishlatadi (`failure_text.dart`), boshqa tilda `FailureCode` bo'yicha
// UMUMIY ARB matnini beradi — ya'ni INGLIZ UI'da arizachi na sababni, na
// vaqtni ko'rmasdi. Arizachi uchun "mening arizam holati" ekrani YO'Q,
// shuning uchun bu YAGONA kanal edi.
//
// BU TEST QULFLAYDIGAN ZANJIR (uchi-uchiga, klient tomoni):
//   server `DETAIL` JSON
//     -> `ExpertApplicationCooldownMapper.tryParse`
//     -> `ServerException.details`
//     -> `ErrorHandler` (details O'ZGARTIRILMAYDI)
//     -> `ExpertApplicationError.cooldown`
//     -> `expertCooldownText` (uz + en)
//
// PASAYISH YO'Q: `cooldown == null` (eski server yoki shakl mos kelmadi)
// holatida avvalgi `errorStateText` xatti-harakati saqlanadi — bu ham
// tekshiriladi.
//
// CHEKLOV (§0, halol qayd): bu KLIENT zanjiri testi. HAQIQIY arizachi JWT
// bilan `apply_for_expert_verification` chaqiruvi O'LCHANMADI — migratsiya
// sessiyasida `auth.uid()` NULL (`20260830070000_...sql` sarlavhasidagi
// qayd). Ya'ni serverning `DETAIL` ni AYNAN shu shaklda yuborishi
// PARTIALLY VERIFIED: migratsiya ichidagi D1/D2 assertionlari serverda
// bajarildi, lekin uchi-uchiga runtime chaqiruv yo'q.

import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/features/legal_experts/data/models/expert_application_cooldown_mapper.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application_cooldown.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/apply_expert_verification_usecase.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_legal_experts_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_state.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/apply_expert_dialog.dart';

/// Ariza yo'lida BERILGAN `Failure` ni qaytaradigan repozitoriy.
///
/// Boshqa metodlar `UnimplementedError` beradi (jim `Right` EMAS): bu testda
/// ular chaqirilmasligi SHART, chaqirilsa test yashirin ravishda "o'tib"
/// ketardi (§20).
class _FailingApplyRepository implements LegalExpertsRepository {
  final Failure failure;

  _FailingApplyRepository(this.failure);

  @override
  Future<Either<Failure, Map<String, dynamic>>> applyForVerification({
    required String specialization,
    required int experienceYears,
    required String licenseNumber,
    String? licenseDocumentUrl,
    String? workplace,
    String? education,
    double consultationFee = 0.0,
  }) async {
    return Left(failure);
  }

  @override
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async =>
      throw UnimplementedError('bu testda ro\'yxat so\'ralmaydi');

  @override
  Future<Either<Failure, LegalExpert>> getExpertById(String id) async =>
      throw UnimplementedError('bu testda advokat so\'ralmaydi');

  @override
  Future<Either<Failure, List<ExpertApplication>>>
      getPendingApplications() async =>
          throw UnimplementedError('bu testda moderatsiya kutilmaydi');

  @override
  Future<Either<Failure, Map<String, dynamic>>> verifyExpertApplication({
    required String userId,
    required bool approve,
    String? rejectionReason,
  }) async =>
      throw UnimplementedError('bu testda tasdiqlash RPC chaqirilmaydi');
}

void main() {
  // Serverning HAQIQIY shakli (`20260830070000_...sql` dagi
  // `jsonb_build_object`). Vaqt ATAYLAB UTC ofseti bilan — mapper uni
  // mahalliy vaqtga aylantirishi kerak.
  const serverJson = '{"lx":"application_cooldown",'
      '"retry_at":"2026-08-31T05:00:00+00:00",'
      '"reason":"Litsenziya nusxasi o\'qilmaydi"}';

  group('Mapper — server DETAIL -> tipli obyekt', () {
    test('JSON MATNI (PostgREST shakli) o\'qiladi', () {
      final c = ExpertApplicationCooldownMapper.tryParse(serverJson);

      expect(c, isNotNull);
      expect(c!.reason, "Litsenziya nusxasi o'qilmaydi");
      // MAHALLIY vaqt: serverdagi xom UTC matni ko'rsatilmaydi.
      expect(c.retryAt.isUtc, isFalse);
      expect(
        c.retryAt.toUtc(),
        DateTime.utc(2026, 8, 31, 5, 0, 0),
      );
    });

    test('allaqachon `Map` bo\'lsa ham o\'qiladi', () {
      final c = ExpertApplicationCooldownMapper.tryParse(
        jsonDecode(serverJson) as Map<String, dynamic>,
      );

      expect(c, isNotNull);
      expect(c!.reason, "Litsenziya nusxasi o'qilmaydi");
    });

    test('SABAB YO\'Q (server `reason: null` shoxi) -> `reason == null`', () {
      final c = ExpertApplicationCooldownMapper.tryParse(
        '{"lx":"application_cooldown",'
        '"retry_at":"2026-08-31T05:00:00+00:00","reason":null}',
      );

      expect(c, isNotNull);
      // `null` = sabab YOZILMAGAN. Bu HAQIQIY holat, yo'qolgan ma'lumot emas.
      expect(c!.reason, isNull);
    });

    test('BO\'SH/oraliqli sabab ham `null` (bo\'sh sarlavha chiqmasin)', () {
      final c = ExpertApplicationCooldownMapper.tryParse(
        '{"lx":"application_cooldown",'
        '"retry_at":"2026-08-31T05:00:00+00:00","reason":"   "}',
      );

      expect(c?.reason, isNull);
    });

    test('BELGI mos kelmasa `null` (boshqa xatoning DETAIL\'i o\'zlashmaydi)',
        () {
      expect(
        ExpertApplicationCooldownMapper.tryParse(
          '{"lx":"something_else","retry_at":"2026-08-31T05:00:00+00:00"}',
        ),
        isNull,
      );
    });

    test('`retry_at` buzuq yoki yo\'q bo\'lsa `null`', () {
      expect(
        ExpertApplicationCooldownMapper.tryParse(
          '{"lx":"application_cooldown","retry_at":"kecha"}',
        ),
        isNull,
      );
      expect(
        ExpertApplicationCooldownMapper.tryParse(
          '{"lx":"application_cooldown"}',
        ),
        isNull,
      );
    });

    test('JSON BO\'LMAGAN xom server matni `null` beradi (otmaydi)', () {
      expect(ExpertApplicationCooldownMapper.tryParse('Key (user_id)=(...)'),
          isNull);
      expect(ExpertApplicationCooldownMapper.tryParse('{buzuq'), isNull);
      expect(ExpertApplicationCooldownMapper.tryParse(null), isNull);
      expect(ExpertApplicationCooldownMapper.tryParse(42), isNull);
    });
  });

  group('ErrorHandler — `details` O\'ZGARTIRILMAYDI', () {
    test('423 + tipli `details` -> `applicationCooldown` + ayni obyekt', () {
      final cooldown = ExpertApplicationCooldownMapper.tryParse(serverJson)!;
      final failure = ErrorHandler.handle(
        ServerException(
          message: 'Ariza rad etilgan.',
          statusCode: 423,
          details: cooldown,
        ),
      );

      expect(failure.code, FailureCode.applicationCooldown);
      // AYNI obyekt: matndan qayta ajratib olish YO'Q.
      expect(failure.details, same(cooldown));
    });
  });

  group('BLoC — sovutish ma\'lumoti state\'ga yetib boradi', () {
    test('tipli `details` -> `ExpertApplicationError.cooldown`', () async {
      final cooldown = ExpertApplicationCooldownMapper.tryParse(serverJson)!;
      final repo = _FailingApplyRepository(ServerFailure(
        message: 'Ariza rad etilgan.',
        statusCode: 423,
        details: cooldown,
        code: FailureCode.applicationCooldown,
      ));
      final bloc = LegalExpertsBloc(
        getLegalExpertsUseCase: GetLegalExpertsUseCase(repo),
        applyExpertVerificationUseCase: ApplyExpertVerificationUseCase(repo),
      );
      addTearDown(bloc.close);

      final future = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ExpertApplicationSubmitting>(),
          predicate<LegalExpertsState>((s) =>
              s is ExpertApplicationError &&
              s.code == FailureCode.applicationCooldown &&
              s.cooldown == cooldown),
        ]),
      );

      bloc.add(const SubmitExpertApplicationEvent(
        specialization: 'Mehnat huquqi',
        experienceYears: 5,
        licenseNumber: 'ADV-00001',
      ));

      await future;
    });

    test('tuzilgan ma\'lumot bo\'lmasa `cooldown == null` (xom matn o\'zlashmaydi)',
        () async {
      final repo = _FailingApplyRepository(const ServerFailure(
        message: 'Ariza rad etilgan.',
        statusCode: 423,
        details: 'PostgrestException(message: ..., code: LX429)',
        code: FailureCode.applicationCooldown,
      ));
      final bloc = LegalExpertsBloc(
        getLegalExpertsUseCase: GetLegalExpertsUseCase(repo),
        applyExpertVerificationUseCase: ApplyExpertVerificationUseCase(repo),
      );
      addTearDown(bloc.close);

      final future = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ExpertApplicationSubmitting>(),
          predicate<LegalExpertsState>(
              (s) => s is ExpertApplicationError && s.cooldown == null),
        ]),
      );

      bloc.add(const SubmitExpertApplicationEvent(
        specialization: 'Mehnat huquqi',
        experienceYears: 5,
        licenseNumber: 'ADV-00001',
      ));

      await future;
    });
  });

  group('Matn — SABAB VA VAQT ikki tilda ham ko\'rinadi', () {
    late AppL10n uz;
    late AppL10n en;
    // Mahalliy vaqtga aylantirilgan kutilgan satr: test mashinasining vaqt
    // mintaqasi qotib qolmasligi kerak (CI UTC'da ishlashi mumkin).
    final retryAt = DateTime.utc(2026, 8, 31, 5, 0, 0).toLocal();
    final expectedDay = retryAt.day.toString().padLeft(2, '0');
    final expectedHour = retryAt.hour.toString().padLeft(2, '0');

    setUp(() async {
      uz = await AppL10n.delegate.load(const Locale('uz'));
      en = await AppL10n.delegate.load(const Locale('en'));
    });

    test('INGLIZ UI: sabab va vaqt matnda BOR', () {
      final text = expertCooldownText(
        en,
        'Ariza rad etilgan. Sabab: Litsenziya nusxasi o\'qilmaydi.',
        FailureCode.applicationCooldown,
        ExpertApplicationCooldown(
          retryAt: retryAt,
          reason: "Litsenziya nusxasi o'qilmaydi",
        ),
      );

      expect(text, contains("Litsenziya nusxasi o'qilmaydi"));
      expect(text, contains('$expectedDay.08.2026'));
      expect(text, contains('$expectedHour:00'));
      // Ingliz shabloni: o'zbekcha server matni AYNAN ko'chirilmaydi.
      expect(text, contains('re-apply'));
      expect(text, isNot(contains('Qayta topshirish')));
    });

    test('O\'ZBEK UI: sabab va vaqt matnda BOR (pasayish yo\'q)', () {
      final text = expertCooldownText(
        uz,
        'Ariza rad etilgan. Sabab: Litsenziya nusxasi o\'qilmaydi.',
        FailureCode.applicationCooldown,
        ExpertApplicationCooldown(
          retryAt: retryAt,
          reason: "Litsenziya nusxasi o'qilmaydi",
        ),
      );

      expect(text, contains("Litsenziya nusxasi o'qilmaydi"));
      expect(text, contains('$expectedDay.08.2026'));
      expect(text, contains('Qayta topshirish'));
    });

    test('SABAB YO\'Q -> bo\'sh "Sabab:" sarlavhasi KO\'RSATILMAYDI', () {
      for (final l10n in [uz, en]) {
        final text = expertCooldownText(
          l10n,
          'Ariza rad etilgan.',
          FailureCode.applicationCooldown,
          ExpertApplicationCooldown(retryAt: retryAt),
        );

        expect(text, contains('$expectedDay.08.2026'));
        expect(text.toLowerCase(), isNot(contains('sabab:')));
        expect(text.toLowerCase(), isNot(contains('reason:')));
      }
    });

    test('`cooldown == null` -> AVVALGI xatti-harakat (`errorStateText`)', () {
      const serverMsg = 'Ariza rad etilgan. Qayta topshirish ... mumkin.';

      expect(
        expertCooldownText(
            uz, serverMsg, FailureCode.applicationCooldown, null),
        errorStateText(uz, serverMsg, FailureCode.applicationCooldown),
      );
      expect(
        expertCooldownText(
            en, serverMsg, FailureCode.applicationCooldown, null),
        en.errorApplicationCooldown,
      );
    });

    test('ARB shablonlari ikki tilda ham TARJIMA qilingan', () {
      // Bir xil qolsa `arb_parity_test.dart` `_identicalAllowed` talab
      // qilardi; bu yerda ular ATAYLAB boshqa-boshqa.
      expect(uz.errorApplicationCooldownUntil('X'),
          isNot(en.errorApplicationCooldownUntil('X')));
      expect(uz.errorApplicationCooldownUntilWithReason('R', 'X'),
          isNot(en.errorApplicationCooldownUntilWithReason('R', 'X')));
      // Qiymatlar shablonga HAQIQATAN qo'yiladi.
      expect(en.errorApplicationCooldownUntilWithReason('R1', 'T1'),
          allOf(contains('R1'), contains('T1')));
    });
  });

  group('MUVAFFAQIYAT matni — o\'zbekcha SnackBar ingliz UI\'ga chiqmaydi', () {
    late AppL10n uz;
    late AppL10n en;

    setUp(() async {
      uz = await AppL10n.delegate.load(const Locale('uz'));
      en = await AppL10n.delegate.load(const Locale('en'));
    });

    test('O\'ZBEK UI: serverning o\'z matni AYNAN ko\'rsatiladi', () {
      expect(
        expertApplySuccessText(uz, 'Ariza qabul qilindi.'),
        'Ariza qabul qilindi.',
      );
    });

    test('INGLIZ UI: o\'zbekcha server matni KO\'RSATILMAYDI', () {
      final text = expertApplySuccessText(en, 'Ariza qabul qilindi.');

      expect(text, en.expertApplySuccess);
      expect(text, isNot(contains('Ariza')));
    });

    test('Server matn bermasa — har ikki tilda ARB matni', () {
      expect(expertApplySuccessText(uz, ''), uz.expertApplySuccess);
      expect(expertApplySuccessText(uz, '   '), uz.expertApplySuccess);
      expect(expertApplySuccessText(en, ''), en.expertApplySuccess);
    });

    test('BLoC o\'zbekcha fallback MATNINI O\'ZI QURMAYDI', () {
      // Ilgari bloc `?? "Ariza muvaffaqiyatli topshirildi."` qilardi va bu
      // matn ingliz UI'da XOM chiqardi (`Text(state.message)`).
      final src = File('lib/features/legal_experts/presentation/bloc/'
              'legal_experts_bloc.dart')
          .readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(code, isNot(contains('Ariza muvaffaqiyatli topshirildi')));
    });
  });

  group('Server shakli — klient kutgan kalitlar bilan bir xil', () {
    test('migratsiya `lx`/`retry_at`/`reason` kalitlarini yuboradi', () {
      final sql = File('supabase/migrations/'
              '20260830070000_expert_cooldown_machine_readable.sql')
          .readAsStringSync();
      final code = sql
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n');

      expect(code, contains("'lx', 'application_cooldown'"));
      expect(code, contains("'retry_at', to_jsonb("));
      expect(code, contains("'reason', v_reason"));
      // Klientdagi belgi bilan AYNI satr.
      expect(ExpertApplicationCooldownMapper.marker, 'application_cooldown');
      expect(code, contains(ExpertApplicationCooldownMapper.marker));
    });
  });
}
