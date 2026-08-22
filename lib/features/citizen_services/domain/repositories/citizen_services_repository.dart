import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

abstract class CitizenServicesRepository {
  Future<Either<Failure, List<CitizenService>>> getServices({String? category, String? searchQuery});
  Future<Either<Failure, CitizenService>> getServiceById(String serviceId);
}
