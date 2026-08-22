import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/apply_expert_verification_usecase.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_legal_experts_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_state.dart';

class MockLegalExpertsRepository implements LegalExpertsRepository {
  final List<LegalExpert> mockExperts = const [
    LegalExpert(
      id: 'adv_test_1',
      fullName: 'Alisher Karimov',
      specialization: 'Mehnat huquqi',
      licenseNumber: 'ADV-12345',
      rating: 4.9,
      experienceYears: 10,
      city: 'Toshkent sh.',
      address: 'Nukus ko\'chasi',
      consultationType: ConsultationType.all,
      phoneNumber: '+998901234567',
      telegramUsername: 'adv_alisher',
      bio: 'Tajribali advokat',
    ),
    LegalExpert(
      id: 'adv_test_2',
      fullName: 'Jasur Rustamov',
      specialization: 'Jinoyat huquqi',
      licenseNumber: 'ADV-54321',
      rating: 4.8,
      experienceYears: 8,
      city: 'Samarqand sh.',
      address: 'Registon',
      consultationType: ConsultationType.office,
      phoneNumber: '+998933334455',
      telegramUsername: 'adv_jasur',
      bio: 'Jinoyat ishlari advokati',
    ),
  ];

  @override
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async {
    var result = mockExperts;
    if (specialization != null) {
      result = result.where((e) => e.specialization.contains(specialization)).toList();
    }
    if (city != null) {
      result = result.where((e) => e.city.contains(city)).toList();
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, LegalExpert>> getExpertById(String id) async {
    return Right(mockExperts.first);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> applyForVerification({
    required String specialization,
    required int experienceYears,
    required String licenseNumber,
    String? licenseDocumentUrl,
    String? workplace,
    String? education,
    double consultationFee = 0.0,
  }) async {
    return const Right({
      'success': true,
      'status': 'pending_verification',
      'message': 'Ariza qabul qilindi.',
    });
  }
}

void main() {
  late MockLegalExpertsRepository mockRepo;
  late GetLegalExpertsUseCase getLegalExpertsUseCase;
  late ApplyExpertVerificationUseCase applyExpertVerificationUseCase;
  late LegalExpertsBloc bloc;

  setUp(() {
    mockRepo = MockLegalExpertsRepository();
    getLegalExpertsUseCase = GetLegalExpertsUseCase(mockRepo);
    applyExpertVerificationUseCase = ApplyExpertVerificationUseCase(mockRepo);
    bloc = LegalExpertsBloc(
      getLegalExpertsUseCase: getLegalExpertsUseCase,
      applyExpertVerificationUseCase: applyExpertVerificationUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be LegalExpertsInitial', () {
    expect(bloc.state, equals(LegalExpertsInitial()));
  });

  test('emits LegalExpertsLoading and LegalExpertsLoaded on LoadLegalExpertsEvent', () async {
    final expectedStates = [
      isA<LegalExpertsLoading>(),
      isA<LegalExpertsLoaded>(),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));
    bloc.add(const LoadLegalExpertsEvent());
  });

  test('filters experts by specialization properly', () async {
    bloc.add(const LoadLegalExpertsEvent());
    await expectLater(bloc.stream, emitsThrough(isA<LegalExpertsLoaded>()));

    bloc.add(const FilterSpecializationEvent('Mehnat'));
    await expectLater(
      bloc.stream,
      emits(
        predicate<LegalExpertsState>((state) {
          if (state is LegalExpertsLoaded) {
            return state.selectedSpecialization == 'Mehnat' &&
                state.experts.length == 1 &&
                state.experts.first.fullName == 'Alisher Karimov';
          }
          return false;
        }),
      ),
    );
  });

  test('submits expert application and emits ExpertApplicationSuccess', () async {
    final expectedStates = [
      isA<ExpertApplicationSubmitting>(),
      isA<ExpertApplicationSuccess>(),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));

    bloc.add(
      const SubmitExpertApplicationEvent(
        specialization: 'Oila huquqi',
        experienceYears: 7,
        licenseNumber: 'ADV-77881',
      ),
    );
  });
}
