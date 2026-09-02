import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/apply_expert_verification_usecase.dart';

class MockLegalExpertsRepository implements LegalExpertsRepository {
  @override
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, LegalExpert>> getExpertById(String id) async {
    return const Right(
      LegalExpert(
        id: '1',
        fullName: 'Test Advokat',
        specialization: 'Mehnat',
        licenseNumber: 'ADV-1',
        rating: 5.0,
        experienceYears: 10,
        city: 'Toshkent',
        address: 'Nukus 1',
        consultationType: ConsultationType.all,
        phoneNumber: '+998901234567',
        telegramUsername: 'test',
        bio: 'Bio',
      ),
    );
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
    if (licenseNumber.isEmpty) {
      return const Left(ValidationFailure(message: 'Litsenziya raqami kiritilishi shart'));
    }
    return const Right({
      'success': true,
      'status': 'pending_verification',
      'message': 'Ariza muvaffaqiyatli topshirildi.',
    });
  }
  // MODERATSIYA metodlari bu testda ISHLATILMAYDI. `UnimplementedError`
  // ATAYLAB: jim `Right([])` qaytarish testni yashirin ravishda "o'tdi"
  // qilardi, aslida esa moderatsiya yo'li tekshirilmagan bo'lib qolardi.
  @override
  Future<Either<Failure, List<ExpertApplication>>>
      getPendingApplications() async {
    throw UnimplementedError('bu testda moderatsiya arizalari kutilmaydi');
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> verifyExpertApplication({
    required String userId,
    required bool approve,
    String? rejectionReason,
  }) async {
    throw UnimplementedError('bu testda tasdiqlash RPC chaqirilmaydi');
  }
}

void main() {
  late ApplyExpertVerificationUseCase useCase;
  late MockLegalExpertsRepository repository;

  setUp(() {
    repository = MockLegalExpertsRepository();
    useCase = ApplyExpertVerificationUseCase(repository);
  });

  group('ApplyExpertVerificationUseCase Tests', () {
    test('should return success map when valid application is submitted', () async {
      const params = ApplyExpertVerificationParams(
        specialization: "Mehnat huquqi",
        experienceYears: 5,
        licenseNumber: "ADV-99881",
        workplace: "Toshkent Advokatlar Hay'ati",
        consultationFee: 150000.0,
      );

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (data) {
          expect(data['success'], true);
          expect(data['status'], 'pending_verification');
        },
      );
    });

    test('should return failure when validation fails', () async {
      const params = ApplyExpertVerificationParams(
        specialization: "Mehnat huquqi",
        experienceYears: 5,
        licenseNumber: "", // Invalid
      );

      final result = await useCase(params);

      expect(result.isLeft(), true);
    });
  });
}
