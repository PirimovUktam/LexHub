import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';
import 'package:lexhub/l10n/gen/app_localizations_uz.dart';

/// Risk Matrix Evaluator to prevent false confidence and evaluate realistic litigation outcomes
class RiskMatrixEvaluator {
  RiskMatrixEvaluator._();

  /// Evaluates risk profile based on case context, presence of written evidence, and procedural complexity
  static RiskAssessment evaluate({
    required String queryText,
    required bool? hasWrittenEvidence,
    required bool isEmergency,
    AppL10n? l10n,
  }) {
    final text = l10n ?? AppL10nUz();
    if (isEmergency) {
      return RiskAssessment(
        level: RiskLevel.critical,
        summary: text.legalRiskEmergency,
        limitations: [
          text.legalEvidenceApplicabilityLimit,
          text.legalEvidenceDeadlineUnknown,
        ],
        requiresLawyer: true,
      );
    }

    final lower = queryText.toLowerCase();

    // High Risk: Criminal or heavy disputes without documentation
    if (lower.contains('jinoyat') ||
        lower.contains('tergov') ||
        (hasWrittenEvidence != true &&
            (lower.contains('qarz') || lower.contains('shartnoma')))) {
      return RiskAssessment(
        level: RiskLevel.high,
        summary: text.legalRiskHigh,
        limitations: [
          if (hasWrittenEvidence == null)
            text.legalRiskEvidenceUnknown
          else if (!hasWrittenEvidence)
            text.legalRiskEvidenceAbsent,
          text.legalEvidenceApplicabilityLimit,
        ],
        requiresLawyer: true,
      );
    }

    // Medium Risk: Labor or family disputes
    if (lower.contains('ishdan') ||
        lower.contains('maosh') ||
        lower.contains('mulk') ||
        lower.contains('mehnat') ||
        lower.contains('ish haqi')) {
      return RiskAssessment(
        level: RiskLevel.medium,
        summary: text.legalRiskContextIncomplete,
        limitations: [
          text.legalEvidenceDeadlineUnknown,
        ],
        requiresLawyer: true,
      );
    }

    // Low Risk: Standard consumer rights or civil queries
    return RiskAssessment(
      level: RiskLevel.low,
      summary: text.legalRiskNoHighSignal,
      limitations: [
        text.legalEvidenceApplicabilityLimit,
        text.legalEvidenceDeadlineUnknown,
      ],
      requiresLawyer: false,
    );
  }
}
