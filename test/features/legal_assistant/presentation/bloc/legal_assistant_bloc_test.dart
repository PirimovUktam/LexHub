import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/detect_emergency_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/get_legal_advice_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_bloc.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_event.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_state.dart';

class MockLegalAssistantRepository implements LegalAssistantRepository {
  @override
  Future<Either<Failure, LegalResponse>> getLegalAdvice(dynamic query) async {
    return Right(
      LegalResponse(
        id: "resp_1",
        queryId: "q_1",
        relatableSummary: "Ishdan bo'shatish noqonuniy.",
        actionableSteps: const ["Sudga murojaat qiling"],
        legalBasis: const [
          LawArticle(
            lawName: "Mehnat kodeksi",
            articleNumber: "161-modda",
            articleTitle: "Bekor qilish",
            articleText: "Matn",
            lexUrl: "https://lex.uz",
          ),
        ],
        riskAssessment: const RiskAssessment(
          level: RiskLevel.medium,
          summary: "O'rtacha risk",
        ),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Either<Failure, EmergencyProtocol?>> detectEmergency(String queryText) async {
    if (queryText.contains("hibs")) {
      return const Right(
        EmergencyProtocol(
          isEmergency: true,
          title: "Hibsga olish holati",
          emergencyHotline: "1002",
        ),
      );
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> saveCase(LegalResponse response) async => const Right(null);

  @override
  Future<Either<Failure, List<LegalResponse>>> getSavedCases() async => const Right([]);

  @override
  Future<Either<Failure, void>> deleteSavedCase(String id) async => const Right(null);
}

void main() {
  late MockLegalAssistantRepository mockRepo;
  late GetLegalAdviceUseCase getLegalAdviceUseCase;
  late DetectEmergencyUseCase detectEmergencyUseCase;
  late SaveCaseUseCase saveCaseUseCase;
  late DeleteSavedCaseUseCase deleteSavedCaseUseCase;
  late LegalAssistantBloc bloc;

  setUp(() {
    mockRepo = MockLegalAssistantRepository();
    getLegalAdviceUseCase = GetLegalAdviceUseCase(mockRepo);
    detectEmergencyUseCase = DetectEmergencyUseCase(mockRepo);
    saveCaseUseCase = SaveCaseUseCase(mockRepo);
    deleteSavedCaseUseCase = DeleteSavedCaseUseCase(mockRepo);

    bloc = LegalAssistantBloc(
      getLegalAdviceUseCase: getLegalAdviceUseCase,
      detectEmergencyUseCase: detectEmergencyUseCase,
      saveCaseUseCase: saveCaseUseCase,
      deleteSavedCaseUseCase: deleteSavedCaseUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be LegalAssistantInitial', () {
    expect(bloc.state, equals(const LegalAssistantInitial()));
  });

  test('emits LegalAssistantLoading then LegalAssistantSuccess on SubmitLegalQueryEvent', () async {
    final expectedStates = [
      isA<LegalAssistantLoading>(),
      isA<LegalAssistantSuccess>(),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));

    bloc.add(const SubmitLegalQueryEvent(
      queryText: "Meni noqonuniy ishdan bo'shatishmoqda",
    ));
  });

  test('emits liveEmergencyWarning on CheckEmergencyTextEvent with red flag keywords', () async {
    bloc.add(const CheckEmergencyTextEvent("Meni hibsga olishdi"));

    await expectLater(
      bloc.stream,
      emits(
        predicate<LegalAssistantState>(
          (state) =>
              state.liveEmergencyWarning != null &&
              state.liveEmergencyWarning!.isEmergency == true,
        ),
      ),
    );
  });

  test('auto-saves response into local storage with selected category on SubmitLegalQueryEvent', () async {
    bloc.add(const SubmitLegalQueryEvent(
      queryText: "Bank krediti bo'yicha foizlar asossiz oshirildi",
      category: "Bank va kredit",
    ));

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<LegalAssistantState>((state) {
          if (state is LegalAssistantSuccess) {
            return state.isSaved == true &&
                state.response.isSaved == true &&
                state.response.category == "Bank va kredit" &&
                state.response.userQuery == "Bank krediti bo'yicha foizlar asossiz oshirildi";
          }
          return false;
        }),
      ),
    );
  });
}
