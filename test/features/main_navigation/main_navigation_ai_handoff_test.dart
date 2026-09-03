/// HAMJAMIYAT SAVOLI -> "MASLAHAT" BO'LIMI UZATMASI (Problem Intake).
///
/// TOPILGAN NUQSON (`main_navigation_page.dart`, audit):
///
///     onSendQueryToAI: (query) { _navigateToTab(1); }   // <- `query` TASHLANDI
///     ...
///     const LegalAssistantPage(),                       // <- savol BERILMADI
///
/// `LegalAssistantPage` `initialQuery` ni ALLAQACHON qo'llab-quvvatlaydi va
/// bu parametr boshqa ikki joyda TO'G'RI ishlatiladi (`home_page.dart:535`,
/// `faq_questions_page.dart:205`). Ya'ni quvurning faqat SHU bo'g'ini uzilgan
/// edi: foydalanuvchi hamjamiyat savolida "AI'dan so'rash" ni bosardi va
/// BO'SH ekranga tushardi — savolini qaytadan yozishi kerak edi. Hech qanday
/// xato ko'rinmasdi (§20: jim ma'lumot yo'qotish).
///
/// IKKINCHI (nozik) qism: `IndexedStack` `LegalAssistantPage` ni TIRIK
/// saqlaydi, `initialQuery` esa faqat `initState` da o'qiladi. Shuning uchun
/// parametrni ulashning O'ZI kifoya QILMAYDI — sahifa qayta yaratilishi
/// kerak. Shu sababli 2-tekshiruv `initialQuery` maydonini emas, MATN
/// MAYDONINING O'ZINI o'qiydi: u remount bo'lmasa BO'SH qoladi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/citizen_services/domain/repositories/citizen_services_repository.dart';
import 'package:lexhub/features/citizen_services/domain/usecases/get_citizen_services_usecase.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_bloc.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_event.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';
import 'package:lexhub/features/community_forum/domain/usecases/accept_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/add_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/create_community_question_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/get_community_posts_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_post_usecase.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_bloc.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_event.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/home/domain/repositories/home_repository.dart';
import 'package:lexhub/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:lexhub/features/home/presentation/bloc/home_bloc.dart';
import 'package:lexhub/features/home/presentation/bloc/home_event.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/detect_emergency_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/get_legal_advice_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_bloc.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_event.dart';
import 'package:lexhub/features/legal_assistant/presentation/pages/legal_assistant_page.dart';
import 'package:lexhub/features/main_navigation/presentation/pages/main_navigation_page.dart';

import '../../support/l10n_test_app.dart';
import '../../support/locale_test_cubit.dart';

/// Testda HECH QACHON chaqirilmasligi kerak bo'lgan repozitoriylar.
/// Chaqirilsa — test yiqiladi, ya'ni "tarmoqqa chiqmadi" da'vosi tekshiriladi.
class _UnusedRepo implements
    HomeRepository,
    CommunityForumRepository,
    LegalAssistantRepository,
    CitizenServicesRepository,
    AuthRepository {
  /// `AuthBloc` konstruktori shu oqimga DARHOL obuna bo'ladi
  /// (`auth_bloc.dart:44`) — `noSuchMethod` uni ushlab qolsa bloc
  /// yaratilmaydi. Bo'sh oqim: hech qanday auth hodisasi kelmaydi.
  @override
  Stream<UserEntity?> get authStateChanges => const Stream<UserEntity?>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'Testda repozitoriy chaqirilmasligi kerak: ${invocation.memberName}');
}

/// Sahifalar `create:` ichida hodisa qo'shadi (`LoadHomeDataEvent` va h.k.).
/// `add` bloklanmasa oqim repozitoriyga yetib boradi.
class _FrozenHomeBloc extends HomeBloc {
  _FrozenHomeBloc(_UnusedRepo r)
      : super(
          getHomeDataUseCase: GetHomeDataUseCase(r),
          filterSeedQuestionsUseCase: FilterSeedQuestionsUseCase(r),
          searchSeedQuestionsUseCase: SearchSeedQuestionsUseCase(r),
        );
  @override
  void add(HomeEvent event) {}
}

