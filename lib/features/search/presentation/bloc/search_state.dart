import 'package:equatable/equatable.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';

enum SearchStatus { initial, loading, success, empty, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final SearchResultType selectedFilter;
  final List<SearchResultItem> results;
  final List<String> recentSearches;
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.selectedFilter = SearchResultType.all,
    this.results = const [],
    this.recentSearches = const [],
    this.errorMessage,
  });

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchResultType? selectedFilter,
    List<SearchResultItem>? results,
    List<String>? recentSearches,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        selectedFilter,
        results,
        recentSearches,
        errorMessage,
      ];
}
