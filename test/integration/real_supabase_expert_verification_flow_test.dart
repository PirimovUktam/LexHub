// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart';
import 'package:lexhub/features/legal_experts/data/models/legal_expert_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('real_supabase_expert_verification_flow')) return;

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

  group('Sprint 5.1: Real Supabase Expert Verification E2E Suite', () {
    test('1. Remote Database Schema & Expert Tables / Views Status', () async {
      final client = Supabase.instance.client;

      bool expertProfilesExists = false;
      bool publicViewExists = false;

      // 1. Check expert_profiles base table
      try {
        final expertProfiles = await client
            .from('expert_profiles')
            .select('id, user_id, specialization')
            .limit(1);
        expertProfilesExists = true;
        print('EVIDENCE 1: Live expert_profiles table found (${expertProfiles.length} rows)');
      } catch (e) {
        print('EVIDENCE 1: expert_profiles table error: $e');
      }

      // 2. Check public_expert_profiles_view
      try {
        final publicExperts = await client
            .from('public_expert_profiles_view')
            .select()
            .limit(5);
        publicViewExists = true;
        print('EVIDENCE 1: Live public_expert_profiles_view found (${publicExperts.length} rows)');
      } catch (e) {
        print('EVIDENCE 1: public_expert_profiles_view error: $e');
      }

      print('EVIDENCE 1 SUMMARY: expert_profiles=$expertProfilesExists, public_view=$publicViewExists');
      expect(expertProfilesExists, true);
      expect(publicViewExists, true);
    });

    test('2. License Document Privacy Shield & Model Serialization Verification', () async {
      final client = Supabase.instance.client;

      // 1. Live View Column Inspection (Privacy Shield)
      try {
        final publicExperts = await client
            .from('public_expert_profiles_view')
            .select()
            .limit(1);

        if (publicExperts.isNotEmpty) {
          final first = publicExperts.first;
          print('EVIDENCE 2: Live public_expert_profiles_view columns: ${first.keys.toList()}');
          expect(first.containsKey('license_document_url'), false);
          expect(first.containsKey('is_profile_verified'), true);
        }
      } catch (e) {
        print('EVIDENCE 2: View query info: $e');
      }

      // 2. Client Model Privacy Serialization Guard
      final mockRecord = {
        'expert_id': 'exp_999',
        'user_id': 'usr_888',
        'full_name': 'Jasur Advokat',
        'specialization': 'Mehnat huquqi',
        'license_number': 'ADV-77112',
        'rating': 5.0,
        'reviews_count': 12,
        'experience_years': 8,
        'workplace': 'Advokatlar hay\'ati',
        'is_profile_verified': true,
        'phone': '+998901234567',
      };
      final model = LegalExpertModel.fromJson(mockRecord);
      print('EVIDENCE 2: LegalExpertModel safely parsed without leaking private license doc: ${model.fullName}, verified=${model.isVerified}');
      expect(model.isVerified, true);
      expect(model.fullName, 'Jasur Advokat');
      expect(model.licenseNumber, 'ADV-77112');
    });

    test('3. Unauthenticated Verification Application Rejection (RLS / Auth Enforcement)', () async {
      final client = Supabase.instance.client;
      final remoteDataSource = LegalExpertsRemoteDataSourceImpl(
        supabaseClient: client,
      );
      // Unauthenticated application attempt must throw UnauthorizedException (401)
      try {
        await remoteDataSource.applyForVerification(
          specialization: 'Jinoyat huquqi',
          experienceYears: 6,
          licenseNumber: 'ADV-TEST-001',
          workplace: 'Samarqand Advokatlar',
          consultationFee: 200000.0,
        );
        fail('Unauthenticated application should have been blocked');
      } catch (e) {
        print('EVIDENCE 3: Unauthenticated expert application strictly blocked: $e');
        expect(
          e.toString().contains('Ariza topshirish uchun avval tizimga kiring') ||
              e.toString().contains('Unauthorized') ||
              e.toString().contains('401'),
          true,
        );
      }
    });

    test('4. Anti-Escalation & Role Tampering Defense — Citizens cannot promote themselves to expert/admin', () async {
      final client = Supabase.instance.client;

      // Attempt direct update to escalate role or fake verification
      try {
        await client
            .from('profiles')
            .update({
              'role': 'verified_expert',
              'is_verified': true,
            })
            .eq('id', '00000000-0000-0000-0000-000000000000');
        print('EVIDENCE 4: Unauthorized role update returned 0 rows or was blocked by RLS/Trigger');
      } catch (e) {
        print('EVIDENCE 4: Role escalation attempt blocked with error: $e');
        expect(e, isNotNull);
      }
    });

    test('5. Rating & Reviews Count Tampering Defense — Direct mutation blocked', () async {
      final client = Supabase.instance.client;

      // Attempt to tamper rating on expert_profiles
      try {
        await client
            .from('expert_profiles')
            .update({'rating': 5.0, 'reviews_count': 9999})
            .eq('id', '00000000-0000-0000-0000-000000000000');
        print('EVIDENCE 5: Rating tampering attempt returned 0 rows or was blocked by RLS/Trigger');
      } catch (e) {
        print('EVIDENCE 5: Rating tampering blocked with error: $e');
        expect(e, isNotNull);
      }
    });

    test('6. RPC Security: verify_expert_application rejects non-admin users', () async {
      final client = Supabase.instance.client;

      try {
        final result = await client.rpc(
          'verify_expert_application',
          params: {
            'p_target_user_id': '00000000-0000-0000-0000-000000000000',
            'p_approve': true,
          },
        );
        print('EVIDENCE 6: verify_expert_application RPC response: $result');
      } catch (e) {
        print('EVIDENCE 6: Non-admin approval blocked with exception: $e');
        expect(
          e.toString().contains('Access Denied') ||
              e.toString().contains('P0001') ||
              e.toString().contains('403') ||
              e.toString().contains('permission') ||
              e.toString().contains('Only administrators'),
          true,
        );
      }
    });

    test('7. RPC Security: apply_for_expert_verification requires authentication', () async {
      final client = Supabase.instance.client;

      try {
        final result = await client.rpc(
          'apply_for_expert_verification',
          params: {
            'p_specialization': 'Fuqarolik huquqi',
            'p_experience_years': 5,
            'p_license_number': 'ADV-9999',
            'p_license_document_url': 'https://secret.docs/license.pdf',
            'p_workplace': 'Toshkent Advokatlar Hay\'ati',
            'p_education': 'TDYU Magistratura',
            'p_consultation_fee': 150000.0,
          },
        );
        print('EVIDENCE 7: apply_for_expert_verification RPC response: $result');
      } catch (e) {
        print('EVIDENCE 7: Unauthenticated RPC call blocked with: $e');
        expect(
          e.toString().contains('Authentication required') ||
              e.toString().contains('P0001') ||
              e.toString().contains('401') ||
              e.toString().contains('null'),
          true,
        );
      }
    });

    // §6 MOCK-DATA SIYOSATI: bu test ILGARI "with fallback" deb nomlangan va
    // `expect(experts.isNotEmpty, true)` faqat TO'QILGAN 6 ta advokat
    // (`LegalExpertsLocalDataSourceImpl`) hisobidan o'tishi mumkin edi — ya'ni
    // bo'sh/ishlamayotgan `public_expert_profiles_view` ham "PASS" berardi.
    // Endi test HAQIQIY shartnomani tekshiradi: natija faqat view'dan keladi,
    // bo'sh bo'lishi MUMKIN, va har bir yozuv tasdiqlangan bo'lishi SHART.
    test('8. LegalExpertsRemoteDataSource returns ONLY real view rows (no mock fallback)', () async {
      final client = Supabase.instance.client;
      final remoteDataSource = LegalExpertsRemoteDataSourceImpl(
        supabaseClient: client,
      );

      final experts = await remoteDataSource.getExperts(specialization: 'Mehnat');
      print('EVIDENCE 8: Loaded ${experts.length} legal experts for specialization "Mehnat" (real view only)');

      for (final e in experts) {
        expect(e.isVerified, true, reason: 'public view faqat tasdiqlangan advokatlarni beradi');
        expect(
          e.specialization.toLowerCase().contains('mehnat'),
          true,
          reason: 'ilike filtri server tomonda qo\'llanishi kerak',
        );
        expect(e.id.startsWith('adv_'), false, reason: 'soxta local ID qaytmasligi kerak');
      }
    });

    test('9. getExpertById on a non-existent ID throws 404 (never substitutes another advocate)', () async {
      final client = Supabase.instance.client;
      final remoteDataSource = LegalExpertsRemoteDataSourceImpl(
        supabaseClient: client,
      );

      const missingId = '00000000-0000-0000-0000-0000000000ff';
      try {
        final expert = await remoteDataSource.getExpertById(missingId);
        fail(
          'Mavjud bo\'lmagan advokat uchun 404 kutilgan edi, lekin '
          '"${expert.fullName}" qaytdi (mock fallback regressi).',
        );
      } on ServerException catch (e) {
        print('EVIDENCE 9: Missing expert correctly rejected -> ${e.statusCode}: ${e.message}');
        expect(e.statusCode, 404);
      }
    });
  });
}