class _FrozenCommunityBloc extends CommunityForumBloc {
  _FrozenCommunityBloc(_UnusedRepo r)
      : super(
          getCommunityPostsUseCase: GetCommunityPostsUseCase(r),
          createCommunityQuestionUseCase: CreateCommunityQuestionUseCase(r),
          voteCommunityPostUseCase: VoteCommunityPostUseCase(r),
          addCommunityAnswerUseCase: AddCommunityAnswerUseCase(r),
          voteCommunityAnswerUseCase: VoteCommunityAnswerUseCase(r),
          acceptCommunityAnswerUseCase: AcceptCommunityAnswerUseCase(r),
        );
  @override
  void add(CommunityForumEvent event) {}
}

class _FrozenLegalBloc extends LegalAssistantBloc {
  _FrozenLegalBloc(_UnusedRepo r)
      : super(
          getLegalAdviceUseCase: GetLegalAdviceUseCase(r),
          detectEmergencyUseCase: DetectEmergencyUseCase(r),
          saveCaseUseCase: SaveCaseUseCase(r),
          deleteSavedCaseUseCase: DeleteSavedCaseUseCase(r),
        );
  @override
  void add(LegalAssistantEvent event) {}
}

class _FrozenCitizenBloc extends CitizenServicesBloc {
  _FrozenCitizenBloc(_UnusedRepo r)
      : super(getCitizenServicesUseCase: GetCitizenServicesUseCase(r));
  @override
  void add(CitizenServicesEvent event) {}
}

/// `AuthBloc` ilovada `MaterialApp` USTIDA beriladi (`main.dart:175`), ya'ni
/// `sl` dan emas, ANCESTOR provider'dan olinadi — `ProfileTabPage` uni
/// `BlocBuilder` bilan o'qiydi. Shu sababli test ham shu shaklni takrorlaydi.
class _FrozenAuthBloc extends AuthBloc {
  _FrozenAuthBloc(_UnusedRepo r)
      : super(
          authRepository: r,
          getCurrentUserUseCase: GetCurrentUserUseCase(r),
          signInWithEmailUseCase: SignInWithEmailUseCase(r),
          signUpWithEmailUseCase: SignUpWithEmailUseCase(r),
          signOutUseCase: SignOutUseCase(r),
          getUserProfileUseCase: GetUserProfileUseCase(r),
          updateUserProfileUseCase: UpdateUserProfileUseCase(r),
        );
  @override
  void add(AuthEvent event) {}
}

/// Yig'ilgan `LegalAssistantPage` ni daraxtdan oladi (`IndexedStack` barcha
/// bolalarni quradi, shuning uchun u tab almashmasa ham mavjud).
/// `skipOffstage: false` MAJBURIY: `IndexedStack` tanlanmagan bolalarni
/// OFFSTAGE qiladi, `find.byType` esa sukut bo'yicha ularni o'tkazib yuboradi.
LegalAssistantPage _legalPage(WidgetTester tester) =>
    tester.widget<LegalAssistantPage>(
      find.byType(LegalAssistantPage, skipOffstage: false),
    );

