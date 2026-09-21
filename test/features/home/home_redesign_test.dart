import 'package:lexhub/core/storage/local_case_scope.dart';
// Home redesign regression scenarios, authored 2026-09-19.
// Covers lost routes/query payloads, loading/error/empty states, category
// filtering, and layout overflow after changing the presentation. The tests
// run real BLoCs with in-memory repositories; they do not prove production
// API behavior, device typography, pixel contrast, or deployment.
import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';
import 'package:lexhub/features/community_forum/domain/usecases/accept_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/add_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/create_community_question_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/get_community_posts_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_post_usecase.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_bloc.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/community_mini_card.dart';
import 'package:lexhub/features/emergency_rights/presentation/pages/emergency_rights_page.dart';
import 'package:lexhub/features/home/data/datasources/home_local_datasource.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/home/domain/repositories/home_repository.dart';
import 'package:lexhub/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:lexhub/features/home/presentation/bloc/home_bloc.dart';
import 'package:lexhub/features/home/presentation/pages/home_page.dart';
import 'package:lexhub/features/home/presentation/widgets/category_grid_widget.dart';
import 'package:lexhub/features/home/presentation/widgets/home_hero_card.dart';
import 'package:lexhub/features/home/presentation/widgets/language_quick_switch.dart';
import 'package:lexhub/features/home/presentation/widgets/quick_access_grid.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/features/search/domain/repositories/search_repository.dart';
import 'package:lexhub/features/search/domain/usecases/global_search_usecase.dart';
import 'package:lexhub/features/search/presentation/bloc/search_bloc.dart';
import 'package:lexhub/features/search/presentation/pages/search_page.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../support/l10n_test_app.dart';
import '../../support/locale_test_cubit.dart';

/// Only the repository boundary is substituted. Home filtering and query
/// handoff still execute the application's use cases and BLoCs.
class _Repositories
    implements
        HomeRepository,
        CommunityForumRepository,
        AuthRepository,
        SearchRepository {
  final local = HomeLocalDataSourceImpl();
  bool failHome = false;
  bool failCommunity = false;
  Completer<void>? homeGate;
  int homeLoads = 0;
  int communityLoads = 0;
  final searchQueries = <String>[];
  List<CommunityPost> posts = [
    CommunityPost(
      id: 'home-widget-question',
      title: 'Community fixture question',
      anonymizedQuestion: 'Community fixture question',
      category: 'Mehnat huquqi',
      aiSummary: '',
      answersCount: 7,
      createdAt: DateTime(2026, 9, 1),
    ),
  ];

  @override
  Stream<UserEntity?> get authStateChanges => const Stream.empty();

  @override
  Future<Either<Failure, List<LegalCategory>>> getCategories() async {
    homeLoads++;
    await homeGate?.future;
    if (failHome) return const Left(NetworkFailure());
    return Right(await local.getCategories());
  }

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> getSeedQuestions({
    String? categoryId,
  }) async =>
      Right(await local.getSeedQuestions(categoryId: categoryId));

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> searchSeedQuestions(
    String query,
  ) async =>
      Right(await local.searchSeedQuestions(query));

  @override
  Future<Either<Failure, List<CommunityPost>>> getPosts({
    String? category,
    String? searchQuery,
  }) async {
    communityLoads++;
    if (failCommunity) return const Left(NetworkFailure());
    return Right(posts);
  }

  @override
  Future<Either<Failure, List<SearchResultItem>>> search({
    required String query,
    SearchResultType filterType = SearchResultType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    searchQueries.add(query);
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<String>>> getRecentSearches() async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> saveRecentSearch(String query) async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Unexpected repository operation: ${invocation.memberName}',
      );
}

/// The Home recent-cases feed reads keys and subscribes to changes. Any
/// accidental write or new dependency fails, instead of reaching user data.
class _EmptyCasesBox implements Box<String> {
  @override
  Iterable<dynamic> get keys => const [];

  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Unexpected cache operation: ${invocation.memberName}',
      );
}

