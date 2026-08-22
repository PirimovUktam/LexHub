import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';

abstract class LegalExpertsState extends Equatable {
  const LegalExpertsState();

  @override
  List<Object?> get props => [];
}

class LegalExpertsInitial extends LegalExpertsState {}

class LegalExpertsLoading extends LegalExpertsState {}

class LegalExpertsLoaded extends LegalExpertsState {
  final List<LegalExpert> experts;
  final String? selectedSpecialization;
  final String? selectedCity;
  final String searchQuery;

  const LegalExpertsLoaded({
    required this.experts,
    this.selectedSpecialization,
    this.selectedCity,
    this.searchQuery = '',
  });

  LegalExpertsLoaded copyWith({
    List<LegalExpert>? experts,
    String? selectedSpecialization,
    bool clearSpecialization = false,
    String? selectedCity,
    bool clearCity = false,
    String? searchQuery,
  }) {
    return LegalExpertsLoaded(
      experts: experts ?? this.experts,
      selectedSpecialization: clearSpecialization
          ? null
          : (selectedSpecialization ?? this.selectedSpecialization),
      selectedCity:
          clearCity ? null : (selectedCity ?? this.selectedCity),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        experts,
        selectedSpecialization,
        selectedCity,
        searchQuery,
      ];
}

class LegalExpertsError extends LegalExpertsState {
  final String message;

  const LegalExpertsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ExpertApplicationSubmitting extends LegalExpertsState {}

class ExpertApplicationSuccess extends LegalExpertsState {
  final String message;

  const ExpertApplicationSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class ExpertApplicationError extends LegalExpertsState {
  final String message;

  const ExpertApplicationError({required this.message});

  @override
  List<Object?> get props => [message];
}