Future<void> _pumpNav(WidgetTester tester) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => _FrozenAuthBloc(_UnusedRepo())),
        // `LocaleCubit` ham `MaterialApp` USTIDA beriladi (`main.dart:174`) —
        // bosh sahifadagi `LanguageQuickSwitch` uni o'qiydi, ya'ni
        // `IndexedStack` HomePage'ni qurganda bu provider MAJBURIY.
        BlocProvider<LocaleCubit>(create: (_) => testLocaleCubit()),
      ],
      child: l10nTestApp(const MainNavigationPage()),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    final repo = _UnusedRepo();
    sl
      ..registerFactory<HomeBloc>(() => _FrozenHomeBloc(repo))
      ..registerFactory<CommunityForumBloc>(() => _FrozenCommunityBloc(repo))
      ..registerFactory<LegalAssistantBloc>(() => _FrozenLegalBloc(repo))
      ..registerFactory<CitizenServicesBloc>(() => _FrozenCitizenBloc(repo));
  });

  tearDown(() {
    sl
      ..unregister<HomeBloc>()
      ..unregister<CommunityForumBloc>()
      ..unregister<LegalAssistantBloc>()
      ..unregister<CitizenServicesBloc>();
  });

  testWidgets('MEXANIZM: boshida savol maydoni BO\'SH va uzatma yo\'q',
      (tester) async {
    await _pumpNav(tester);

    expect(
      _legalPage(tester).initialQuery,
      isNull,
      reason: 'Uzatmadan OLDIN savol bo\'lmasligi kerak — aks holda '
          'quyidagi tekshiruv bo\'sh (har doim yashil) bo\'lib qoladi.',
    );
  });

  testWidgets('UZATMA: hamjamiyat savoli "Maslahat" maydoniga TUSHADI',
      (tester) async {
    const question = 'Ish beruvchi mehnat shartnomasini bekor qildi';

    await _pumpNav(tester);

    // Hamjamiyat kartasidagi "AI'dan so'rash" tugmasi AYNAN shu callback'ni
    // chaqiradi (`community_forum_page.dart:265`).
    final forum = tester.widget<CommunityForumPage>(
      find.byType(CommunityForumPage, skipOffstage: false),
    );
    expect(
      forum.onSendQueryToAI,
      isNotNull,
      reason: 'Hamjamiyat sahifasiga uzatma callback berilmagan.',
    );
    forum.onSendQueryToAI!(question);
    // `pumpAndSettle` ATAYLAB ishlatilmaydi: qotib qolgan bloclar sahifalarni
    // `Initial` holatida ushlaydi va shimmer animatsiyasi HECH QACHON
    // tugamaydi ("pumpAndSettle timed out"). Holat o'zgarishi esa sinxron
    // `setState`, ya'ni bitta kadr yetarli.
    await tester.pump();

    // 1) Savol sahifaga YETDI.
    expect(_legalPage(tester).initialQuery, question);

    // 2) ENG MUHIM: matn maydonining O'ZI to'ldirildi. `IndexedStack` sahifani
    //    tirik saqlagani uchun remount bo'lmasa bu tekshiruv YIQILADI.
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(LegalAssistantPage, skipOffstage: false),
        matching: find.byType(TextField, skipOffstage: false),
      ),
    );
    expect(
      field.controller?.text,
      question,
      reason: 'Sahifa qayta yaratilmagan — `initialQuery` faqat `initState` '
          'da o\'qiladi, ya\'ni foydalanuvchi hamon BO\'SH maydon ko\'radi.',
    );
  });

  testWidgets('BO\'SH SAVOL: sahifa remount BO\'LMAYDI (yozilgan matn saqlanadi)',
      (tester) async {
    await _pumpNav(tester);

    final forum = tester.widget<CommunityForumPage>(
      find.byType(CommunityForumPage, skipOffstage: false),
    );
    forum.onSendQueryToAI!('   ');
    // `pumpAndSettle` ATAYLAB ishlatilmaydi: qotib qolgan bloclar sahifalarni
    // `Initial` holatida ushlaydi va shimmer animatsiyasi HECH QACHON
    // tugamaydi ("pumpAndSettle timed out"). Holat o'zgarishi esa sinxron
    // `setState`, ya'ni bitta kadr yetarli.
    await tester.pump();

    expect(
      _legalPage(tester).initialQuery,
      isNull,
      reason: 'Bo\'sh matn uchun remount qilinmasligi kerak: aks holda '
          'foydalanuvchining yozib qo\'ygan savoli o\'chib ketadi.',
    );
  });
}
