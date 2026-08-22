import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';

class GetExpertAvailableSlotsParams extends Equatable {
  final String expertId;
  final DateTime date;

  const GetExpertAvailableSlotsParams({
    required this.expertId,
    required this.date,
  });

  @override
  List<Object?> get props => [expertId, date];
}

class GetExpertAvailableSlotsUseCase
    implements UseCase<List<ConsultationSlot>, GetExpertAvailableSlotsParams> {
  final ConsultationRepository repository;

  GetExpertAvailableSlotsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ConsultationSlot>>> call(
      GetExpertAvailableSlotsParams params) async {
    return repository.getExpertAvailableSlots(
      expertId: params.expertId,
      date: params.date,
    );
  }
}
