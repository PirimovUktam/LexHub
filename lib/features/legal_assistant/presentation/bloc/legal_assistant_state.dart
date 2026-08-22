import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

abstract class LegalAssistantState extends Equatable {
  final EmergencyProtocol? liveEmergencyWarning;

  const LegalAssistantState({this.liveEmergencyWarning});

  @override
  List<Object?> get props => [liveEmergencyWarning];
}

/// Initial clean state
class LegalAssistantInitial extends LegalAssistantState {
  const LegalAssistantInitial({super.liveEmergencyWarning});
}

/// Loading state with dynamic status stage
class LegalAssistantLoading extends LegalAssistantState {
  final String stage;

  const LegalAssistantLoading({
    this.stage = "Yuridik tahlil amalga oshirilmoqda...",
    super.liveEmergencyWarning,
  });

  @override
  List<Object?> get props => [stage, liveEmergencyWarning];
}

/// Success state with full Dual-Layer Response
class LegalAssistantSuccess extends LegalAssistantState {
  final LegalResponse response;
  final bool isSaved;

  const LegalAssistantSuccess({
    required this.response,
    this.isSaved = false,
    super.liveEmergencyWarning,
  });

  LegalAssistantSuccess copyWith({
    LegalResponse? response,
    bool? isSaved,
    EmergencyProtocol? liveEmergencyWarning,
  }) {
    return LegalAssistantSuccess(
      response: response ?? this.response,
      isSaved: isSaved ?? this.isSaved,
      liveEmergencyWarning: liveEmergencyWarning ?? this.liveEmergencyWarning,
    );
  }

  @override
  List<Object?> get props => [response, isSaved, liveEmergencyWarning];
}

/// Emergency Red Flag state triggered instantly
class LegalAssistantEmergency extends LegalAssistantState {
  final EmergencyProtocol protocol;
  final String queryText;

  const LegalAssistantEmergency({
    required this.protocol,
    required this.queryText,
  }) : super(liveEmergencyWarning: protocol);

  @override
  List<Object?> get props => [protocol, queryText, liveEmergencyWarning];
}

/// Failure / Error state
class LegalAssistantError extends LegalAssistantState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const LegalAssistantError({
    required this.message,
    this.code = FailureCode.unknown,
    super.liveEmergencyWarning,
  });

  @override
  List<Object?> get props => [message, code, liveEmergencyWarning];
}
