import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application_cooldown.dart';
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

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const LegalExpertsError(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
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

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  /// SOVUTISH DAVRI MA'LUMOTI — faqat `FailureCode.applicationCooldown`
  /// holatida to'ldiriladi. Ilgari sabab va vaqt server MATNI ichida edi,
  /// ya'ni ingliz UI'da YO'QOLARDI; endi UI shablonni o'z tilida quradi
  /// (`20260830070000_expert_cooldown_machine_readable.sql`).
  /// `null` = server tuzilgan ma'lumot bermadi (eski server versiyasi yoki
  /// boshqa xato) -> UI umumiy sovutish matnini ko'rsatadi.
  final ExpertApplicationCooldown? cooldown;

  const ExpertApplicationError({
    required this.message,
    this.code = FailureCode.unknown,
    this.cooldown,
  });

  @override
  List<Object?> get props => [message, code, cooldown];
}
