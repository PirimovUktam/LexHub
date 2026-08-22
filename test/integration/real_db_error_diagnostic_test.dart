import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealHttpOverrides extends HttpOverrides {}

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
      } catch (_) {}
    }
  });

  test('Diagnose exact Supabase Auth signUp failure variations', () async {
    final client = Supabase.instance.client;
    final now = DateTime.now().millisecondsSinceEpoch;

    stdout.writeln('=== TEST 1: signUp WITHOUT data payload ===');
    try {
      final res1 = await client.auth.signUp(
        email: 'test_nodata_$now@lexhub.uz',
        password: 'Password123!',
      );
      stdout.writeln('TEST 1 SUCCESS: user=${res1.user?.id}, session=${res1.session != null}');
    } catch (e) {
      stdout.writeln('TEST 1 ERROR: $e');
    }

    stdout.writeln('=== TEST 2: signUp WITH full_name only ===');
    try {
      final res2 = await client.auth.signUp(
        email: 'test_nameonly_$now@lexhub.uz',
        password: 'Password123!',
        data: {'full_name': 'Test Name Only'},
      );
      stdout.writeln('TEST 2 SUCCESS: user=${res2.user?.id}, session=${res2.session != null}');
    } catch (e) {
      stdout.writeln('TEST 2 ERROR: $e');
    }

    stdout.writeln('=== TEST 3: signUp WITH full_name and role="citizen" ===');
    try {
      final res3 = await client.auth.signUp(
        email: 'test_withrole_$now@lexhub.uz',
        password: 'Password123!',
        data: {
          'full_name': 'Test Citizen',
          'role': 'citizen',
        },
      );
      stdout.writeln('TEST 3 SUCCESS: user=${res3.user?.id}, session=${res3.session != null}');
    } catch (e) {
      stdout.writeln('TEST 3 ERROR: $e');
    }
  });
}
