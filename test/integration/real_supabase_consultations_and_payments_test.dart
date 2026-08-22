// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/consultations/data/datasources/consultation_remote_datasource.dart';
import 'package:lexhub/features/consultations/data/repositories/consultation_repository_impl.dart';
import 'package:lexhub/features/consultations/domain/usecases/book_consultation_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/process_payment_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// §0 / §14 — CLAIM ≠ EVIDENCE. BU FAYL QAYTA YOZILDI.
///
/// Ilgari 2-, 5- va 6-testlar `ConsultationLocalDataSourceImpl()` (mock)
/// ustida ishlagan va TO'QILGAN konstantalarni tekshirgan:
/// `priceAmountTiyin == 20000000`, `commissionAmountUzs == 20000.0`,
/// `response['status'] == 'paid'`, `refund_percent == 100`. Ya'ni ular
/// "Real Supabase" nomi bilan turib, BIRORTA HAM server kodini
/// bajarmagan — bu FALSE PASS edi. Mock datasource o'chirildi, endi
/// testlar REAL client bilan ishlaydi va faqat HAQIQIY server javobini
/// tasdiqlaydi.
///
/// Bu testlar HECH NARSANI O'ZGARTIRMAYDI (no mutation): barcha yozuv
/// yo'llari mavjud bo'lmagan UUID va sessiyasiz (anon) client bilan
/// chaqiriladi, shuning uchun ular faqat RAD ETILISHI kutiladi.
class RealHttpOverrides extends HttpOverrides {}

/// Mavjud bo'lmagan, lekin UUID FORMATIDA to'g'ri identifikator.
///
/// Format muhim: `book_consultation(p_expert_id uuid)` — noto'g'ri formatli
/// satr funksiya tanasiga yetib bormasdan, `uuid` cast'ida yiqiladi va test
/// nimani isbotlaganini aniqlab bo'lmaydi.
const String _absentUuid = '00000000-0000-0000-0000-000000000001';

/// Real UUID'lar logga TO'LIQ chiqmaydi (PII/ID gigienasi).
String _redact(String id) =>
    id.length <= 12 ? id : '${id.substring(0, 8)}…${id.substring(id.length - 4)}';

