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

  test('Forensic Database & Schema Diagnostics on Supabase Cloud', () async {
    final client = Supabase.instance.client;

    stdout.writeln('=== 1. Checking Profiles Table Structure & Queries ===');
    try {
      final sample = await client.from('profiles').select().limit(1);
      stdout.writeln('Profiles query success. Rows: ${sample.length}');
      if (sample.isNotEmpty) {
        stdout.writeln('Sample Profile columns: ${sample.first.keys.toList()}');
      }
    } catch (e) {
      stdout.writeln('Profiles query error: $e');
    }

    stdout.writeln('=== 2. Checking Expert Profiles Table Structure ===');
    try {
      final sampleExperts = await client.from('expert_profiles').select().limit(1);
      stdout.writeln('Expert profiles query success. Rows: ${sampleExperts.length}');
      if (sampleExperts.isNotEmpty) {
        stdout.writeln('Sample Expert Profile columns: ${sampleExperts.first.keys.toList()}');
      }
    } catch (e) {
      stdout.writeln('Expert profiles query error: $e');
    }

    stdout.writeln('=== 3. Testing Direct Anonymous Signup / Auth Endpoint ===');
    final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
    final testEmail = 'forensic_check_$uniqueTimestamp@lexhubtest.com';
    const testPassword = 'Password123!';

    try {
      final authRes = await client.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Forensic Test User',
          'role': 'citizen',
        },
      );
      stdout.writeln('Direct signUp response: user=${authRes.user?.id}, email=${authRes.user?.email}, session=${authRes.session != null}');

      if (authRes.user != null) {
        final profileCheck = await client.from('profiles').select().eq('id', authRes.user!.id).maybeSingle();
        stdout.writeln('Auto-created Profile Record in DB: $profileCheck');
      }
    } on AuthApiException catch (e, stack) {
      stdout.writeln('AUTH API EXCEPTION:');
      stdout.writeln('  - Status Code: ${e.statusCode}');
      stdout.writeln('  - Error Code: ${e.code}');
      stdout.writeln('  - Message: ${e.message}');
      stdout.writeln('STACK: $stack');
    } on AuthException catch (e, stack) {
      stdout.writeln('AUTH EXCEPTION:');
      stdout.writeln('  - Status Code: ${e.statusCode}');
      stdout.writeln('  - Message: ${e.message}');
      stdout.writeln('STACK: $stack');
    } catch (e, stack) {
      stdout.writeln('GENERAL EXCEPTION: $e');
      stdout.writeln('STACK: $stack');
    }
  });
}
