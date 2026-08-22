import 'package:equatable/equatable.dart';

abstract class LegalExpertsEvent extends Equatable {
  const LegalExpertsEvent();

  @override
  List<Object?> get props => [];
}

class LoadLegalExpertsEvent extends LegalExpertsEvent {
  final String? specialization;
  final String? city;
  final String? searchQuery;

  const LoadLegalExpertsEvent({
    this.specialization,
    this.city,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [specialization, city, searchQuery];
}

class FilterSpecializationEvent extends LegalExpertsEvent {
  final String? specialization;

  const FilterSpecializationEvent(this.specialization);

  @override
  List<Object?> get props => [specialization];
}

class FilterCityEvent extends LegalExpertsEvent {
  final String? city;

  const FilterCityEvent(this.city);

  @override
  List<Object?> get props => [city];
}

class SearchLegalExpertsEvent extends LegalExpertsEvent {
  final String query;

  const SearchLegalExpertsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class SubmitExpertApplicationEvent extends LegalExpertsEvent {
  final String specialization;
  final int experienceYears;
  final String licenseNumber;
  final String? licenseDocumentUrl;
  final String? workplace;
  final String? education;
  final double consultationFee;

  const SubmitExpertApplicationEvent({
    required this.specialization,
    required this.experienceYears,
    required this.licenseNumber,
    this.licenseDocumentUrl,
    this.workplace,
    this.education,
    this.consultationFee = 0.0,
  });

  @override
  List<Object?> get props => [
        specialization,
        experienceYears,
        licenseNumber,
        licenseDocumentUrl,
        workplace,
        education,
        consultationFee,
      ];
}
