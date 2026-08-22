import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeDataEvent extends HomeEvent {
  const LoadHomeDataEvent();
}

class SelectCategoryFilterEvent extends HomeEvent {
  final String? categoryId;

  const SelectCategoryFilterEvent(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class SearchHomeQuestionsEvent extends HomeEvent {
  final String query;

  const SearchHomeQuestionsEvent(this.query);

  @override
  List<Object?> get props => [query];
}
