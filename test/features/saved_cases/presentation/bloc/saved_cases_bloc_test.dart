import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:lexhub/features/saved_cases/presentation/bloc/saved_cases_bloc.dart';

class MockSavedCasesRepository implements LegalAssistantRepository {
  List<LegalResponse> savedList = [
    LegalResponse(
      id: "case_bank_1",
      queryId: "q_bank",
      userQuery: "Bank krediti stavkasini bir tomonlama oshirdi",
      category: "Bank va kredit",
      relatableSummary: "Bank shartnomani bir tomonlama o'zgartirishga haqli emas.",
      actionableSteps: const ["Pretenziya xati yuboring"],
      legalBasis: const [
        LawArticle(
          lawName: "Fuqarolik kodeksi",
          articleNumber: "382-modda",
          articleTitle: "Shartnomani o'zgartirish",
          articleText: "Matn",
          lexUrl: "https://lex.uz",
        ),
      ],
      riskAssessment: const RiskAssessment(
        level: RiskLevel.low,
        summary: "Yutuq ehtimoli yuqori",
      ),
      createdAt: DateTime.now(),
      isSaved: true,
    ),
  ];

  @override
  Future<Either<Failure, void>> saveCase(LegalResponse response) async {
    savedList.insert(0, response);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<LegalResponse>>> getSavedCases() async {
    return Right(List<LegalResponse>.from(savedList));
  }

  @override
  Future<Either<Failure, void>> deleteSavedCase(String id) async {
    savedList.removeWhere((item) => item.id == id);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockSavedCasesRepository mockRepo;
  late GetSavedCasesUseCase getSavedCasesUseCase;
  late DeleteSavedCaseUseCase deleteSavedCaseUseCase;
  late SavedCasesBloc bloc;

  setUp(() {
    mockRepo = MockSavedCasesRepository();
    getSavedCasesUseCase = GetSavedCasesUseCase(mockRepo);
    deleteSavedCaseUseCase = DeleteSavedCaseUseCase(mockRepo);
    bloc = SavedCasesBloc(
      getSavedCasesUseCase: getSavedCasesUseCase,
      deleteSavedCaseUseCase: deleteSavedCaseUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be SavedCasesInitial', () {
    expect(bloc.state, isA<SavedCasesInitial>());
  });

  test('emits SavedCasesLoading and SavedCasesLoaded with persisted cases', () async {
    final expectedStates = [
      isA<SavedCasesLoading>(),
      isA<SavedCasesLoaded>(),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));
    bloc.add(const LoadSavedCasesEvent());
  });

  test('loads saved case with correct category, query and law articles', () async {
    bloc.add(const LoadSavedCasesEvent());

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<SavedCasesState>((state) {
          if (state is SavedCasesLoaded) {
            final firstCase = state.cases.first;
            return state.cases.length == 1 &&
                firstCase.category == "Bank va kredit" &&
                firstCase.userQuery.contains("Bank krediti") &&
                firstCase.legalBasis.isNotEmpty;
          }
          return false;
        }),
      ),
    );
  });

  test('deletes saved case item properly and reloads list', () async {
    bloc.add(const DeleteSavedCaseItemEvent("case_bank_1"));

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<SavedCasesState>((state) {
          if (state is SavedCasesLoaded) {
            return state.cases.isEmpty;
          }
          return false;
        }),
      ),
    );
  });
}
