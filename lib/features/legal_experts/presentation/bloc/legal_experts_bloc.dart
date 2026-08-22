import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/apply_expert_verification_usecase.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_legal_experts_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_state.dart';

class LegalExpertsBloc extends Bloc<LegalExpertsEvent, LegalExpertsState> {
  final GetLegalExpertsUseCase getLegalExpertsUseCase;
  final ApplyExpertVerificationUseCase? applyExpertVerificationUseCase;

  LegalExpertsBloc({
    required this.getLegalExpertsUseCase,
    this.applyExpertVerificationUseCase,
  }) : super(LegalExpertsInitial()) {
    on<LoadLegalExpertsEvent>(_onLoadLegalExperts);
    on<FilterSpecializationEvent>(_onFilterSpecialization);
    on<FilterCityEvent>(_onFilterCity);
    on<SearchLegalExpertsEvent>(_onSearchLegalExperts);
    on<SubmitExpertApplicationEvent>(_onSubmitExpertApplication);
  }

  Future<void> _onLoadLegalExperts(
    LoadLegalExpertsEvent event,
    Emitter<LegalExpertsState> emit,
  ) async {
    emit(LegalExpertsLoading());
    final result = await getLegalExpertsUseCase(GetLegalExpertsParams(
      specialization: event.specialization,
      city: event.city,
      searchQuery: event.searchQuery,
    ));

    result.fold(
      (failure) => emit(LegalExpertsError(failure.message)),
      (experts) => emit(LegalExpertsLoaded(
        experts: experts,
        selectedSpecialization: event.specialization,
        selectedCity: event.city,
        searchQuery: event.searchQuery ?? '',
      )),
    );
  }

  Future<void> _onFilterSpecialization(
    FilterSpecializationEvent event,
    Emitter<LegalExpertsState> emit,
  ) async {
    if (state is LegalExpertsLoaded) {
      final current = state as LegalExpertsLoaded;
      final newSpec = current.selectedSpecialization == event.specialization
          ? null
          : event.specialization;

      final result = await getLegalExpertsUseCase(GetLegalExpertsParams(
        specialization: newSpec,
        city: current.selectedCity,
        searchQuery: current.searchQuery,
      ));

      result.fold(
        (failure) => emit(LegalExpertsError(failure.message)),
        (experts) => emit(current.copyWith(
          experts: experts,
          selectedSpecialization: newSpec,
          clearSpecialization: newSpec == null,
        )),
      );
    }
  }

  Future<void> _onFilterCity(
    FilterCityEvent event,
    Emitter<LegalExpertsState> emit,
  ) async {
    if (state is LegalExpertsLoaded) {
      final current = state as LegalExpertsLoaded;
      final newCity = current.selectedCity == event.city ? null : event.city;

      final result = await getLegalExpertsUseCase(GetLegalExpertsParams(
        specialization: current.selectedSpecialization,
        city: newCity,
        searchQuery: current.searchQuery,
      ));

      result.fold(
        (failure) => emit(LegalExpertsError(failure.message)),
        (experts) => emit(current.copyWith(
          experts: experts,
          selectedCity: newCity,
          clearCity: newCity == null,
        )),
      );
    }
  }

  Future<void> _onSearchLegalExperts(
    SearchLegalExpertsEvent event,
    Emitter<LegalExpertsState> emit,
  ) async {
    if (state is LegalExpertsLoaded) {
      final current = state as LegalExpertsLoaded;

      final result = await getLegalExpertsUseCase(GetLegalExpertsParams(
        specialization: current.selectedSpecialization,
        city: current.selectedCity,
        searchQuery: event.query,
      ));

      result.fold(
        (failure) => emit(LegalExpertsError(failure.message)),
        (experts) => emit(current.copyWith(
          experts: experts,
          searchQuery: event.query,
        )),
      );
    }
  }

  Future<void> _onSubmitExpertApplication(
    SubmitExpertApplicationEvent event,
    Emitter<LegalExpertsState> emit,
  ) async {
    if (applyExpertVerificationUseCase == null) return;

    emit(ExpertApplicationSubmitting());
    final result = await applyExpertVerificationUseCase!(
      ApplyExpertVerificationParams(
        specialization: event.specialization,
        experienceYears: event.experienceYears,
        licenseNumber: event.licenseNumber,
        licenseDocumentUrl: event.licenseDocumentUrl,
        workplace: event.workplace,
        education: event.education,
        consultationFee: event.consultationFee,
      ),
    );

    result.fold(
      (failure) => emit(ExpertApplicationError(message: failure.message)),
      (data) {
        final msg = data['message'] as String? ?? "Ariza muvaffaqiyatli topshirildi.";
        emit(ExpertApplicationSuccess(message: msg));
      },
    );
  }
}
