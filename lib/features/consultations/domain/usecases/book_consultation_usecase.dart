import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';

class BookConsultationParams extends Equatable {
  final String expertId;
  final DateTime scheduledAt;
  final String meetingType;
  final String? notes;
  final String? questionId;
  final String provider;

  const BookConsultationParams({
    required this.expertId,
    required this.scheduledAt,
    this.meetingType = 'online',
    this.notes,
    this.questionId,
    this.provider = 'payme',
  });

  @override
  List<Object?> get props => [
        expertId,
        scheduledAt,
        meetingType,
        notes,
        questionId,
        provider,
      ];
}

class BookConsultationUseCase
    implements UseCase<PaymentCheckoutResult, BookConsultationParams> {
  final ConsultationRepository repository;

  BookConsultationUseCase(this.repository);

  @override
  Future<Either<Failure, PaymentCheckoutResult>> call(
      BookConsultationParams params) async {
    return repository.bookConsultation(
      expertId: params.expertId,
      scheduledAt: params.scheduledAt,
      meetingType: params.meetingType,
      notes: params.notes,
      questionId: params.questionId,
      provider: params.provider,
    );
  }
}
