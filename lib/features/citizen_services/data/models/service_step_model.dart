import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

class ServiceStepModel extends ServiceStep {
  const ServiceStepModel({
    required super.stepNumber,
    required super.title,
    required super.description,
    super.warningNote,
    super.actionUrl,
    super.stepType = 'online',
  });

  factory ServiceStepModel.fromJson(Map<String, dynamic> json) {
    return ServiceStepModel(
      stepNumber: json['step_number'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      warningNote: json['warning_note'] as String?,
      actionUrl: json['action_url'] as String?,
      stepType: json['step_type'] as String? ?? 'online',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step_number': stepNumber,
      'title': title,
      'description': description,
      if (warningNote != null) 'warning_note': warningNote,
      if (actionUrl != null) 'action_url': actionUrl,
      'step_type': stepType,
    };
  }
}
