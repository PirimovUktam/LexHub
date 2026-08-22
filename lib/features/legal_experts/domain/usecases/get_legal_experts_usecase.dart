import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';

class GetLegalExpertsParams extends Equatable {
  final String? specialization;
  final String? city;
  final String? searchQuery;

  const GetLegalExpertsParams({
    this.specialization,
    this.city,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [specialization, city, searchQuery];
}

class GetLegalExpertsUseCase implements UseCase<List<LegalExpert>, GetLegalExpertsParams> {
  final LegalExpertsRepository repository;

  GetLegalExpertsUseCase(this.repository);

  @override
  Future<Either<Failure, List<LegalExpert>>> call(GetLegalExpertsParams params) async {
    return await repository.getExperts(
      specialization: params.specialization,
      city: params.city,
      searchQuery: params.searchQuery,
    );
  }
}