/// Real Supabase client bilan repository. Mock fallback YO'Q (§6).
ConsultationRepositoryImpl _realRepository() => ConsultationRepositoryImpl(
      remoteDataSource: ConsultationRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          // ignore: deprecated_member_use
          anonKey: SupabaseConfig.anonKey,
        );
      } catch (_) {
        // Already initialized
      }
    }
  });

  group('Sprint 9.1: Real Supabase Consultations, Payments & Security Suite', () {
    test('1. Real Cloud: get_expert_available_slots RPC', () async {
      if (!SupabaseConfig.isConfigured) {
        markTestSkipped('BLOCKED: env/prod.json defines berilmagan.');
        return;
      }
      final client = Supabase.instance.client;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateStr =
          "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";

      final expertRows = await client
          .from('expert_profiles')
          .select('id, user_id, specialization, consultation_fee, verified_at')
          .limit(1);

      print('EVIDENCE 1.1: expert_profiles qatorlari: ${expertRows.length}');
      var expertId = _absentUuid;
      if (expertRows.isNotEmpty) {
        expertId = expertRows.first['id'] as String;
        print('  - Expert ID (redacted): ${_redact(expertId)}'
            ', fee: ${expertRows.first['consultation_fee']}');
      }

      final rpcResult = await client.rpc(
        'get_expert_available_slots',
        params: {'p_expert_id': expertId, 'p_date': dateStr},
      );
      print('EVIDENCE 1.2: RPC qaytardi: ${(rpcResult as List).length} slot');
      expect(rpcResult, isA<List>());
      if (rpcResult.isNotEmpty) {
        final first = rpcResult.first as Map<String, dynamic>;
        print('  - slot_time: ${first['slot_time']}'
            ', is_available: ${first['is_available']}'
            ', price_amount_uzs: ${first['price_amount_uzs']}');
        // Server javobining SHAKLI (§6 parser kontrakti) tekshiriladi.
        expect(first.containsKey('slot_time'), true);
        expect(first.containsKey('is_available'), true);
        expect(first.containsKey('price_amount_uzs'), true);
      }
    });

    /// §6 REGRESSION GUARD: sessiyasiz bron MOCK bilan "muvaffaqiyat"
    /// bo'lmasligi kerak.
    ///
    /// Ilgari bu test mock datasource'ning `20000000 tiyin` va `20000.0`
    /// komissiyasini tekshirardi — server kodi ishlamagan. Endi: real client,
    /// sessiya YO'Q -> `book_consultation` `Authentication required` bilan
    /// yiqiladi -> repository `Left(Failure)` qaytaradi. `Right` kelishi =
    /// mock fallback qaytgan degani (P0 regressiya).
    test('2. Booking without session -> Left(Failure), mock fallback yo\'q',
        () async {
      if (!SupabaseConfig.isConfigured) {
        markTestSkipped('BLOCKED: env/prod.json defines berilmagan.');
        return;
      }
      expect(Supabase.instance.client.auth.currentUser, isNull,
          reason: 'Bu test ataylab SESSIYASIZ bajariladi.');

      final useCase = BookConsultationUseCase(_realRepository());
      final result = await useCase(
        BookConsultationParams(
          expertId: _absentUuid,
          scheduledAt: DateTime.now().add(const Duration(days: 2, hours: 14)),
          meetingType: 'online',
          notes: 'Mehnat huquqi yuzasidan murojaat',
          provider: 'payme',
        ),
      );

      expect(result.isLeft(), true,
          reason: "Sessiyasiz bron QABUL QILINMASLIGI kerak (§6/§8).");
      result.fold(
        (failure) => print('EVIDENCE 2: real server rad etdi -> '
            '${failure.runtimeType}: ${failure.message}'),
        (_) => fail('Sessiyasiz bron "muvaffaqiyat" qaytardi — '
            'mock fallback tirilgan.'),
      );
    });

    test('3. Real Cloud RPC Security: book_consultation autentifikatsiya talab qiladi',
        () async {
      if (!SupabaseConfig.isConfigured) {
        markTestSkipped('BLOCKED: env/prod.json defines berilmagan.');
        return;
      }
      final client = Supabase.instance.client;
      final slotTime = DateTime.now()
          .add(const Duration(days: 2, hours: 11))
          .toIso8601String();

      try {
        await client.rpc(
          'book_consultation',
          params: {
            'p_expert_id': _absentUuid,
            'p_scheduled_at': slotTime,
            'p_meeting_type': 'online',
            'p_notes': 'Hujum testi',
            'p_provider': 'payme',
          },
        );
        fail('Unauthenticated booking should have been blocked');
      } catch (e) {
        if (e is TestFailure) rethrow;
        print('EVIDENCE 3: RPC sessiyasiz bloklandi: $e');
        expect(
          e.toString().contains('Authentication required') ||
              e.toString().contains('401') ||
              e.toString().contains('P0001'),
          true,
        );
      }
    });

    test('4. Security Vector: to\'g\'ridan-to\'g\'ri UPDATE/INSERT RLS bilan bloklangan',
        () async {
      if (!SupabaseConfig.isConfigured) {
        markTestSkipped('BLOCKED: env/prod.json defines berilmagan.');
        return;
      }
      final client = Supabase.instance.client;

      // Hujumchi to'lov holatini to'g'ridan-to'g'ri 'paid' qilishga urinadi.
      try {
        final res = await client
            .from('consultations')
            .update({'payment_status': 'paid', 'status': 'confirmed'})
            .eq('id', _absentUuid)
            .select();

        print('EVIDENCE 4: to\'g\'ridan-to\'g\'ri UPDATE qatorlari: ${res.length}');
        expect(res.isEmpty, true);
      } catch (e) {
        print('EVIDENCE 4: UPDATE RLS bilan bloklandi: $e');
        expect(e, isNotNull);
      }

      // Hujumchi `payments` jadvaliga soxta qator qo'shishga urinadi.
      try {
        await client.from('payments').insert({
          'consultation_id': _absentUuid,
          'amount_tiyin': 1000,
          'status': 'paid',
          'idempotency_key': 'fake_hack_key',
        });
        fail('Direct payment insert should have been blocked by RLS');
      } catch (e) {
        if (e is TestFailure) rethrow;
        print('EVIDENCE 4.2: INSERT RLS bilan bloklandi: $e');
        expect(e, isNotNull);
      }
    });

    /// §3/§6 REGRESSION GUARD + `process_payment_webhook` EXECUTABILITY PROBE.
    ///
    /// Ilgari bu test mock datasource'ning `{'success': true, 'status':
    /// 'paid'}` javobini tekshirardi — ya'ni SOXTA to'lov capture'i "PASS"
    /// deb yozilardi. Endi: real client, MAVJUD BO'LMAGAN to'lov ID'si.
    /// Har qanday holatda natija `Left(Failure)` bo'lishi shart.
    ///
    /// Bu ayni paytda AUDIT PROBE: xato matni RPC'ning anon rol uchun
    /// bajarilishi mumkinligini ko'rsatadi ('Payment record not found' =>
    /// funksiya BAJARILDI, ya'ni caller authorization YO'Q; 'permission
    /// denied' => bajarilmaydi). Hech qanday yozuv o'zgarmaydi.
    test('5. process_payment_webhook: mavjud bo\'lmagan to\'lov -> Left(Failure)',
        () async {
      if (!SupabaseConfig.isConfigured) {
        markTestSkipped('BLOCKED: env/prod.json defines berilmagan.');
        return;
      }
      final useCase = ProcessPaymentUseCase(_realRepository());
      final result = await useCase(
        const ProcessPaymentParams(
          paymentId: _absentUuid,
          provider: 'payme',
          providerTransactionId: 'audit_probe_absent_payment',
          paidAmountTiyin: 20000000,
          status: 'paid',
        ),
      );

      expect(result.isLeft(), true,
          reason: "Mavjud bo'lmagan to'lov TASDIQLANMASLIGI kerak (§3).");
      result.fold(
        (failure) {
          final msg = failure.message;
          print('EVIDENCE 5: server rad etdi -> ${failure.runtimeType}: $msg');
          final executed = msg.contains('Payment record not found');
          final denied = msg.toLowerCase().contains('permission denied');
          print('  - RPC anon rol tomonidan BAJARILDIMI: '
              '${executed ? "HA (caller authorization YO'Q)" : denied ? "YO'Q (permission denied)" : "ANIQLANMADI"}');
        },
        (_) => fail("Mavjud bo'lmagan to'lov 'muvaffaqiyat' qaytardi — "
            'soxta capture tirilgan.'),
      );
    });

    /// §6 REGRESSION GUARD: bekor qilish 100% refund'ni O'YLAB TOPMASLIGI kerak.
    ///
    /// Ilgari mock `{'refund_percent': 100, 'refund_amount_uzs': 200000.0}`
    /// qaytarardi va test shuni "PASS" deb yozardi — foydalanuvchiga
    /// mavjud bo'lmagan to'liq qaytarish VA'DA qilinardi. Endi: real client,
    /// sessiya yo'q + mavjud bo'lmagan konsultatsiya -> `Left(Failure)`.
    test('6. cancel_consultation: sessiyasiz/mavjud bo\'lmagan yozuv -> Left(Failure)',
        () async {
      if (!SupabaseConfig.isConfigured) {
        markTestSkipped('BLOCKED: env/prod.json defines berilmagan.');
        return;
      }
      final result = await _realRepository().cancelConsultation(
        consultationId: _absentUuid,
        reason: "Rejalar o'zgarishi sababli",
      );

      expect(result.isLeft(), true,
          reason: 'Sessiyasiz bekor qilish QABUL QILINMASLIGI kerak (§8).');
      result.fold(
        (failure) => print('EVIDENCE 6: server rad etdi -> '
            '${failure.runtimeType}: ${failure.message}'),
        (res) => fail('Bekor qilish "muvaffaqiyat" qaytardi: $res'),
      );
    });

    /// §0/§14: bu test HECH NARSANI ISBOTLAMAYDI — u faqat integratsiya
    /// HOLATINI qayd etadi. Ilgari shu yerda "Backend Security Engine …
    /// FULLY IMPLEMENTED & ACTIVE" degan, birorta ham assertion bilan
    /// tasdiqlanmagan da'vo chop etilardi. Bu CLAIM ≠ EVIDENCE buzilishi.
    test('7. To\'lov gateway integratsiya holati (FAQAT QAYDNOMA, isbot emas)',
        () async {
      print('--- PAYMENT GATEWAY INTEGRATION STATUS (NOT VERIFIED) ---');
      print('  - Payme Merchant API: SIMULATED / IN DEVELOPMENT');
      print('  - Click Merchant API: SIMULATED / IN DEVELOPMENT');
      print('  - Uzum Bank Checkout: SIMULATED / IN DEVELOPMENT');
      print('  - Real merchant credential/webhook production\'da YO\'Q, '
          "shuning uchun uchidan-uchiga to'lov: NOT VERIFIED.");
      print('  - Backend RLS / amount verification / double-booking lock / '
          "idempotency: migration'da MAVJUD, lekin bu test ularni "
          'ISBOTLAMAYDI — 3-, 4-, 5-, 6-testlarga qara.');
    });
  });
}
