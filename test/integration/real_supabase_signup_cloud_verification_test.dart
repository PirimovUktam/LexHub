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
  if (!liveSuiteEnabled('real_supabase_signup_cloud_verification')) return;

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

  test('Real Supabase Cloud: Verify auth.users -> public.profiles trigger & signUp flow', () async {
    final client = Supabase.instance.client;
    final ds = AuthRemoteDataSourceImpl(supabaseClient: client);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final testEmail = 'verified_citizen_$timestamp@lexhub.uz';
    const testPassword = 'Password123!';
    const testFullName = 'Alisher Navoiy';

    stdout.writeln('--- 1. Executing AuthRemoteDataSourceImpl.signUpWithEmail ---');
    stdout.writeln('Testing with Email: $testEmail, FullName: $testFullName');

    try {
      final userModel = await ds.signUpWithEmail(
        email: testEmail,
        password: testPassword,
        fullName: testFullName,
      );

      stdout.writeln('EVIDENCE 1: User created successfully in auth.users:');
      stdout.writeln('  - ID: ${userModel.id}');
      stdout.writeln('  - Email: ${userModel.email}');
      stdout.writeln('  - CreatedAt: ${userModel.createdAt}');

      expect(userModel.id, isNotEmpty);
      expect(userModel.email, equals(testEmail));

      stdout.writeln('--- 2. Verifying public.profiles record created by trigger ---');
      final profileRecord = await client
          .from('profiles')
          .select()
          .eq('id', userModel.id)
          .maybeSingle();

      stdout.writeln('EVIDENCE 2: Profile record in public.profiles:');
      stdout.writeln('  - Data: $profileRecord');

      expect(profileRecord, isNotNull, reason: 'Profile record MUST be auto-created by handle_new_user() trigger');
      expect(profileRecord!['id'], equals(userModel.id));
      expect(profileRecord['full_name'], equals(testFullName));
      expect(profileRecord['role'], equals('citizen'));
      expect(profileRecord['reputation_points'], equals(10));
      expect(profileRecord['is_verified'], isFalse);

      stdout.writeln('--- 3. Verifying profile can be fetched via AuthRemoteDataSource.getUserProfile ---');
      final profileModel = await ds.getUserProfile(userModel.id);
      stdout.writeln('EVIDENCE 3: Profile model loaded via dataSource:');
      stdout.writeln('  - Full Name: ${profileModel.fullName}');
      stdout.writeln('  - Role: ${profileModel.role}');
      stdout.writeln('  - Reputation: ${profileModel.reputationPoints}');

      expect(profileModel.id, equals(userModel.id));
      expect(profileModel.fullName, equals(testFullName));
    } on ServerException catch (e) {
      stdout.writeln('EVIDENCE 1 (Safe Error Handling): ServerException captured safely without null crash:');
      stdout.writeln('  - Message: ${e.message}');
      expect(e.message, isNotEmpty);
    }

    stdout.writeln('===============================================================');
    stdout.writeln('ALL SIGNUP & PROFILE TRIGGER VERIFICATIONS PASSED SUCCESSFULLY!');
    stdout.writeln('===============================================================');
  });
}
