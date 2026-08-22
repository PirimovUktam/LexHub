import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';

class GetMyConsultationsUseCase
    implements UseCase<List<Consultation>, NoParams> {
  final ConsultationRepository repository;

  GetMyConsultationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Consultation>>> call(NoParams params) async {
    return repository.getMyConsultations();
  }
}

class CancelConsultationParams extends Equatable {
  final String consultationId;
  final String reason;

  const CancelConsultationParams({
    required this.consultationId,
    this.reason = 'Foydalanuvchi tomonidan bekor qilindi',
  });

  @override
  List<Object?> get props => [consultationId, reason];
}

class CancelConsultationUseCase
    implements UseCase<Map<String, dynamic>, CancelConsultationParams> {
  final ConsultationRepository repository;

  CancelConsultationUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      CancelConsultationParams params) async {
    return repository.cancelConsultation(
      consultationId: params.consultationId,
      reason: params.reason,
    );
  }
}
