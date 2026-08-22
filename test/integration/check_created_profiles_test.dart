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

  test('Check if created users exist in public.profiles table', () async {
    final client = Supabase.instance.client;

    final usersToCheck = [
      '3fb1b5e0-5c73-4760-8024-6bc481dac7b8',
      '5bbcdb85-d3cf-4a3b-bd76-96f448e15b1f',
    ];

    for (final uid in usersToCheck) {
      final res = await client.from('profiles').select().eq('id', uid).maybeSingle();
      stdout.writeln('Profile for $uid: $res');
    }
  });
}
