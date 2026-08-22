import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/data/repositories/community_forum_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('real_supabase_community_e2e')) return;

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

  group('Real Supabase Community Q&A E2E Suite', () {
    test('1. Verify questions and public_questions_view schema presence', () async {
      if (!SupabaseConfig.isConfigured) {
        stdout.writeln('SKIPPED: Real Supabase credentials not found in .env');
        return;
      }

      final client = Supabase.instance.client;
      final dataSource = CommunityForumDataSourceImpl(supabaseClient: client);

      final posts = await dataSource.getPosts();
      expect(posts, isNotNull);
      expect(posts.isNotEmpty, true);
      stdout.writeln('COMMUNITY POSTS LOADED: ${posts.length} items');
    });

    test('2. Verify Anonymous Privacy Masking Logic on Question Creation', () async {
      const rawText = "Mening pasportim AA 1234567, telefonim +998 90 123 45 67. Bank bilan muammo bo'ldi.";
      final anonymized = PiiAnonymizer.anonymize(rawText);

      expect(anonymized.contains('AA 1234567'), false);
      expect(anonymized.contains('+998 90 123 45 67'), false);
      expect(anonymized.contains('[Pasport yashirildi]'), true);
      expect(anonymized.contains('[Telefon yashirildi]'), true);
    });

    test('3. Repository returns failure when unauthenticated create is attempted', () async {
      if (!SupabaseConfig.isConfigured) {
        return;
      }

      final client = Supabase.instance.client;
      await client.auth.signOut();

      final dataSource = CommunityForumDataSourceImpl(supabaseClient: client);
      final repository = CommunityForumRepositoryImpl(dataSource: dataSource);

      final result = await repository.createQuestion(
        title: "Test savol",
        rawQuestion: "Test matn",
        category: "Mehnat huquqi",
        isAnonymous: true,
        authorName: "Anonim",
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          stdout.writeln('AUTH ENFORCEMENT PASSED: ${failure.message}');
          expect(failure.message.contains("tizimga kiring"), true);
        },
        (_) => fail('Should not allow unauthenticated question creation'),
      );
    });

    test('4. Repository returns failure when unauthenticated vote is attempted', () async {
      if (!SupabaseConfig.isConfigured) {
        return;
      }

      final client = Supabase.instance.client;
      await client.auth.signOut();

      final dataSource = CommunityForumDataSourceImpl(supabaseClient: client);
      final repository = CommunityForumRepositoryImpl(dataSource: dataSource);

      final result = await repository.votePost('00000000-0000-0000-0000-000000000000');
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          stdout.writeln('VOTE AUTH ENFORCEMENT PASSED: ${failure.message}');
          expect(failure.message.contains("tizimga kiring"), true);
        },
        (_) => fail('Should not allow unauthenticated voting'),
      );
    });
  });
}
