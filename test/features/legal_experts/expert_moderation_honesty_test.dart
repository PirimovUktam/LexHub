/// ARIZA MODERATSIYASI — HALOLLIK QULFLARI (§20, §21).
///
/// Bu fayl `ExpertModerationBloc` ning XATTI-HARAKATINI (statik matn emas)
/// va PII chegarasini qulflaydi. Har bir test bitta ANIQ yolg'on shaklini
/// qaytib kelishidan saqlaydi:
///
///   1. Rad etish arizani ro'yxatdan MAHALLIY o'chirib "bajarildi" ko'rinishi.
///      Server holati (`rejected_at`) `20260829010000_expert_rejection_and_revocation
///      .sql` bilan qo'shildi va JONLI bazada RUNTIME'da o'lchandi, ya'ni rad
///      etilgan ariza endi haqiqatan ro'yxatdan chiqadi.
///
///      SHUNGA QARAMAY QULF O'ZGARMAYDI: bloc serverdan qaytgan ro'yxatni
///      ko'rsatishi kerak, O'Z TAXMININI emas. Fake ATAYLAB rad etishdan
///      keyin ham ikkala arizani qaytaradi — agar bloc qatorni mahalliy
///      o'chirsa, u serverni emas, o'zini ishonchli manba deb hisoblayotgan
///      bo'ladi. Bu xatti-harakat filtr buzilganda (masalan ustun tushib
///      qolsa) yolg'on ko'rsatishga aylanardi.

///   2. RPC o'tib, ro'yxatni qayta o'qish yiqilganda buni yashirish.
///   3. Xato holatida ro'yxatni yo'q qilib, moderatorni ma'lumotsiz qoldirish.
///   4. Litsenziya hujjati (PII) ochiq katalog ekranlariga chiqib ketishi.
///
/// BU RUNTIME DALIL EMAS: real Supabase va real admin sessiyasi bu yerda
/// ishlatilmaydi. Bu — regression qulfi. Serverdagi haqiqiy huquq chegarasi
/// `expert_verification_invariant_test.dart` da (SQL manbasi bo'yicha)
/// qulflangan, real tasdiqlash esa qurilmada o'lchanishi kerak.
library;

import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_pending_applications_usecase.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/verify_expert_application_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_state.dart';

const _appA = ExpertApplication(
  applicationId: 'app-a',
  userId: 'user-a',
  fullName: 'Arizachi A',
  licenseNumber: 'ADV-0001',
  specialization: 'Mehnat huquqi',
  workplace: 'Toshkent',
  education: 'TDYU',
  experienceYears: 5,
);

const _appB = ExpertApplication(
  applicationId: 'app-b',
  userId: 'user-b',
  fullName: 'Arizachi B',
  licenseNumber: 'ADV-0002',
  specialization: 'Oila huquqi',
  workplace: 'Samarqand',
  education: 'TDYU',
  experienceYears: 3,
);

/// Boshqariladigan fake. `getPendingApplications` HAR CHAQIRUVDA navbatdagi
/// javobni beradi — shu bilan "RPC o'tdi, qayta o'qish yiqildi" holatini
/// aynan modellashtira olamiz.
class _FakeRepo implements LegalExpertsRepository {
  _FakeRepo({required this.pendingQueue, this.verifyResult});

  final List<Either<Failure, List<ExpertApplication>>> pendingQueue;
  final Either<Failure, Map<String, dynamic>>? verifyResult;

  int pendingCalls = 0;
  final List<({String userId, bool approve})> verifyCalls = [];

