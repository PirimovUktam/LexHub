import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_local_datasource.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';

class LegalAssistantRepositoryImpl implements LegalAssistantRepository {
  final LegalAssistantRemoteDataSource remoteDataSource;
  final LegalAssistantLocalDataSource localDataSource;

  LegalAssistantRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, LegalResponse>> getLegalAdvice(LegalQuery query) async {
    try {
      final response = await remoteDataSource.getLegalAdvice(query);
      return Right(response);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, EmergencyProtocol?>> detectEmergency(String queryText) async {
    try {
      final emergency = await remoteDataSource.detectEmergency(queryText);
      return Right(emergency);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, void>> saveCase(LegalResponse response) async {
    try {
      await localDataSource.saveCase(response);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<LegalResponse>>> getSavedCases() async {
    try {
      final cases = await localDataSource.getSavedCases();
      return Right(cases);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSavedCase(String id) async {
    try {
      await localDataSource.deleteSavedCase(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
