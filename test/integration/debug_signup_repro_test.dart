import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('debug_signup_repro')) return;

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

  test('Reproduce exact Register / SignUp flow with stack trace', () async {
    final client = Supabase.instance.client;
    final ds = AuthRemoteDataSourceImpl(supabaseClient: client);

    final testEmail = 'oktamtatu_${DateTime.now().millisecondsSinceEpoch}@gmail.com';
    const testPassword = 'Password123!';
    const testFullName = 'jxbdndn';

    stdout.writeln('--- STEP 1: Calling signUp directly on SupabaseClient ---');
    try {
      final res = await client.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': testFullName,
          'role': 'citizen',
        },
      );
      stdout.writeln('Direct client.auth.signUp SUCCESS: user=${res.user?.id}, session=${res.session != null}');
    } catch (e, stack) {
      stdout.writeln('Direct client.auth.signUp ERROR: $e');
      stdout.writeln('STACK TRACE:\n$stack');
    }

    stdout.writeln('--- STEP 2: Calling ds.signUpWithEmail ---');
    try {
      final userModel = await ds.signUpWithEmail(
        email: testEmail,
        password: testPassword,
        fullName: testFullName,
      );
      stdout.writeln('ds.signUpWithEmail SUCCESS: userModel=${userModel.id}, email=${userModel.email}');
    } catch (e, stack) {
      stdout.writeln('ds.signUpWithEmail ERROR: $e');
      stdout.writeln('STACK TRACE:\n$stack');
    }
  });
}
