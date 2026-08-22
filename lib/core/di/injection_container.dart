import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexhub/core/network/api_client.dart';
import 'package:lexhub/core/network/gemini_legal_service.dart';
import 'package:lexhub/core/network/network_info.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/localization/locale_store.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lexhub/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_datasource.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_remote_datasource.dart';
import 'package:lexhub/features/citizen_services/data/repositories/citizen_services_repository_impl.dart';
import 'package:lexhub/features/citizen_services/domain/repositories/citizen_services_repository.dart';
import 'package:lexhub/features/citizen_services/domain/usecases/get_citizen_services_usecase.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_bloc.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/data/repositories/community_forum_repository_impl.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';
import 'package:lexhub/features/community_forum/domain/usecases/accept_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/add_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/create_community_question_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/get_community_posts_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_post_usecase.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_bloc.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_remote_datasource.dart';
import 'package:lexhub/features/document_builder/data/repositories/document_builder_repository_impl.dart';
import 'package:lexhub/features/document_builder/domain/repositories/document_builder_repository.dart';
import 'package:lexhub/features/document_builder/domain/usecases/get_document_templates_usecase.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_bloc.dart';
import 'package:lexhub/features/home/data/datasources/home_local_datasource.dart';
import 'package:lexhub/features/home/data/repositories/home_repository_impl.dart';
import 'package:lexhub/features/home/domain/repositories/home_repository.dart';
import 'package:lexhub/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:lexhub/features/home/presentation/bloc/home_bloc.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_local_datasource.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/data/repositories/legal_assistant_repository_impl.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/detect_emergency_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/get_legal_advice_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_bloc.dart';
import 'package:lexhub/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart';
import 'package:lexhub/features/legal_experts/data/repositories/legal_experts_repository_impl.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/apply_expert_verification_usecase.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_legal_experts_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/consultations/data/datasources/consultation_remote_datasource.dart';
import 'package:lexhub/features/consultations/data/repositories/consultation_repository_impl.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';
import 'package:lexhub/features/consultations/domain/usecases/book_consultation_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/get_expert_available_slots_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/get_my_consultations_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/process_payment_usecase.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_bloc.dart';
import 'package:lexhub/features/saved_cases/presentation/bloc/saved_cases_bloc.dart';
import 'package:lexhub/features/search/data/datasources/search_local_datasource.dart';
import 'package:lexhub/features/search/data/datasources/search_remote_datasource.dart';
import 'package:lexhub/features/search/data/repositories/search_repository_impl.dart';
import 'package:lexhub/features/search/domain/repositories/search_repository.dart';
import 'package:lexhub/features/search/domain/usecases/global_search_usecase.dart';
import 'package:lexhub/features/search/presentation/bloc/search_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1. External & Local Storage
  await Hive.initFlutter();
  final legalCasesBox = await Hive.openBox<String>(LegalAssistantLocalDataSourceImpl.boxName);
  sl.registerLazySingleton<Box<String>>(() => legalCasesBox);

  // Til tanlovi uchun ALOHIDA box.
  //
  // `Box<String>` turi allaqachon legal-cases uchun ro'yxatdan o'tgan, shuning
  // uchun bu box GetIt'ga box sifatida EMAS, `LocaleStore` ichida beriladi —
  // tur to'qnashuvi (type collision) bo'lmaydi.
  final settingsBox = await Hive.openBox<String>(LocaleStore.boxName);
  sl.registerLazySingleton<LocaleStore>(() => LocaleStore(settingsBox));
  // Til — ilova umri bo'yicha YAGONA instance (lazy emas: `main()` darhol
  // o'qiydi va boshlang'ich locale'ni birinchi frame'dan oldin biladi).
  sl.registerSingleton<LocaleCubit>(LocaleCubit(store: sl<LocaleStore>()));

  // Supabase Client.
  //
  // Ataylab HECH QANDAY fallback yo'q. `main()` konfiguratsiya yetishmasa
  // `initDependencies()`ga umuman yetib kelmaydi, shuning uchun bu nuqtada
  // `Supabase.instance` doim initialize qilingan bo'ladi. Agar biror sabab
  // bilan bo'lmasa — xato JIM qolmasligi, balki darhol otilishi kerak.
  //
  // Oldingi versiya `catch (_)` bilan qo'lda yasalgan soxta client qaytarardi
  // (hardcoded host + soxta token). Natijada har bir backend chaqiruvi mavjud
  // bo'lmagan proyektga ketardi va asl konfiguratsiya xatosi oylab yashiringan.
  // Regression guard: test/core/config/supabase_config_test.dart
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // 2. Core (Network, NetworkInfo, AI)
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<GeminiLegalService>(() => GeminiLegalService());

  // 3. Data Sources
  // Auth
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(supabaseClient: sl()),
  );

  // Legal Assistant
  sl.registerLazySingleton<LegalAssistantRemoteDataSource>(
    () => LegalAssistantRemoteDataSourceImpl(
      apiClient: sl(),
      geminiService: sl(),
      supabaseClient: sl(),
    ),
  );
  sl.registerLazySingleton<LegalAssistantLocalDataSource>(
    () => LegalAssistantLocalDataSourceImpl(box: sl()),
  );
  sl.registerLazySingleton<HomeLocalDataSource>(
    () => HomeLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<CommunityForumDataSource>(
    () => CommunityForumDataSourceImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<CitizenServicesDataSource>(
    () => CitizenServicesDataSourceImpl(),
  );
  sl.registerLazySingleton<CitizenServicesLocalDataSource>(
    () => CitizenServicesLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<CitizenServicesRemoteDataSource>(
    () => CitizenServicesRemoteDataSourceImpl(
      supabaseClient: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<DocumentTemplatesDataSource>(
    () => DocumentTemplatesDataSourceImpl(),
  );
  sl.registerLazySingleton<DocumentTemplatesLocalDataSource>(
    () => DocumentTemplatesLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<DocumentTemplatesRemoteDataSource>(
    () => DocumentTemplatesRemoteDataSourceImpl(
      supabaseClient: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<LegalExpertsRemoteDataSource>(
    () => LegalExpertsRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );
  sl.registerLazySingleton<SearchLocalDataSource>(
    () => SearchLocalDataSourceImpl(
      templatesLocalDS: sl(),
      servicesLocalDS: sl(),
    ),
  );
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(
      supabaseClient: null,
      localDataSource: sl(),
    ),
  );

  // 4. Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<LegalAssistantRepository>(
    () => LegalAssistantRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<CommunityForumRepository>(
    () => CommunityForumRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton<CitizenServicesRepository>(
    () => CitizenServicesRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<DocumentBuilderRepository>(
    () => DocumentBuilderRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<LegalExpertsRepository>(
    () => LegalExpertsRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<ConsultationRemoteDataSource>(
    () => ConsultationRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );
  sl.registerLazySingleton<ConsultationRepository>(
    () => ConsultationRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  // 5. Use Cases
  // Auth
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => SignInWithEmailUseCase(sl()));
  sl.registerLazySingleton(() => SignUpWithEmailUseCase(sl()));
  sl.registerLazySingleton(() => SignOutUseCase(sl()));
  sl.registerLazySingleton(() => GetUserProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserProfileUseCase(sl()));

  // Legal Assistant
  sl.registerLazySingleton(() => GetLegalAdviceUseCase(sl()));
  sl.registerLazySingleton(() => DetectEmergencyUseCase(sl()));
  sl.registerLazySingleton(() => SaveCaseUseCase(sl()));
  sl.registerLazySingleton(() => GetSavedCasesUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSavedCaseUseCase(sl()));

  // Home
  sl.registerLazySingleton(() => GetHomeDataUseCase(sl()));
  sl.registerLazySingleton(() => FilterSeedQuestionsUseCase(sl()));
  sl.registerLazySingleton(() => SearchSeedQuestionsUseCase(sl()));

  // Community Forum
  sl.registerLazySingleton(() => GetCommunityPostsUseCase(sl()));
  sl.registerLazySingleton(() => CreateCommunityQuestionUseCase(sl()));
  sl.registerLazySingleton(() => VoteCommunityPostUseCase(sl()));
  sl.registerLazySingleton(() => AddCommunityAnswerUseCase(sl()));
  sl.registerLazySingleton(() => VoteCommunityAnswerUseCase(sl()));
  sl.registerLazySingleton(() => AcceptCommunityAnswerUseCase(sl()));

  // Citizen Services
  sl.registerLazySingleton(() => GetCitizenServicesUseCase(sl()));

  // Document Builder
  sl.registerLazySingleton(() => GetDocumentTemplatesUseCase(sl()));
  sl.registerLazySingleton(() => GetTemplateByIdUseCase(sl()));

  // Legal Experts
  sl.registerLazySingleton(() => GetLegalExpertsUseCase(sl()));
  sl.registerLazySingleton(() => ApplyExpertVerificationUseCase(sl()));

  // Consultations & Payments
  sl.registerLazySingleton(() => GetExpertAvailableSlotsUseCase(sl()));
  sl.registerLazySingleton(() => BookConsultationUseCase(sl()));
  sl.registerLazySingleton(() => ProcessPaymentUseCase(sl()));
  sl.registerLazySingleton(() => GetMyConsultationsUseCase(sl()));
  sl.registerLazySingleton(() => CancelConsultationUseCase(sl()));

  // Global Search
  sl.registerLazySingleton(() => GlobalSearchUseCase(sl()));

  // 6. Blocs (Lazy Singleton for AuthBloc to maintain session, Factory for UI Blocs)
  sl.registerLazySingleton(
    () => AuthBloc(
      authRepository: sl(),
      getCurrentUserUseCase: sl(),
      signInWithEmailUseCase: sl(),
      signUpWithEmailUseCase: sl(),
      signOutUseCase: sl(),
      getUserProfileUseCase: sl(),
      updateUserProfileUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => LegalAssistantBloc(
      getLegalAdviceUseCase: sl(),
      detectEmergencyUseCase: sl(),
      saveCaseUseCase: sl(),
      deleteSavedCaseUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => CommunityForumBloc(
      getCommunityPostsUseCase: sl(),
      createCommunityQuestionUseCase: sl(),
      voteCommunityPostUseCase: sl(),
      addCommunityAnswerUseCase: sl(),
      voteCommunityAnswerUseCase: sl(),
      acceptCommunityAnswerUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => CitizenServicesBloc(
      getCitizenServicesUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => SavedCasesBloc(
      getSavedCasesUseCase: sl(),
      deleteSavedCaseUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => HomeBloc(
      getHomeDataUseCase: sl(),
      filterSeedQuestionsUseCase: sl(),
      searchSeedQuestionsUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => DocumentBuilderBloc(
      getDocumentTemplatesUseCase: sl(),
      getTemplateByIdUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => LegalExpertsBloc(
      getLegalExpertsUseCase: sl(),
      applyExpertVerificationUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ConsultationBloc(
      getExpertAvailableSlotsUseCase: sl(),
      bookConsultationUseCase: sl(),
      processPaymentUseCase: sl(),
      getMyConsultationsUseCase: sl(),
      cancelConsultationUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => SearchBloc(
      globalSearchUseCase: sl(),
    ),
  );
}
