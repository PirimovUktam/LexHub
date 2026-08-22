import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';

class LegalExpertsRepositoryImpl implements LegalExpertsRepository {
  final LegalExpertsRemoteDataSource remoteDataSource;

  LegalExpertsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<LegalExpert>>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async {
    try {
      final experts = await remoteDataSource.getExperts(
        specialization: specialization,
        city: city,
        searchQuery: searchQuery,
      );
      return Right(experts);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, LegalExpert>> getExpertById(String id) async {
    try {
      final expert = await remoteDataSource.getExpertById(id);
      return Right(expert);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
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
    try {
      final result = await remoteDataSource.applyForVerification(
        specialization: specialization,
        experienceYears: experienceYears,
        licenseNumber: licenseNumber,
        licenseDocumentUrl: licenseDocumentUrl,
        workplace: workplace,
        education: education,
        consultationFee: consultationFee,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
