import 'package:equatable/equatable.dart';

abstract class CitizenServicesEvent extends Equatable {
  const CitizenServicesEvent();

  @override
  List<Object?> get props => [];
}

class LoadCitizenServicesEvent extends CitizenServicesEvent {
  final String? category;
  final String? searchQuery;

  const LoadCitizenServicesEvent({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class FilterServicesByCategoryEvent extends CitizenServicesEvent {
  final String category;

  const FilterServicesByCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class SearchCitizenServicesEvent extends CitizenServicesEvent {
  final String query;

  const SearchCitizenServicesEvent(this.query);

  @override
  List<Object?> get props => [query];
}