  @override
  Future<Either<Failure, List<ExpertApplication>>>
      getPendingApplications() async {
    final index = pendingCalls < pendingQueue.length
        ? pendingCalls
        : pendingQueue.length - 1;
    pendingCalls++;
    return pendingQueue[index];
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> verifyExpertApplication({
    required String userId,
    required bool approve,
  }) async {
    verifyCalls.add((userId: userId, approve: approve));
    return verifyResult ??
        const Right<Failure, Map<String, dynamic>>(
          {'success': true, 'status': 'approved'},
        );
  }

  // Quyidagilar bu testda ISHLATILMAYDI. `UnimplementedError` ATAYLAB:
  // jim bo'sh natija qaytarish testni yashirin ravishda "o'tdi" qilardi.
  @override
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async =>
      throw UnimplementedError('katalog bu testda kutilmaydi');

  @override
  Future<Either<Failure, LegalExpert>> getExpertById(String id) async =>
      throw UnimplementedError('katalog bu testda kutilmaydi');

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
      throw UnimplementedError('ariza topshirish bu testda kutilmaydi');
}

ExpertModerationBloc _blocFor(_FakeRepo repo) => ExpertModerationBloc(
      getPendingApplicationsUseCase: GetPendingApplicationsUseCase(repo),
      verifyExpertApplicationUseCase: VerifyExpertApplicationUseCase(repo),
    );

void main() {
  group('1. RAD ETISH — jim no-op yolg\'on ko\'rsatilmaydi', () {
    test('rad etilgan ariza ro\'yxatdan MAHALLIY o\'chirilmaydi', () async {
      // Server holati: rad etishdan KEYIN ham ikkala ariza qaytadi, chunki
      // `verified_at` NULL qoldi. Bloc shu haqiqatni ko'rsatishi kerak.
      final repo = _FakeRepo(pendingQueue: [
        const Right([_appA, _appB]),
        const Right([_appA, _appB]),
      ]);
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(const ModerateApplicationEvent(
          userId: 'user-a', approve: false));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionDone &&
            s.approved == false &&
            s.listRefreshed == true &&
            s.applications.length == 2 &&
            s.applications.any((a) => a.userId == 'user-a'))),
      );

      expect(repo.verifyCalls.single.approve, isFalse);
      expect(repo.verifyCalls.single.userId, 'user-a');
    });

