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

  test('Diagnose Supabase Cloud profiles table and handle_new_user errors', () async {
    final client = Supabase.instance.client;

    stdout.writeln('--- 1. Testing SELECT from profiles ---');
    try {
      final res = await client.from('profiles').select().limit(5);
      stdout.writeln('Profiles query success, count: ${res.length}');
      if (res.isNotEmpty) {
        stdout.writeln('Sample profile: ${res.first}');
      }
    } catch (e) {
      stdout.writeln('Profiles query error: $e');
    }

    stdout.writeln('--- 2. Checking if profiles table accepts manual insert or upsert with anon key ---');
    try {
      final testId = '00000000-0000-0000-0000-000000000999';
      await client.from('profiles').insert({
        'id': testId,
        'full_name': 'Test Anon Insert',
        'role': 'citizen',
        'reputation_points': 10,
        'is_verified': false,
      });
      stdout.writeln('Anon insert to profiles succeeded');
    } catch (e) {
      stdout.writeln('Anon insert to profiles rejected/error: $e');
    }
  });
}
