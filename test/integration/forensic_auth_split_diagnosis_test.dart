import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/auth/data/models/user_model.dart';
import 'package:lexhub/features/auth/data/models/user_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('forensic_auth_split_diagnosis')) return;

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
      } catch (_) {}
    }
  });

  group('Forensic Authentication Diagnostic Suite', () {
    test('ISSUE 1 INVESTIGATION: Simulated Null-Check & Forced Unwrap Reproduction', () {
      stdout.writeln('=== FORENSIC TEST 1: How Null check operator used on a null value occurred ===');

      // Reproduction of legacy UserModel.fromSupabaseUser when email or createdAt is null
      final mockUserJsonWithNulls = <String, dynamic>{
        'id': 'test-uuid-1234',
        'email': null,
        'phone': null,
        'created_at': null,
        'app_metadata': {},
        'aud': 'authenticated',
      };

      try {
        final user = User.fromJson(mockUserJsonWithNulls);
        stdout.writeln('Gotrue User.fromJson parsed: id=${user?.id}, email=${user?.email}, createdAt=${user?.createdAt}');

        // Legacy vulnerable code simulation:
        // String forcedEmail = user!.email!; // <-- Throws Null check operator used on a null value
      } catch (e, stack) {
        stdout.writeln('SIMULATED LEGACY CRASH TRACE:');
        stdout.writeln('$e');
        stdout.writeln('$stack');
      }

      // Verify current UserModel handles null email and null createdAt safely
      final safeUser = UserModel.fromJson(mockUserJsonWithNulls);
      expect(safeUser.id, equals('test-uuid-1234'));
      expect(safeUser.email, equals(''));
      expect(safeUser.createdAt, isNull);
      stdout.writeln('VERIFIED: Current UserModel safely handles null email/dates without throwing Null check operator.');

      // Verify current UserProfileModel handles missing JSON fields safely
      final mockProfileJsonWithNulls = <String, dynamic>{
        'id': 'test-profile-1234',
        'full_name': null,
        'role': null,
        'reputation_points': null,
        'is_verified': null,
        'created_at': null,
        'updated_at': null,
      };
      final safeProfile = UserProfileModel.fromJson(mockProfileJsonWithNulls);
      expect(safeProfile.id, equals('test-profile-1234'));
      expect(safeProfile.fullName, equals('Foydalanuvchi'));
      expect(safeProfile.reputationPoints, equals(10));
      expect(safeProfile.isVerified, isFalse);
      stdout.writeln('VERIFIED: Current UserProfileModel safely handles null JSON fields without throwing Null check operator.');
    });

    test('ISSUE 2 INVESTIGATION: Real Supabase Cloud Auth API & Rate Limit Inspection', () async {
      stdout.writeln('=== FORENSIC TEST 2: Inspecting Real Cloud Auth API Status ===');
      final client = Supabase.instance.client;

      final randomEmail = 'diag_${DateTime.now().millisecondsSinceEpoch}@testdomain.uz';
      try {
        final res = await client.auth.signUp(
          email: randomEmail,
          password: 'Password123!',
          data: {'full_name': 'Diagnostic User'},
        );
        stdout.writeln('Cloud signUp result: user=${res.user?.id}, session=${res.session != null}');
      } on AuthApiException catch (e, stack) {
        stdout.writeln('Cloud AuthApiException captured: code=${e.code}, statusCode=${e.statusCode}, message=${e.message}');
        stdout.writeln('STACK TRACE:\n$stack');
      } catch (e, stack) {
        stdout.writeln('Cloud General Exception captured: $e');
        stdout.writeln('STACK TRACE:\n$stack');
      }
    });
  });
}
