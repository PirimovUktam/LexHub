import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<LegalCategory>>> getCategories();
  Future<Either<Failure, List<SeedQuestionModel>>> getSeedQuestions({String? categoryId});
  Future<Either<Failure, List<SeedQuestionModel>>> searchSeedQuestions(String query);
}
