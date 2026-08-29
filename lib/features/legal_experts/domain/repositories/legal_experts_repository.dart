import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';

abstract class LegalExpertsRepository {
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  });

  Future<Either<Failure, LegalExpert>> getExpertById(String id);

  Future<Either<Failure, Map<String, dynamic>>> applyForVerification({
    required String specialization,
    required int experienceYears,
    required String licenseNumber,
    String? licenseDocumentUrl,
    String? workplace,
    String? education,
    double consultationFee = 0.0,
  });

  /// MODERATSIYA: tasdiqlash kutayotgan arizalar. Server tomonda RLS bilan
  /// qulflangan — admin bo'lmagan chaqiruvchi faqat O'Z arizasini oladi.
  Future<Either<Failure, List<ExpertApplication>>> getPendingApplications();

  /// MODERATSIYA: arizani tasdiqlash (`approve: true`) yoki rad etish.
  /// Yagona yo'l — `verify_expert_application` RPC.
  Future<Either<Failure, Map<String, dynamic>>> verifyExpertApplication({
    required String userId,
    required bool approve,
  });
}
