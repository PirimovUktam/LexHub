import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:lexhub/features/citizen_services/domain/repositories/citizen_services_repository.dart';

class GetCitizenServicesParams extends Equatable {
  final String? category;
  final String? searchQuery;

  const GetCitizenServicesParams({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class GetCitizenServicesUseCase implements UseCase<List<CitizenService>, GetCitizenServicesParams> {
  final CitizenServicesRepository repository;

  GetCitizenServicesUseCase(this.repository);

  @override
  Future<Either<Failure, List<CitizenService>>> call(GetCitizenServicesParams params) async {
    return await repository.getServices(
      category: params.category,
      searchQuery: params.searchQuery,
    );
  }
}
