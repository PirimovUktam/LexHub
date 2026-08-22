import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';

abstract class SearchRepository {
  /// Performs global unified search across laws, experts, services, templates, and questions.
  Future<Either<Failure, List<SearchResultItem>>> search({
    required String query,
    SearchResultType filterType = SearchResultType.all,
    int limit = 20,
    int offset = 0,
  });

  /// Fetches recent search history keywords.
  Future<Either<Failure, List<String>>> getRecentSearches();

  /// Adds a query to search history.
  Future<Either<Failure, void>> saveRecentSearch(String query);

  /// Clears recent search history.
  Future<Either<Failure, void>> clearRecentSearches();
}
