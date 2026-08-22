import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('real_supabase_e2e')) return;

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

  group('Real Supabase Cloud E2E Integration Suite', () {
    test('1. Check Remote Database Schema Connectivity', () async {
      if (!SupabaseConfig.isConfigured) {
        stdout.writeln('SKIPPED: Real Supabase credentials not found in .env');
        return;
      }

      final client = Supabase.instance.client;

      // Verify connection to tables
      final profiles = await client.from('profiles').select().limit(5);
      stdout.writeln('PROFILES COUNT: ${profiles.length}');

      final questions = await client.from('questions').select().limit(5);
      stdout.writeln('QUESTIONS TABLE ACCESSIBLE: ${questions.length} rows');
    });

    test('2. Check Login with Invalid and Created Credentials', () async {
      if (!SupabaseConfig.isConfigured) {
        stdout.writeln('SKIPPED: Live E2E test requires .env configuration.');
        return;
      }

      final client = Supabase.instance.client;

      // Attempt login with non-existent user
      try {
        await client.auth.signInWithPassword(
          email: 'nonexistent_test_account@lexhub.uz',
          password: 'Password123!',
        );
        fail('Should fail on invalid credentials');
      } on AuthApiException catch (e) {
        stdout.writeln('PASS: Supabase Auth rejected invalid credentials with: ${e.message} (status: ${e.statusCode})');
        expect(e.statusCode.toString(), equals('400'));
      }
    });
  });
}
