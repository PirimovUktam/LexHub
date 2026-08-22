import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/detect_emergency_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/get_legal_advice_usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_event.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_state.dart';
import 'package:uuid/uuid.dart';

class LegalAssistantBloc extends Bloc<LegalAssistantEvent, LegalAssistantState> {
  final GetLegalAdviceUseCase getLegalAdviceUseCase;
  final DetectEmergencyUseCase detectEmergencyUseCase;
  final SaveCaseUseCase saveCaseUseCase;
  final DeleteSavedCaseUseCase deleteSavedCaseUseCase;

  LegalAssistantBloc({
    required this.getLegalAdviceUseCase,
    required this.detectEmergencyUseCase,
    required this.saveCaseUseCase,
    required this.deleteSavedCaseUseCase,
  }) : super(const LegalAssistantInitial()) {
    on<SubmitLegalQueryEvent>(_onSubmitLegalQuery);
    on<CheckEmergencyTextEvent>(_onCheckEmergencyText);
    on<ToggleSaveCaseEvent>(_onToggleSaveCase);
    on<ResetLegalQueryEvent>(_onResetLegalQuery);
  }

  Future<void> _onSubmitLegalQuery(
    SubmitLegalQueryEvent event,
    Emitter<LegalAssistantState> emit,
  ) async {
    final liveWarning = state.liveEmergencyWarning;

    emit(LegalAssistantLoading(
      stage: "Qonunchilik normalari va Lex.uz bazasi tahlil qilinmoqda...",
      liveEmergencyWarning: liveWarning,
    ));

    final queryId = const Uuid().v4();
    final result = await getLegalAdviceUseCase(
      GetLegalAdviceParams(
        id: queryId,
        queryText: event.queryText,
        category: event.category,
      ),
    );

    final category = (event.category != null && event.category!.trim().isNotEmpty)
        ? event.category!
        : "Umumiy huquq";

    if (result.isLeft()) {
      final failure = result.fold((l) => l, (r) => null)!;
      emit(LegalAssistantError(
        message: failure.message,
        code: failure.code,
        liveEmergencyWarning: liveWarning,
      ));
      return;
    }

    final response = result.fold((l) => null, (r) => r)!;
    final enrichedResponse = response.copyWith(
      id: response.id.isNotEmpty ? response.id : queryId,
      userQuery: event.queryText,
      category: category,
      isSaved: true,
    );

    // Auto-save pipeline: persist directly to local Hive storage
    await saveCaseUseCase(enrichedResponse);

    if (enrichedResponse.emergencyProtocol != null &&
        enrichedResponse.emergencyProtocol!.isEmergency) {
      emit(LegalAssistantEmergency(
        protocol: enrichedResponse.emergencyProtocol!,
        queryText: event.queryText,
      ));
    }

    emit(LegalAssistantSuccess(
      response: enrichedResponse,
      isSaved: true,
      liveEmergencyWarning: liveWarning,
    ));
  }

  Future<void> _onCheckEmergencyText(
    CheckEmergencyTextEvent event,
    Emitter<LegalAssistantState> emit,
  ) async {
    if (event.queryText.trim().isEmpty) {
      _emitStateWithWarning(emit, null);
      return;
    }

    final result = await detectEmergencyUseCase(event.queryText);
    result.fold(
      (_) => null,
      (emergency) {
        _emitStateWithWarning(emit, emergency);
      },
    );
  }

  void _emitStateWithWarning(
    Emitter<LegalAssistantState> emit,
    EmergencyProtocol? warning,
  ) {
    if (state is LegalAssistantSuccess) {
      final s = state as LegalAssistantSuccess;
      emit(s.copyWith(liveEmergencyWarning: warning));
    } else if (state is LegalAssistantLoading) {
      final s = state as LegalAssistantLoading;
      emit(LegalAssistantLoading(stage: s.stage, liveEmergencyWarning: warning));
    } else if (state is LegalAssistantError) {
      final s = state as LegalAssistantError;
      emit(LegalAssistantError(message: s.message, liveEmergencyWarning: warning));
    } else {
      emit(LegalAssistantInitial(liveEmergencyWarning: warning));
    }
  }

  Future<void> _onToggleSaveCase(
    ToggleSaveCaseEvent event,
    Emitter<LegalAssistantState> emit,
  ) async {
    if (state is LegalAssistantSuccess) {
      final currentSuccess = state as LegalAssistantSuccess;
      final currentlySaved = currentSuccess.isSaved;

      if (currentlySaved) {
        final res = await deleteSavedCaseUseCase(event.response.id);
        res.fold(
          (f) => emit(LegalAssistantError(message: f.message)),
          (_) => emit(currentSuccess.copyWith(isSaved: false)),
        );
      } else {
        final res = await saveCaseUseCase(event.response);
        res.fold(
          (f) => emit(LegalAssistantError(message: f.message)),
          (_) => emit(currentSuccess.copyWith(isSaved: true)),
        );
      }
    }
  }

  void _onResetLegalQuery(
    ResetLegalQueryEvent event,
    Emitter<LegalAssistantState> emit,
  ) {
    emit(const LegalAssistantInitial());
  }
}
