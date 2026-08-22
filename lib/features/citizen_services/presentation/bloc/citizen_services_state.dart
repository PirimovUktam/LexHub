import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

abstract class CitizenServicesState extends Equatable {
  const CitizenServicesState();

  @override
  List<Object?> get props => [];
}

class CitizenServicesInitial extends CitizenServicesState {}

class CitizenServicesLoading extends CitizenServicesState {}

class CitizenServicesLoaded extends CitizenServicesState {
  final List<CitizenService> services;
  final String selectedCategory;
  final String searchQuery;

  const CitizenServicesLoaded({
    required this.services,
    this.selectedCategory = 'Barchasi',
    this.searchQuery = '',
  });

  CitizenServicesLoaded copyWith({
    List<CitizenService>? services,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return CitizenServicesLoaded(
      services: services ?? this.services,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [services, selectedCategory, searchQuery];
}

class CitizenServicesError extends CitizenServicesState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi — UI `failureMessageFor(l10n, code)`
  /// orqali tanlangan tilda matn oladi.
  final FailureCode code;

  const CitizenServicesError(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}
