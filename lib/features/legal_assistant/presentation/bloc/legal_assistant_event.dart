import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

abstract class LegalAssistantEvent extends Equatable {
  const LegalAssistantEvent();

  @override
  List<Object?> get props => [];
}

/// Request legal advice for user query
class SubmitLegalQueryEvent extends LegalAssistantEvent {
  final String queryText;
  final String? category;

  const SubmitLegalQueryEvent({
    required this.queryText,
    this.category,
  });

  @override
  List<Object?> get props => [queryText, category];
}

/// Realtime text change to detect immediate emergency red flags
class CheckEmergencyTextEvent extends LegalAssistantEvent {
  final String queryText;

  const CheckEmergencyTextEvent(this.queryText);

  @override
  List<Object?> get props => [queryText];
}

/// Toggle save / bookmark for current legal response
class ToggleSaveCaseEvent extends LegalAssistantEvent {
  final LegalResponse response;

  const ToggleSaveCaseEvent(this.response);

  @override
  List<Object?> get props => [response];
}

/// Reset to initial state
class ResetLegalQueryEvent extends LegalAssistantEvent {
  const ResetLegalQueryEvent();
}
