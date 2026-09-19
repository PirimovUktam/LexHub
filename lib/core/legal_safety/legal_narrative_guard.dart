import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';
import 'package:lexhub/l10n/gen/app_localizations_uz.dart';

/// Bounds proxy, direct Gemini and legacy API narratives to source selection.
/// Context matching does not establish legal currency or applicability.
class LegalNarrativeGuard {
  LegalNarrativeGuard._();

  static LegalResponse constrain({
    required LegalResponse response,
    required List<LawArticleChunk> verifiedChunks,
    AppL10n? l10n,
  }) {
    // Existing legal-answer protocol is Uzbek; UI locale is independent.
    // Strings remain in ARB, with an explicit locale available to callers.
    final text = l10n ?? AppL10nUz();
    final selected = <LawArticleChunk>[];
    for (final article in response.legalBasis) {
      final chunk = LegalGroundingValidator.findGroundingChunk(
        lawName: article.lawName,
        articleNumber: article.articleNumber,
        chunks: verifiedChunks,
      );
      if (chunk == null ||
          chunk.content.trim().isEmpty ||
          chunk.documentName.trim().isEmpty ||
          selected.contains(chunk)) {
        continue;
      }
      selected.add(chunk);
      if (selected.length == 3) break;
    }

    final articles = selected.map((chunk) => chunk.toLawArticle()).toList();
    final excerpts = <String>[];
    final sourceSteps = <String>[];
    for (var i = 0; i < articles.length; i++) {
      final article = articles[i];
      final label = '[${i + 1}] ${article.lawName}, ${article.articleNumber}';
      // Show the whole supplied excerpt or a link to the basis section;
      // a substring chosen by the model could omit a negation/exception.
      final quote = article.articleText.length <= 900
          ? '«${article.articleText}»'
          : text.legalEvidenceReadSource;
      excerpts.add('$label\n$quote');
      sourceSteps.add('$label: ${text.legalEvidenceReadSource}');
    }

    final summary = articles.isEmpty
        ? text.legalEvidenceSummaryMissing
        : '${text.legalEvidenceSummaryIntro}\n\n${excerpts.join('\n\n')}';
    final modelLevel = response.riskAssessment.level;
    return response.copyWith(
      relatableSummary: summary,
      actionableSteps: [
        text.legalEvidenceCollectRecords,
        text.legalEvidenceRecordDates,
        ...sourceSteps,
        text.legalEvidenceConsultLawyer,
      ],
      legalBasis: articles,
      riskAssessment: RiskAssessment(
        level: modelLevel.isHighOrCritical ? modelLevel : RiskLevel.medium,
        summary: text.legalEvidenceRiskUncertain,
        limitations: [
          text.legalEvidenceApplicabilityLimit,
          text.legalEvidenceDeadlineUnknown,
        ],
        requiresLawyer: true,
      ),
      source: articles.isEmpty
          ? LegalResponse.sourceDeterministic
          : response.source,
    );
  }
}
