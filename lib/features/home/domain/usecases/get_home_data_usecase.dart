import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/home/domain/repositories/home_repository.dart';

class HomeDataBundle extends Equatable {
  final List<LegalCategory> categories;
  final List<SeedQuestionModel> trendingQuestions;

  const HomeDataBundle({
    required this.categories,
    required this.trendingQuestions,
  });

  @override
  List<Object?> get props => [categories, trendingQuestions];
}

class GetHomeDataUseCase implements UseCase<HomeDataBundle, NoParams> {
  final HomeRepository repository;

  GetHomeDataUseCase(this.repository);

  @override
  Future<Either<Failure, HomeDataBundle>> call(NoParams params) async {
    final categoriesResult = await repository.getCategories();
    final questionsResult = await repository.getSeedQuestions();

    return categoriesResult.fold(
      (failure) => Left(failure),
      (categories) => questionsResult.fold(
        (failure) => Left(failure),
        (questions) => Right(
          HomeDataBundle(
            categories: categories,
            trendingQuestions: questions,
          ),
        ),
      ),
    );
  }
}

class FilterSeedQuestionsUseCase implements UseCase<List<SeedQuestionModel>, String?> {
  final HomeRepository repository;

  FilterSeedQuestionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> call(String? categoryId) async {
    return await repository.getSeedQuestions(categoryId: categoryId);
  }
}

class SearchSeedQuestionsUseCase implements UseCase<List<SeedQuestionModel>, String> {
  final HomeRepository repository;

  SearchSeedQuestionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<SeedQuestionModel>>> call(String query) async {
    return await repository.searchSeedQuestions(query);
  }
}
