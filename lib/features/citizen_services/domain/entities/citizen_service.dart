import 'package:equatable/equatable.dart';

class ServiceStep extends Equatable {
  final int stepNumber;
  final String title;
  final String description;
  final String? warningNote;
  final String? actionUrl;
  final String stepType; // 'online', 'offline', 'payment', 'appeal'

  const ServiceStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.warningNote,
    this.actionUrl,
    this.stepType = 'online',
  });

  @override
  List<Object?> get props => [
        stepNumber,
        title,
        description,
        warningNote,
        actionUrl,
        stepType,
      ];
}

class CitizenService extends Equatable {
  final String id;
  final String title;
  final String category;
  final String department; // e.g., 'Ichki Ishlar Vazirligi', 'Adliya Vazirligi', 'Soliq Qo'mitasi'
  final String description;
  final double costBhmPercent; // Percent of BHM (e.g. 0.1 for 10% BHM)
  final bool isFree;
  final int processingDays;
  final List<String> requiredDocuments;
  final String? onlineUrl; // my.gov.uz / custom link
  final String? deadlineLawReference;
  final String? sourceUrl; // Lex.uz official decree URL
  final String? legalBasis; // E.g. 'O‘zbekiston Respublikasi MJtK 332-1-moddasi'
  final DateTime? lastVerifiedAt;
  final String status; // 'active', 'updated', 'archived'
  final bool isPopular;
  final List<ServiceStep> steps;

  const CitizenService({
    required this.id,
    required this.title,
    required this.category,
    required this.department,
    required this.description,
    this.costBhmPercent = 0.0,
    this.isFree = true,
    this.processingDays = 1,
    this.requiredDocuments = const [],
    this.onlineUrl,
    this.deadlineLawReference,
    this.sourceUrl,
    this.legalBasis,
    this.lastVerifiedAt,
    this.status = 'active',
    this.isPopular = false,
    this.steps = const [],
  });

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        department,
        description,
        costBhmPercent,
        isFree,
        processingDays,
        requiredDocuments,
        onlineUrl,
        deadlineLawReference,
        sourceUrl,
        legalBasis,
        lastVerifiedAt,
        status,
        isPopular,
        steps,
      ];
}
