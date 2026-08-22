import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('verify_rate_limit_error_mapping')) return;

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

  test('Real Rate Limit Handling Verification: No Null Check Crash, Clean Uzbek Message', () async {
    final client = Supabase.instance.client;
    final ds = AuthRemoteDataSourceImpl(supabaseClient: client);

    final testEmail = 'rate_check_${DateTime.now().millisecondsSinceEpoch}@lexhubtest.com';

    try {
      final user = await ds.signUpWithEmail(
        email: testEmail,
        password: 'Password123!',
        fullName: 'Test Citizen',
      );
      stdout.writeln('User created (Rate limit not hit): ${user.id}');
    } on ServerException catch (e) {
      stdout.writeln('=== EVIDENCE: ServerException Safely Intercepted ===');
      stdout.writeln('Captured message: "${e.message}"');
      expect(e.message, isNot(contains('Null check operator')));
      expect(e.message, isNot(contains('null')));
      expect(e.message, equals('Juda ko\'p urinish amalga oshirildi. Iltimos, bir necha daqiqadan so\'ng qayta urinib ko\'ring.'));
      stdout.writeln('CONFIRMED: Clean Uzbek Rate Limit message without any Null Check exception.');
    } catch (e, stack) {
      fail('Unexpected non-ServerException thrown: $e\n$stack');
    }
  });
}
