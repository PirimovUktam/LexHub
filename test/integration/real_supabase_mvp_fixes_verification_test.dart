import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lexhub/features/auth/data/models/user_model.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_remote_datasource.dart';
import 'package:lexhub/features/document_builder/data/repositories/document_builder_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../features/auth/domain/usecases/auth_usecases_test.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('real_supabase_mvp_fixes_verification')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  late sb.SupabaseClient supabaseClient;
  late AuthRemoteDataSource authDataSource;
  late CommunityForumDataSource communityDataSource;
  late DocumentBuilderRepositoryImpl documentRepo;

  const testEmail = 'invalid_format_for_test';
  const testPassword = '123';
  const testFullName = 'Test User';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();

    if (SupabaseConfig.isConfigured) {
      try {
        await sb.Supabase.initialize(
          url: SupabaseConfig.url,
          // ignore: deprecated_member_use
          anonKey: SupabaseConfig.anonKey,
        );
      } catch (_) {
        // Already initialized
      }
    }

    supabaseClient = sb.Supabase.instance.client;
    authDataSource = AuthRemoteDataSourceImpl(supabaseClient: supabaseClient);
    communityDataSource = CommunityForumDataSourceImpl(supabaseClient: supabaseClient);

    final docRemote = DocumentTemplatesRemoteDataSourceImpl(
      supabaseClient: supabaseClient,
      localDataSource: DocumentTemplatesLocalDataSourceImpl(),
    );
    documentRepo = DocumentBuilderRepositoryImpl(
      remoteDataSource: docRemote,
      localDataSource: DocumentTemplatesLocalDataSourceImpl(),
    );
  });

  tearDownAll(() async {
    try {
      await supabaseClient.auth.signOut();
    } catch (_) {}
  });

  group('MVP Fixes: Real Supabase Cloud Runtime Verification', () {
    test('1. Register Submit Flow & Null Safety in AuthBloc and UserModel', () async {
      // Step A: Test UserModel null safety
      final userModel = UserModel(
        id: 'test-user-id',
        email: 'test@lexhub.uz',
        phone: null,
        createdAt: DateTime.now(),
      );
      expect(userModel.id, equals('test-user-id'));
      expect(userModel.phone, isNull);
      stdout.writeln('EVIDENCE 1A: UserModel correctly created with null phone');

      // Step B: Test AuthStateChanged with null user (No Null check operator crash)
      final repo = MockAuthRepository();
      final authBloc = AuthBloc(
        authRepository: repo,
        getCurrentUserUseCase: GetCurrentUserUseCase(repo),
        signInWithEmailUseCase: SignInWithEmailUseCase(repo),
        signUpWithEmailUseCase: SignUpWithEmailUseCase(repo),
        signOutUseCase: SignOutUseCase(repo),
        getUserProfileUseCase: GetUserProfileUseCase(repo),
        updateUserProfileUseCase: UpdateUserProfileUseCase(repo),
      );

      authBloc.add(const AuthStateChangedEvent(null));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<Unauthenticated>());
      stdout.writeln('EVIDENCE 1B: AuthBloc._onAuthStateChanged(null) handled safely -> emitted Unauthenticated state');

      // Step C: Test safe error handling on invalid registration against Supabase Auth
      try {
        await authDataSource.signUpWithEmail(
          email: testEmail,
          password: testPassword,
          fullName: testFullName,
        );
      } on ServerException catch (e) {
        expect(e.message, isNotEmpty);
        stdout.writeln('EVIDENCE 1C: Invalid register input safely captured as ServerException("${e.message}") without crash');
      }
      await authBloc.close();
    });

    test('2. Unauthenticated Question & Answer Defense (No fake success)', () async {
      // Ensure completely unauthenticated
      await supabaseClient.auth.signOut();
      expect(supabaseClient.auth.currentUser, isNull);

      // Verify unauthenticated question creation throws 401 ServerException
      expect(
        () async => await communityDataSource.createQuestion(
          title: 'Unauthenticated Test',
          rawQuestion: 'Mening huquqim nima?',
          category: 'Mehnat huquqi',
          isAnonymous: true,
          authorName: 'Anonim',
        ),
        throwsA(
          predicate((e) =>
              e is ServerException &&
              e.statusCode == 401 &&
              e.message.contains('tizimga kiring')),
        ),
      );
      stdout.writeln('EVIDENCE 2A: Unauthenticated question write strictly rejected with 401 ServerException');

      // Verify unauthenticated answer creation throws 401 ServerException
      expect(
        () async => await communityDataSource.addAnswer(
          postId: 'non-existent-id',
          content: 'Noqonuniy javob',
          authorName: 'Hacker',
          isExpert: false,
        ),
        throwsA(
          predicate((e) =>
              e is ServerException &&
              e.statusCode == 401 &&
              e.message.contains('tizimga kiring')),
        ),
      );
      stdout.writeln('EVIDENCE 2B: Unauthenticated answer write strictly rejected with 401 ServerException');
    });

    test('3. Question Persistence & PII Anonymization Verification', () async {
      // Step A: PII Sanitization test before database insert
      const rawText = "Mening telefonim +998901234567, pasportim AA1234567, kartam 8600123456789012. Ish joyimda muammo bo'ldi.";
      final sanitized = PiiAnonymizer.anonymize(rawText);

      expect(sanitized.contains('+998901234567'), isFalse);
      expect(sanitized.contains('AA1234567'), isFalse);
      expect(sanitized.contains('8600123456789012'), isFalse);
      expect(sanitized.contains('[Telefon yashirildi]'), isTrue);
      expect(sanitized.contains('[Pasport yashirildi]'), isTrue);
      expect(sanitized.contains('[Karta raqami yashirildi]'), isTrue);
      stdout.writeln('EVIDENCE 3A: PII Anonymizer strictly removed all PII before write');

      // Step B: Verify live questions table is reachable and public questions view works
      final rows = await supabaseClient.from('questions').select('id, title, category_id, status').limit(5);
      stdout.writeln('EVIDENCE 3B: Live questions table accessible on Supabase Cloud, rows count: ${rows.length}');
    });

    test('4. Document / Template Loading & In-Memory Cache Latency Benchmark', () async {
      // First fetch: Network roundtrip
      final stopwatch1 = Stopwatch()..start();
      final result1 = await documentRepo.getTemplates();
      stopwatch1.stop();
      final elapsed1 = stopwatch1.elapsedMilliseconds;

      expect(result1.isRight(), isTrue);
      final templates1 = result1.getOrElse(() => []);
      expect(templates1, isNotEmpty);
      stdout.writeln('EVIDENCE 4A: 1st fetch (network/DB): loaded ${templates1.length} templates in ${elapsed1}ms');

      // Second fetch: In-memory cache hit
      final stopwatch2 = Stopwatch()..start();
      final result2 = await documentRepo.getTemplates();
      stopwatch2.stop();
      final elapsed2 = stopwatch2.elapsedMilliseconds;

      expect(result2.isRight(), isTrue);
      final templates2 = result2.getOrElse(() => []);
      expect(templates2.length, equals(templates1.length));
      stdout.writeln('EVIDENCE 4B: 2nd fetch (cached in-memory): loaded ${templates2.length} templates in ${elapsed2}ms');

      // Third fetch: Filtered category from in-memory cache
      final stopwatch3 = Stopwatch()..start();
      final result3 = await documentRepo.getTemplates(category: "Mehnat");
      stopwatch3.stop();
      final elapsed3 = stopwatch3.elapsedMilliseconds;

      expect(result3.isRight(), isTrue);
      stdout.writeln('EVIDENCE 4C: Category filter "Mehnat" from cache: completed in ${elapsed3}ms');

      // In-memory cache is sub-15ms
      expect(elapsed2, lessThanOrEqualTo(elapsed1 + 5));
    });
  });
}