    test('TASDIQLASH esa serverdan qaytgan qisqargan ro\'yxatni oladi',
        () async {
      final repo = _FakeRepo(pendingQueue: [
        const Right([_appA, _appB]),
        const Right([_appB]),
      ]);
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(
          const ModerateApplicationEvent(userId: 'user-a', approve: true));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionDone &&
            s.approved == true &&
            s.listRefreshed == true &&
            s.applications.length == 1 &&
            s.applications.single.userId == 'user-b')),
      );
    });
  });

  group('2. RPC O\'TDI, QAYTA O\'QISH YIQILDI — yashirilmaydi', () {
    test('`listRefreshed` FALSE bo\'ladi va ro\'yxat to\'qilmaydi', () async {
      final repo = _FakeRepo(pendingQueue: [
        const Right([_appA, _appB]),
        const Left(NetworkFailure(
            message: 'tarmoq yo\'q', code: FailureCode.network)),
      ]);
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(
          const ModerateApplicationEvent(userId: 'user-a', approve: true));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionDone &&
            s.listRefreshed == false &&
            // Tasdiqlangan ariza mahalliy ro'yxatdan olib tashlanadi (RPC
            // O'TDI), lekin bu holat SnackBar'da "ro'yxat eskirgan" deb
            // aytiladi — `listRefreshed == false` shuning uchun bor.
            s.applications.length == 1 &&
            s.applications.single.userId == 'user-b')),
      );
    });

    test('RAD ETISH + qayta o\'qish yiqilishi: qator OLIB TASHLANADI', () async {
      // Serverda rad etish `rejected_at` yozadi va ariza kutayotganlar
      // filtridan CHIQADI (RUNTIME'DA o'lchangan 2026-08-29: 1 -> 0), shuning
      // uchun qayta o'qish yiqilsa ham qator mahalliy olib tashlanadi. Ilgari
      // bu shox arizani ATAYLAB qoldirardi — o'sha paytda bazada "rad etilgan"
      // holati YO'Q edi. Endi uni qoldirish YOLG'ON bo'lardi.
      //
      // `listRefreshed` baribir FALSE: mahalliy tuzatish qayta o'qish O'RNINI
      // BOSMAYDI va SnackBar buni aytadi.
      final repo = _FakeRepo(pendingQueue: [
        const Right([_appA, _appB]),
        const Left(NetworkFailure(
            message: 'tarmoq yo\'q', code: FailureCode.network)),
      ]);
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(const ModerateApplicationEvent(
          userId: 'user-a', approve: false));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionDone &&
            s.approved == false &&
            s.listRefreshed == false &&
            s.applications.length == 1 &&
            s.applications.single.userId == 'user-b')),
      );
    });

    test('RPC YIQILSA ro\'yxat SAQLANADI va xato KO\'RSATILADI', () async {
      final repo = _FakeRepo(
        pendingQueue: [const Right([_appA, _appB])],
        verifyResult: const Left(ServerFailure(
            message: 'Bu amal uchun ruxsat yo\'q.',
            code: FailureCode.forbidden)),
      );
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(
          const ModerateApplicationEvent(userId: 'user-a', approve: true));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionFailed &&
            s.code == FailureCode.forbidden &&
            s.applications.length == 2)),
      );

      // Xato holatida QAYTA O'QISH bo'lmaydi: RPC yiqilgan, server holati
      // o'zgarmagan — ortiqcha so'rov ma'nosiz.
      expect(repo.pendingCalls, 1);
    });
  });

  group('3. PII — litsenziya hujjati faqat moderatsiyada', () {
    test('`licenseDocumentUrl` ni FAQAT moderatsiya ekrani o\'qiydi', () {
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        final src = file.readAsStringSync();
        if (!src.contains('licenseDocumentUrl') &&
            !src.contains('license_document_url')) {
          continue;
        }
        // Ruxsat etilgan qatlamlar: entity/model (o'qish sxemasi), datasource
        // (ariza topshirish), repository/usecase (uzatish).
        //
        // `/presentation/bloc/` HAM RUXSAT: `SubmitExpertApplicationEvent`
        // foydalanuvchining O'Z hujjat havolasini serverga UZATADI — bu PII
        // KO'RSATISH emas. Haqiqiy xavf — havolani BOSHQA odamga render
        // qilish, shuning uchun asl qulf keyingi testda: `pages/` va
        // `widgets/` ichida faqat MODERATSIYA ekrani.
        final allowed = path.contains('/domain/entities/') ||
            path.contains('/data/models/') ||
            path.contains('/data/datasources/') ||
            path.contains('/data/repositories/') ||
            path.contains('/domain/repositories/') ||
            path.contains('/domain/usecases/') ||
            path.contains('/presentation/bloc/') ||
            path.endsWith('presentation/pages/expert_moderation_page.dart');
        if (!allowed) offenders.add(path);
      }
      expect(offenders, isEmpty,
          reason: 'litsenziya hujjati (PII) moderatsiyadan tashqarida '
              'ko\'rsatilayapti: $offenders');
    });

    test('EKRAN qatlamida hujjat havolasini FAQAT bitta fayl ishlatadi', () {
      final renderers = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        final isScreen =
            path.contains('/presentation/pages/') ||
                path.contains('/presentation/widgets/');
        if (!isScreen) continue;
        if (file.readAsStringSync().contains('licenseDocumentUrl')) {
          renderers.add(path);
        }
      }
      expect(renderers, hasLength(1),
          reason: 'PII havolasi yangi ekranga tarqaldi: $renderers');
      expect(renderers.single,
          endsWith('presentation/pages/expert_moderation_page.dart'));
    });

    test('ochiq katalog view\'i hujjat URL ustunini BERMAYDI', () {
      // Fayl 2026-08-29 da `20260821_...` dan `20260821010000_...` ga qayta
      // nomlandi: `schema_migrations.version` PRIMARY KEY bo'lgani uchun bir
      // kunda bir necha migratsiya bo'lsa 8 xonali prefiks to'qnashadi
      // (o'lchangan: 9 fayl 4 ta takrorlanuvchi prefiksda). 14 xonali
      // `YYYYMMDDHHMMSS` nisbiy tartibni saqlaydi.
      final sql = File('supabase/migrations/'
              '20260821010000_expert_verification_and_privacy.sql')
          .readAsStringSync();
      final viewStart = sql.indexOf('public_expert_profiles_view');
      expect(viewStart, greaterThan(-1));
      // View ta'rifi tugashigacha bo'lgan bo'lakni olamiz.
      final tail = sql.substring(viewStart);
      final viewBody = tail.substring(0, tail.indexOf(';'));
      expect(viewBody.contains('license_document_url'), isFalse,
          reason: 'ochiq katalog view\'i PII hujjat havolasini tarqatayapti');
    });
  });

  group('4. RAD ETISHNING OQIBATI UI\'da AYTILADI', () {
    test('ikki ARB ham `moderationRejectConsequence` ni saqlaydi', () {
      for (final locale in const ['uz', 'en']) {
        final arb = File('lib/l10n/arb/app_$locale.arb').readAsStringSync();
        expect(arb.contains('"moderationRejectConsequence"'), isTrue,
            reason: '$locale: rad etishning oqibati aytilmaydi');
        // ESKI kalit QAYTMASLIGI kerak: uning matni "bazada rad etilgan
        // holati yo'q" deb aytardi va bu 2026-08-29 dan keyin YOLG'ON.
        expect(arb.contains('"moderationRejectKeepsPending"'), isFalse,
            reason: '$locale: eski (endi yolg\'on) matn qaytib keldi');
      }
    });

    test('rad etish DIALOGI shu izohni ko\'rsatadi', () {
      final src = File('lib/features/legal_experts/presentation/pages/'
              'expert_moderation_page.dart')
          .readAsStringSync();
      // `l10n.` PREFIKSI bilan qidiriladi: fayl boshidagi izohda kalit nomi
      // matn sifatida ham uchraydi, u esa `if (!approve)` dan OLDIN.
      final at = src.indexOf('l10n.moderationRejectConsequence');
      expect(at, greaterThan(-1), reason: 'kalit UI\'da ishlatilmayapti');
      final before = src.substring(0, at);
      expect(before.contains('if (!approve)'), isTrue,
          reason: 'izoh tasdiqlash dialogida ham chiqib ketmasligi kerak');
    });

    test('ro\'yxat eskirganini aytadigan matn ham bor va ISHLATILADI', () {
      final src = File('lib/features/legal_experts/presentation/pages/'
              'expert_moderation_page.dart')
          .readAsStringSync();
      expect(src.contains('moderationListStale'), isTrue);
      expect(src.contains('listRefreshed'), isTrue,
          reason: 'eskirgan ro\'yxat holati SnackBar\'da farqlanmayapti');
    });

    test('kutayotganlar so\'rovi IKKI ustun bo\'yicha filtrlaydi', () {
      // Bu qulf serverdagi partial index'ga mos: `WHERE verified_at IS NULL
      // AND rejected_at IS NULL`. `rejected_at` filtri tushib qolsa, rad
      // etilgan ariza ro'yxatga QAYTIB tushadi va moderator ayni qarorni
      // qayta-qayta bosadi — ya'ni tuzatilgan T-3 defekti klient tomonidan
      // tiklanadi.
      final src = File('lib/features/legal_experts/data/datasources/'
              'legal_experts_remote_datasource.dart')
          .readAsStringSync();
      expect(src.contains("isFilter('verified_at', null)"), isTrue);
      expect(src.contains("isFilter('rejected_at', null)"), isTrue,
          reason: 'rad etilgan arizalar kutayotganlar ro\'yxatiga qaytadi');
    });
  });

  group('5. ROL BEKOR QILINGANI SERVERDAN OLINADI', () {
    test('`role_reverted: true` holatga o\'tadi', () async {
      final repo = _FakeRepo(
        pendingQueue: [
          const Right([_appA, _appB]),
          const Right([_appB]),
        ],
        verifyResult: const Right<Failure, Map<String, dynamic>>(
          <String, dynamic>{
            'success': true,
            'status': 'rejected',
            'role_reverted': true,
            'previous_role': 'verified_expert',
          },
        ),
      );
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(const ModerateApplicationEvent(
          userId: 'user-a', approve: false));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionDone && s.roleReverted == true)),
      );
    });

    test('maydon YO\'Q bo\'lsa KLIENT O\'ZI to\'qimaydi', () async {
      // Default javobda `role_reverted` YO'Q. Agar klient bu qarorni o'zi
      // hisoblasa ("rad etildi -> demak rol bekor qilindi"), oddiy `citizen`
      // arizachi rad etilganda ham "Advokat maqomi bekor qilindi" deb
      // yozardi — YOLG'ON. Belgi FAQAT serverdan keladi (§14).
      final repo = _FakeRepo(pendingQueue: [
        const Right([_appA, _appB]),
        const Right([_appB]),
      ]);
      final bloc = _blocFor(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadPendingApplicationsEvent());
      await expectLater(
          bloc.stream, emitsThrough(isA<ExpertModerationLoaded>()));

      bloc.add(const ModerateApplicationEvent(
          userId: 'user-a', approve: false));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<ExpertModerationState>((s) =>
            s is ExpertModerationActionDone && s.roleReverted == false)),
      );
    });

    test('ikki ARB ham `moderationRoleReverted` ni saqlaydi', () {
      for (final locale in const ['uz', 'en']) {
        final arb = File('lib/l10n/arb/app_$locale.arb').readAsStringSync();
        expect(arb.contains('"moderationRoleReverted"'), isTrue,
            reason: '$locale: rol bekor qilingani aytilmaydi');
      }
    });

    test('SnackBar `roleReverted` ni O\'QIYDI', () {
      final src = File('lib/features/legal_experts/presentation/pages/'
              'expert_moderation_page.dart')
          .readAsStringSync();
      expect(src.contains('state.roleReverted'), isTrue,
          reason: 'server aytgan oqibat UI\'ga chiqmayapti');
      expect(src.contains('l10n.moderationRoleReverted'), isTrue);
    });
  });
}
