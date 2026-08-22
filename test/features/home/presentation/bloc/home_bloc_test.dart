import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/home/domain/repositories/home_repository.dart';
import 'package:lexhub/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:lexhub/features/home/presentation/bloc/home_bloc.dart';
import 'package:lexhub/features/home/presentation/bloc/home_event.dart';
import 'package:lexhub/features/home/presentation/bloc/home_state.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

class MockHomeRepository implements HomeRepository {
  final List<LegalCategory> mockCategories = const [
    LegalCategory(
      id: 'mehnat',
      title: 'Mehnat huquqi',
      description: "Ishdan bo'shatish",
      icon: Icons.work,
      color: Colors.blue,
    ),
    LegalCategory(
      id: 'yhq',
      title: "Yo'l harakati",
      description: "Jarimalar",
      icon: Icons.car_rental,
      color: Colors.red,
    ),
  ];

  final List<SeedQuestionModel> mockQuestions = const [
    SeedQuestionModel(
      id: 's_1',
      categoryId: 'mehnat',
      categoryName: 'Mehnat huquqi',
      questionText: "Ishdan nohaq bo'shatish",
      relatableSummary: "Xulosa",
      actionableSteps: ["Qadam 1"],
      legalBasis: [],
      riskAssessment: RiskAssessment(level: RiskLevel.low, summary: "Past risk"),
    ),
  ];

  @override
  Future<Either<Failure, List<LegalCategory>>> getCategories() async {
    return Right(mockCategories);
  }

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> getSeedQuestions({String? categoryId}) async {
    if (categoryId != null) {
      return Right(mockQuestions.where((q) => q.categoryId == categoryId).toList());
    }
    return Right(mockQuestions);
  }

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> searchSeedQuestions(String query) async {
    return Right(mockQuestions);
  }
}

void main() {
  late MockHomeRepository mockRepo;
  late GetHomeDataUseCase getHomeDataUseCase;
  late FilterSeedQuestionsUseCase filterSeedQuestionsUseCase;
  late SearchSeedQuestionsUseCase searchSeedQuestionsUseCase;
  late HomeBloc homeBloc;

  setUp(() {
    mockRepo = MockHomeRepository();
    getHomeDataUseCase = GetHomeDataUseCase(mockRepo);
    filterSeedQuestionsUseCase = FilterSeedQuestionsUseCase(mockRepo);
    searchSeedQuestionsUseCase = SearchSeedQuestionsUseCase(mockRepo);

    homeBloc = HomeBloc(
      getHomeDataUseCase: getHomeDataUseCase,
      filterSeedQuestionsUseCase: filterSeedQuestionsUseCase,
      searchSeedQuestionsUseCase: searchSeedQuestionsUseCase,
    );
  });

  tearDown(() {
    homeBloc.close();
  });

  test('initial state should be HomeInitial', () {
    expect(homeBloc.state, equals(HomeInitial()));
  });

  test('emits HomeLoading and HomeLoaded on LoadHomeDataEvent', () async {
    final expectedStates = [
      isA<HomeLoading>(),
      isA<HomeLoaded>(),
    ];

    expectLater(homeBloc.stream, emitsInOrder(expectedStates));
    homeBloc.add(const LoadHomeDataEvent());
  });

  test('filters questions when SelectCategoryFilterEvent is dispatched', () async {
    homeBloc.add(const LoadHomeDataEvent());
    await expectLater(
      homeBloc.stream,
      emitsThrough(isA<HomeLoaded>()),
    );

    homeBloc.add(const SelectCategoryFilterEvent('mehnat'));
    await expectLater(
      homeBloc.stream,
      emits(
        predicate<HomeState>((state) {
          if (state is HomeLoaded) {
            return state.selectedCategoryId == 'mehnat';
          }
          return false;
        }),
      ),
    );
  });
}
