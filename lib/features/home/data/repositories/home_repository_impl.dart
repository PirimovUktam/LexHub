import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/home/data/datasources/home_local_datasource.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeLocalDataSource localDataSource;

  HomeRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<LegalCategory>>> getCategories() async {
    try {
      final categories = await localDataSource.getCategories();
      return Right(categories);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> getSeedQuestions({String? categoryId}) async {
    try {
      final questions = await localDataSource.getSeedQuestions(categoryId: categoryId);
      return Right(questions);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> searchSeedQuestions(String query) async {
    try {
      final questions = await localDataSource.searchSeedQuestions(query);
      return Right(questions);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
