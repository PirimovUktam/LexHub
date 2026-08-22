import 'package:lexhub/features/citizen_services/data/models/service_step_model.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

class CitizenServiceModel extends CitizenService {
  const CitizenServiceModel({
    required super.id,
    required super.title,
    required super.category,
    required super.department,
    required super.description,
    super.costBhmPercent = 0.0,
    super.isFree = true,
    super.processingDays = 1,
    super.requiredDocuments = const [],
    super.onlineUrl,
    super.deadlineLawReference,
    super.sourceUrl,
    super.legalBasis,
    super.lastVerifiedAt,
    super.status = 'active',
    super.isPopular = false,
    super.steps = const [],
  });

  factory CitizenServiceModel.fromJson(Map<String, dynamic> json) {
    // Parse required documents array
    List<String> docs = [];
    if (json['required_documents'] != null) {
      if (json['required_documents'] is List) {
        docs = (json['required_documents'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    // Parse relational service steps
    List<ServiceStep> parsedSteps = [];
    if (json['service_steps'] != null && json['service_steps'] is List) {
      parsedSteps = (json['service_steps'] as List)
          .map((step) => ServiceStepModel.fromJson(step as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    } else if (json['steps'] != null && json['steps'] is List) {
      parsedSteps = (json['steps'] as List)
          .map((step) => ServiceStepModel.fromJson(step as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    }

    // Parse category name / category_id
    String cat = json['category'] as String? ?? '';
    if (cat.isEmpty && json['category_id'] != null) {
      final catId = json['category_id'].toString();
      switch (catId) {
        case 'traffic':
          cat = "Yo'l harakati";
          break;
        case 'labor':
          cat = "Mehnat huquqi";
          break;
        case 'family':
          cat = "Ijtimoiy himoya";
          break;
        case 'civil':
          cat = "Iste'molchi huquqi";
          break;
        case 'real_estate':
          cat = "Kadastr va Uy-joy";
          break;
        default:
          cat = catId;
      }
    }
    if (cat.isEmpty) cat = 'Umumiy xizmatlar';

    // Parse last_verified_at
    DateTime? verifiedDate;
    if (json['last_verified_at'] != null) {
      if (json['last_verified_at'] is String) {
        verifiedDate = DateTime.tryParse(json['last_verified_at'] as String);
      } else if (json['last_verified_at'] is DateTime) {
        verifiedDate = json['last_verified_at'] as DateTime;
      }
    }

    return CitizenServiceModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: cat,
      department: json['department'] as String? ?? '',
      description: json['description'] as String? ?? '',
      costBhmPercent: (json['cost_bhm_percent'] as num?)?.toDouble() ?? 0.0,
      isFree: json['is_free'] as bool? ?? ((json['cost_bhm_percent'] as num?)?.toDouble() == 0.0),
      processingDays: (json['processing_days'] as num?)?.toInt() ?? 1,
      requiredDocuments: docs,
      onlineUrl: json['online_url'] as String?,
      deadlineLawReference: json['deadline_law_reference'] as String?,
      sourceUrl: json['source_url'] as String?,
      legalBasis: json['legal_basis'] as String?,
      lastVerifiedAt: verifiedDate,
      status: json['status'] as String? ?? 'active',
      isPopular: json['is_popular'] as bool? ?? false,
      steps: parsedSteps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'department': department,
      'description': description,
      'cost_bhm_percent': costBhmPercent,
      'is_free': isFree,
      'processing_days': processingDays,
      'required_documents': requiredDocuments,
      if (onlineUrl != null) 'online_url': onlineUrl,
      if (deadlineLawReference != null) 'deadline_law_reference': deadlineLawReference,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (legalBasis != null) 'legal_basis': legalBasis,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt!.toIso8601String(),
      'status': status,
      'is_popular': isPopular,
      'steps': steps.map((s) {
        if (s is ServiceStepModel) return s.toJson();
        return ServiceStepModel(
          stepNumber: s.stepNumber,
          title: s.title,
          description: s.description,
          warningNote: s.warningNote,
          actionUrl: s.actionUrl,
          stepType: s.stepType,
        ).toJson();
      }).toList(),
    };
  }
}
