import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

/// Represents risk analysis, limitations, and lawyer requirements for a case
class RiskAssessment extends Equatable {
  final RiskLevel level;
  final String summary;
  final List<String> limitations;
  final bool requiresLawyer;
  final int? deadlineDays;

  const RiskAssessment({
    required this.level,
    required this.summary,
    this.limitations = const [],
    this.requiresLawyer = false,
    this.deadlineDays,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    RiskLevel parseLevel(dynamic raw) {
      if (raw == null) return RiskLevel.low;
      final str = raw.toString().toLowerCase();
      if (str.contains('critical')) return RiskLevel.critical;
      if (str.contains('high')) return RiskLevel.high;
      if (str.contains('medium')) return RiskLevel.medium;
      return RiskLevel.low;
    }

    final rawLimitations = json['limitations'];
    List<String> limitationsList = [];
    if (rawLimitations is List) {
      limitationsList = rawLimitations.map((e) => e.toString()).toList();
    }

    return RiskAssessment(
      level: parseLevel(json['level']),
      summary: json['summary'] as String? ?? '',
      limitations: limitationsList,
      requiresLawyer: json['requires_lawyer'] as bool? ?? json['requiresLawyer'] as bool? ?? false,
      deadlineDays: json['deadline_days'] as int? ?? json['deadlineDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'summary': summary,
      'limitations': limitations,
      'requires_lawyer': requiresLawyer,
      'deadline_days': deadlineDays,
    };
  }

  RiskAssessment copyWith({
    RiskLevel? level,
    String? summary,
    List<String>? limitations,
    bool? requiresLawyer,
    int? deadlineDays,
  }) {
    return RiskAssessment(
      level: level ?? this.level,
      summary: summary ?? this.summary,
      limitations: limitations ?? this.limitations,
      requiresLawyer: requiresLawyer ?? this.requiresLawyer,
      deadlineDays: deadlineDays ?? this.deadlineDays,
    );
  }

  @override
  List<Object?> get props => [
        level,
        summary,
        limitations,
        requiresLawyer,
        deadlineDays,
      ];
}
