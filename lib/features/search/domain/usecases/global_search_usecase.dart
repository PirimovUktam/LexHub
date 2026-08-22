import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/features/search/domain/repositories/search_repository.dart';

class GlobalSearchParams {
  final String query;
  final SearchResultType filterType;
  final int limit;
  final int offset;

  const GlobalSearchParams({
    required this.query,
    this.filterType = SearchResultType.all,
    this.limit = 20,
    this.offset = 0,
  });
}

class GlobalSearchUseCase {
  final SearchRepository repository;

  GlobalSearchUseCase(this.repository);

  Future<Either<Failure, List<SearchResultItem>>> call(GlobalSearchParams params) {
    return repository.search(
      query: params.query,
      filterType: params.filterType,
      limit: params.limit,
      offset: params.offset,
    );
  }

  Future<Either<Failure, List<String>>> getRecentSearches() {
    return repository.getRecentSearches();
  }

  Future<Either<Failure, void>> saveRecentSearch(String query) {
    return repository.saveRecentSearch(query);
  }

  Future<Either<Failure, void>> clearRecentSearches() {
    return repository.clearRecentSearches();
  }
}
