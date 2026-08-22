import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

/// Represents dual-layer (Relatable + Credible) legal response
class LegalResponse extends Equatable {
  final String id;
  final String queryId;
  final String userQuery;
  final String category;
  final String relatableSummary;
  final List<String> actionableSteps;
  final List<LawArticle> legalBasis;
  final RiskAssessment riskAssessment;
  final EmergencyProtocol? emergencyProtocol;
  final DateTime createdAt;
  final bool isSaved;
  final bool isCompleted;

  const LegalResponse({
    required this.id,
    required this.queryId,
    this.userQuery = '',
    this.category = 'Umumiy huquq',
    required this.relatableSummary,
    this.actionableSteps = const [],
    this.legalBasis = const [],
    required this.riskAssessment,
    this.emergencyProtocol,
    required this.createdAt,
    this.isSaved = false,
    this.isCompleted = false,
  });

  factory LegalResponse.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<LawArticle> parseLawArticles(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => LawArticle.fromJson(e))
            .toList();
      }
      return [];
    }

    RiskAssessment parseRisk(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return RiskAssessment.fromJson(raw);
      }
      return const RiskAssessment(
        level: RiskLevel.low,
        summary: "Risk tahlili mavjud emas",
      );
    }

    EmergencyProtocol? parseEmergency(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return EmergencyProtocol.fromJson(raw);
      }
      return null;
    }

    final queryText = json['user_query'] as String? ??
        json['userQuery'] as String? ??
        json['query_text'] as String? ??
        json['relatable_summary'] as String? ??
        '';

    final catText = json['category'] as String? ??
        json['selected_category'] as String? ??
        'Umumiy huquq';

    return LegalResponse(
      id: json['id'] as String? ?? '',
      queryId: json['query_id'] as String? ?? json['queryId'] as String? ?? '',
      userQuery: queryText,
      category: catText,
      relatableSummary: json['relatable_summary'] as String? ??
          json['relatableSummary'] as String? ??
          '',
      actionableSteps: parseStringList(
        json['actionable_steps'] ?? json['actionableSteps'],
      ),
      legalBasis: parseLawArticles(
        json['legal_basis'] ?? json['legalBasis'],
      ),
      riskAssessment: parseRisk(
        json['risk_assessment'] ?? json['riskAssessment'],
      ),
      emergencyProtocol: parseEmergency(
        json['emergency_protocol'] ?? json['emergencyProtocol'],
      ),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isSaved: json['is_saved'] as bool? ?? json['isSaved'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query_id': queryId,
      'user_query': userQuery,
      'category': category,
      'relatable_summary': relatableSummary,
      'actionable_steps': actionableSteps,
      'legal_basis': legalBasis.map((e) => e.toJson()).toList(),
      'risk_assessment': riskAssessment.toJson(),
      'emergency_protocol': emergencyProtocol?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'is_saved': isSaved,
      'is_completed': isCompleted,
    };
  }

  LegalResponse copyWith({
    String? id,
    String? queryId,
    String? userQuery,
    String? category,
    String? relatableSummary,
    List<String>? actionableSteps,
    List<LawArticle>? legalBasis,
    RiskAssessment? riskAssessment,
    EmergencyProtocol? emergencyProtocol,
    DateTime? createdAt,
    bool? isSaved,
    bool? isCompleted,
  }) {
    return LegalResponse(
      id: id ?? this.id,
      queryId: queryId ?? this.queryId,
      userQuery: userQuery ?? this.userQuery,
      category: category ?? this.category,
      relatableSummary: relatableSummary ?? this.relatableSummary,
      actionableSteps: actionableSteps ?? this.actionableSteps,
      legalBasis: legalBasis ?? this.legalBasis,
      riskAssessment: riskAssessment ?? this.riskAssessment,
      emergencyProtocol: emergencyProtocol ?? this.emergencyProtocol,
      createdAt: createdAt ?? this.createdAt,
      isSaved: isSaved ?? this.isSaved,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        queryId,
        userQuery,
        category,
        relatableSummary,
        actionableSteps,
        legalBasis,
        riskAssessment,
        emergencyProtocol,
        createdAt,
        isSaved,
        isCompleted,
      ];
}
