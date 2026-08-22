import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';

// Events
abstract class SavedCasesEvent extends Equatable {
  const SavedCasesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSavedCasesEvent extends SavedCasesEvent {
  const LoadSavedCasesEvent();
}

class DeleteSavedCaseItemEvent extends SavedCasesEvent {
  final String id;

  const DeleteSavedCaseItemEvent(this.id);

  @override
  List<Object?> get props => [id];
}

// States
abstract class SavedCasesState extends Equatable {
  const SavedCasesState();

  @override
  List<Object?> get props => [];
}

class SavedCasesInitial extends SavedCasesState {}

class SavedCasesLoading extends SavedCasesState {}

class SavedCasesLoaded extends SavedCasesState {
  final List<LegalResponse> cases;

  const SavedCasesLoaded(this.cases);

  @override
  List<Object?> get props => [cases];
}

class SavedCasesError extends SavedCasesState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const SavedCasesError(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}

// Bloc
class SavedCasesBloc extends Bloc<SavedCasesEvent, SavedCasesState> {
  final GetSavedCasesUseCase getSavedCasesUseCase;
  final DeleteSavedCaseUseCase deleteSavedCaseUseCase;

  SavedCasesBloc({
    required this.getSavedCasesUseCase,
    required this.deleteSavedCaseUseCase,
  }) : super(SavedCasesInitial()) {
    on<LoadSavedCasesEvent>(_onLoadSavedCases);
    on<DeleteSavedCaseItemEvent>(_onDeleteSavedCaseItem);
  }

  Future<void> _onLoadSavedCases(
    LoadSavedCasesEvent event,
    Emitter<SavedCasesState> emit,
  ) async {
    emit(SavedCasesLoading());
    final result = await getSavedCasesUseCase(const NoParams());
    result.fold(
      (failure) => emit(SavedCasesError(failure.message, code: failure.code)),
      (cases) => emit(SavedCasesLoaded(cases)),
    );
  }

  Future<void> _onDeleteSavedCaseItem(
    DeleteSavedCaseItemEvent event,
    Emitter<SavedCasesState> emit,
  ) async {
    final result = await deleteSavedCaseUseCase(event.id);
    result.fold(
      (failure) => emit(SavedCasesError(failure.message, code: failure.code)),
      (_) => add(const LoadSavedCasesEvent()),
    );
  }
}