void main() {
  late _Repositories repo;
  late AppL10n uz;

  setUpAll(() async {
    uz = await AppL10n.delegate.load(const Locale('uz'));
  });

  setUp(() {
    repo = _Repositories();
    sl
      ..registerSingleton<Box<String>>(_EmptyCasesBox())
      ..registerSingleton<LocalCaseScope>(LocalCaseScope())
      ..registerFactory<HomeBloc>(() => HomeBloc(
            getHomeDataUseCase: GetHomeDataUseCase(repo),
            filterSeedQuestionsUseCase: FilterSeedQuestionsUseCase(repo),
            searchSeedQuestionsUseCase: SearchSeedQuestionsUseCase(repo),
          ))
      ..registerFactory<CommunityForumBloc>(() => CommunityForumBloc(
            getCommunityPostsUseCase: GetCommunityPostsUseCase(repo),
            createCommunityQuestionUseCase:
                CreateCommunityQuestionUseCase(repo),
            voteCommunityPostUseCase: VoteCommunityPostUseCase(repo),
            addCommunityAnswerUseCase: AddCommunityAnswerUseCase(repo),
            voteCommunityAnswerUseCase: VoteCommunityAnswerUseCase(repo),
            acceptCommunityAnswerUseCase: AcceptCommunityAnswerUseCase(repo),
          ))
      ..registerFactory<SearchBloc>(() => SearchBloc(
            globalSearchUseCase: GlobalSearchUseCase(repo),
          ));
  });

  tearDown(() async => sl.reset());

  Future<void> pumpHome(
    WidgetTester tester, {
    double width = 390,
    double height = 900,
    double scale = 1,
    String language = 'uz',
    bool dark = false,
    VoidCallback? onAdvice,
    ValueChanged<String>? onQuery,
    bool settle = true,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LocaleCubit>(
            create: (_) => testLocaleCubit(initial: Locale(language)),
          ),
          BlocProvider<AuthBloc>(
              create: (_) => AuthBloc(
                    authRepository: repo,
                    getCurrentUserUseCase: GetCurrentUserUseCase(repo),
                    getUserProfileUseCase: GetUserProfileUseCase(repo),
                    signInWithEmailUseCase: SignInWithEmailUseCase(repo),
                    signUpWithEmailUseCase: SignUpWithEmailUseCase(repo),
                    signOutUseCase: SignOutUseCase(repo),
                    updateUserProfileUseCase: UpdateUserProfileUseCase(repo),
                  )),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) => l10nTestApp(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, height),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: HomePage(onAskAITap: onAdvice, onSendQueryToAI: onQuery),
            ),
            locale: locale,
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder quickLabel(String label) => find.descendant(
        of: find.byType(QuickAccessGrid),
        matching: find.text(label),
      );

  for (final viewport in const [
    Size(320, 568),
    Size(360, 800),
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(820, 1180),
    Size(1024, 768),
    Size(1280, 720),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    final width = viewport.width;
    for (final scale in [1.0, 2.0]) {
      for (final language in ['uz', 'en']) {
        for (final dark in [false, true]) {
          testWidgets('loaded Home $width / $scale / $language / dark=$dark',
              (tester) async {
            final diagnostics = <String>[];
            final reportError = FlutterError.onError;
            FlutterError.onError = (details) {
              diagnostics.add(details.toString());
              reportError?.call(details);
            };
            addTearDown(() => FlutterError.onError = reportError);
            await pumpHome(tester,
                width: width,
                height: viewport.height,
                scale: scale,
                language: language,
                dark: dark);
            expect(find.byType(HomeHeroCard), findsOneWidget);
            // Device observation 2026-09-19: a shrink-wrapped hero left white
            // gutters and laid its illustration over the headline.
            expect(
              tester
                  .getSize(find
                      .descendant(
                        of: find.byType(HomeHeroCard),
                        matching: find.byType(Container),
                      )
                      .first)
                  .width,
              tester.getSize(find.byType(HomeHeroCard)).width,
              reason: 'The navy hero must fill its available width.',
            );
            expect(find.byType(QuickAccessGrid), findsOneWidget);
            expect(find.byType(CategoryGridWidget), findsOneWidget);
            expect(find.byType(CommunityMiniCard), findsOneWidget);
            expect(repo.homeLoads, 1);
            expect(repo.communityLoads, 1);
            final l10n = await AppL10n.delegate.load(Locale(language));
            await tester.ensureVisible(find.text(l10n.homeAskBannerTitle));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: diagnostics.join('\n'));
            expect(
                find.byType(LanguageQuickSwitch).hitTestable(), findsOneWidget,
                reason:
                    'Language switch must remain reachable while scrolled.');
          });
        }
      }
    }
  }

  testWidgets('loading keeps language switch usable', (tester) async {
    final gate = Completer<void>();
    repo.homeGate = gate;
    await pumpHome(tester, settle: false);
    expect(find.byType(LegalAnalysisShimmer), findsOneWidget);
    expect(find.byType(HomeHeroCard), findsNothing);
    await tester.tap(find.text('EN'));
    await tester.pump();
    final context = tester.element(find.byType(LanguageQuickSwitch));
    expect(context.read<LocaleCubit>().state.languageCode, 'en');
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeHeroCard), findsOneWidget);
    expect(repo.homeLoads, 1);
  });

  testWidgets('Home failure is localized and retry reloads both feeds',
      (tester) async {
    repo.failHome = true;
    await pumpHome(tester, language: 'en');
    final en = await AppL10n.delegate.load(const Locale('en'));
    const failure = NetworkFailure();
    expect(find.text(errorStateText(en, failure.message, failure.code)),
        findsOneWidget);
    expect(find.byType(LanguageQuickSwitch).hitTestable(), findsOneWidget);
    expect(find.byType(HomeHeroCard), findsNothing);
    repo.failHome = false;
    await tapVisible(tester, find.text(en.actionRetry));
    expect(repo.homeLoads, 2);
    expect(repo.communityLoads, 2);
    expect(find.byType(HomeHeroCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty community retains an explicit notice and other actions',
      (tester) async {
    repo.posts = [];
    await pumpHome(tester);
    expect(find.text(uz.homeCommunityEmpty), findsOneWidget);
    expect(find.byType(CommunityMiniCard), findsNothing);
    expect(find.byType(QuickAccessGrid), findsOneWidget);
    expect(find.byType(CategoryGridWidget), findsOneWidget);
  });

  testWidgets('community failure can retry without reloading Home data',
      (tester) async {
    repo.failCommunity = true;
    await pumpHome(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(HomeHeroCard), findsOneWidget);
    repo.failCommunity = false;
    await tapVisible(tester, find.text(uz.actionRetry));
    expect(repo.communityLoads, 2);
    expect(repo.homeLoads, 1);
    expect(find.byType(CommunityMiniCard), findsOneWidget);
  });

  testWidgets('category taps filter questions, toggle off, and show empty',
      (tester) async {
    await pumpHome(tester);
    final familyQuestions =
        await repo.local.getSeedQuestions(categoryId: 'oila');
    expect(familyQuestions, hasLength(1));
    final familyQuestion = familyQuestions.single.questionText;
    expect(find.text(familyQuestion), findsOneWidget);
    final labor = find.descendant(
        of: find.byType(CategoryGridWidget),
        matching: find.text(uz.categoryLabor));
    await tapVisible(tester, labor);
    expect(
        tester
            .widget<CategoryGridWidget>(find.byType(CategoryGridWidget))
            .selectedCategoryId,
        'mehnat');
    expect(find.text(familyQuestion), findsNothing);
    expect(find.text(uz.homeTopicMatters), findsOneWidget);
    await tapVisible(tester, labor);
    expect(
        tester
            .widget<CategoryGridWidget>(find.byType(CategoryGridWidget))
            .selectedCategoryId,
        isNull);
    expect(find.text(familyQuestion), findsOneWidget);
    await tapVisible(
        tester,
        find.descendant(
            of: find.byType(CategoryGridWidget),
            matching: find.text(uz.homeCatAdminFines)));
    expect(find.text(uz.trendingEmptyInCategory), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search surface opens the existing SearchPage', (tester) async {
    await pumpHome(tester);
    await tapVisible(tester, find.text(uz.homeQueryHint));
    expect(find.byType(SearchPage), findsOneWidget);
    expect(tester.widget<SearchPage>(find.byType(SearchPage)).initialQuery,
        isNull);
    expect(repo.searchQueries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['uz', 'en']) {
    testWidgets(
        'example query reaches SearchPage field and repository ($language)',
        (tester) async {
      await pumpHome(tester, language: language);
      final l10n = await AppL10n.delegate.load(Locale(language));
      final example = find.byKey(const Key('home-search-example-alimony'));
      expect(
          find.descendant(
              of: example, matching: find.text(l10n.homeExampleAlimony)),
          findsOneWidget);
      await tapVisible(tester, example);
      expect(find.byType(SearchPage), findsOneWidget);
      expect(tester.widget<SearchPage>(find.byType(SearchPage)).initialQuery,
          'Aliment');
      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(SearchPage), matching: find.byType(TextField)));
      expect(field.controller?.text, 'Aliment');
      expect(repo.searchQueries, ['Aliment']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick advice uses callback and urgent help opens its route',
      (tester) async {
    var adviceTaps = 0;
    await pumpHome(tester, onAdvice: () => adviceTaps++);
    await tapVisible(tester, quickLabel(uz.navAI));
    expect(adviceTaps, 1);
    expect(find.byType(HomePage), findsOneWidget);
    await tapVisible(tester, quickLabel(uz.homeQuickEmergency));
    expect(find.byType(EmergencyRightsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More preserves secondary entries and community handoff',
      (tester) async {
    final received = <String>[];
    // Destination layout is outside this redesign. Its long heading is
    // artificially widened by the Ahem test font; Home phone layouts are
    // exercised independently in the matrix above.
    await pumpHome(tester, width: 768, onQuery: received.add);
    await tapVisible(tester, quickLabel(uz.homeQuickMore));
    for (final label in [
      uz.navCommunity,
      uz.homeQuickSaved,
      uz.faqBannerTitle,
      uz.cabinetTabConsultations,
      uz.settingsTitle
    ]) {
      expect(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.text(label)),
          findsOneWidget);
    }
    await tapVisible(
        tester,
        find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(uz.navCommunity)));
    expect(find.byType(CommunityForumPage), findsOneWidget);
    final forum =
        tester.widget<CommunityForumPage>(find.byType(CommunityForumPage));
    expect(forum.onSendQueryToAI, isNotNull);
    forum.onSendQueryToAI?.call('Preserve this community question');
    expect(received, ['Preserve this community question']);
    expect(tester.takeException(), isNull);
  });
}
