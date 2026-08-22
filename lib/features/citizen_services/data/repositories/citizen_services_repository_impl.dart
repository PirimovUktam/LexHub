import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_remote_datasource.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:lexhub/features/citizen_services/domain/repositories/citizen_services_repository.dart';

class CitizenServicesRepositoryImpl implements CitizenServicesRepository {
  final CitizenServicesRemoteDataSource remoteDataSource;
  final CitizenServicesLocalDataSource localDataSource;

  CitizenServicesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<CitizenService>>> getServices({String? category, String? searchQuery}) async {
    try {
      final services = await remoteDataSource.getServices(category: category, searchQuery: searchQuery);
      return Right(services);
    } catch (e) {
      try {
        final localServices = await localDataSource.getServices(category: category, searchQuery: searchQuery);
        return Right(localServices);
      } catch (localError) {
        return Left(ServerFailure(message: "Davlat xizmatlari ro'yxatini yuklab bo'lmadi: $e"));
      }
    }
  }

  @override
  Future<Either<Failure, CitizenService>> getServiceById(String serviceId) async {
    try {
      final service = await remoteDataSource.getServiceById(serviceId);
      return Right(service);
    } catch (e) {
      try {
        final localService = await localDataSource.getServiceById(serviceId);
        return Right(localService);
      } catch (localError) {
        return Left(ServerFailure(message: "Xizmat ma'lumotlarini yuklab bo'lmadi: $e"));
      }
    }
  }
}
