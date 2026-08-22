import 'package:equatable/equatable.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class LoadSearchInitialEvent extends SearchEvent {
  const LoadSearchInitialEvent();
}

class SearchQueryChangedEvent extends SearchEvent {
  final String query;
  final SearchResultType filterType;

  const SearchQueryChangedEvent({
    required this.query,
    this.filterType = SearchResultType.all,
  });

  @override
  List<Object?> get props => [query, filterType];
}

class ChangeSearchFilterEvent extends SearchEvent {
  final SearchResultType filterType;

  const ChangeSearchFilterEvent(this.filterType);

  @override
  List<Object?> get props => [filterType];
}

class ClearSearchHistoryEvent extends SearchEvent {
  const ClearSearchHistoryEvent();
}
