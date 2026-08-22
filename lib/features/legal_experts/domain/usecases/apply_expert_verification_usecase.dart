import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';

class ApplyExpertVerificationParams extends Equatable {
  final String specialization;
  final int experienceYears;
  final String licenseNumber;
  final String? licenseDocumentUrl;
  final String? workplace;
  final String? education;
  final double consultationFee;

  const ApplyExpertVerificationParams({
    required this.specialization,
    required this.experienceYears,
    required this.licenseNumber,
    this.licenseDocumentUrl,
    this.workplace,
    this.education,
    this.consultationFee = 0.0,
  });

  @override
  List<Object?> get props => [
        specialization,
        experienceYears,
        licenseNumber,
        licenseDocumentUrl,
        workplace,
        education,
        consultationFee,
      ];
}

class ApplyExpertVerificationUseCase
    implements UseCase<Map<String, dynamic>, ApplyExpertVerificationParams> {
  final LegalExpertsRepository repository;

  ApplyExpertVerificationUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      ApplyExpertVerificationParams params) async {
    return await repository.applyForVerification(
      specialization: params.specialization,
      experienceYears: params.experienceYears,
      licenseNumber: params.licenseNumber,
      licenseDocumentUrl: params.licenseDocumentUrl,
      workplace: params.workplace,
      education: params.education,
      consultationFee: params.consultationFee,
    );
  }
}
