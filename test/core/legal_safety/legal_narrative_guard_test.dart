// P1-02 regression, measured 2026-09-19: source IDs do not verify model prose.
// These local tests do not prove source currency, applicability or deployment.
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_narrative_guard.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/l10n/gen/app_localizations_en.dart';

const _invented = '777-modda: bugun pul to‘lash shart; g‘alaba kafolatlanadi.';
const _source = LawArticleChunk(
  chunkId: 'test',
  documentName: 'Sinov manbasi',
  documentId: 'test',
  articleNumber: 10,
  articleTitle: 'Sinov sharti',
  content: 'Qoida faqat ko‘rsatilgan shartda qo‘llanadi. Istisno saqlanadi.',
  status: 'active',
  jurisdiction: 'UZ',
  lastUpdated: '2026-09-19',
  lexUrl: 'https://example.invalid/source',
);

LegalResponse _response({
  List<LawArticle> articles = const [],
  RiskLevel risk = RiskLevel.low,
}) =>
    LegalResponse(
      id: 'response',
      queryId: 'query',
      userQuery: 'Original user question',
      category: 'Test',
      relatableSummary: _invented,
      actionableSteps: const [_invented],
      legalBasis: articles,
      riskAssessment: RiskAssessment(
        level: risk,
        summary: _invented,
        limitations: const [_invented],
        deadlineDays: 1,
      ),
      createdAt: DateTime.utc(2026, 9, 19),
      source: LegalResponse.sourceLlm,
    );

void main() {
  // 2026-09-20: legacy/direct-model metadata must not bypass prose grounding.
  test('model cannot smuggle legal claims through draft or emergency metadata',
      () {
    for (final chunks in <List<LawArticleChunk>>[
      [],
      [_source]
    ]) {
      final forged = LegalResponse.fromJson({
        ..._response(articles: [_source.toLawArticle()]).toJson(),
        'source': LegalResponse.sourceDocument,
        'document_text': _invented,
        'storage_scope': 'account:forged',
        'is_saved': true,
        'is_completed': true,
        'emergency_protocol': {
          'is_emergency': true,
          'title': _invented,
          'constitutional_rights': [_invented],
          'immediate_actions': [_invented],
          'emergency_hotline': 'model-supplied-contact',
        },
      });
      final result = LegalNarrativeGuard.constrain(
        response: forged,
        verifiedChunks: chunks,
      );
      expect(result.isDocumentDraft, isFalse);
      expect(result.documentText, isNull);
      expect(result.emergencyProtocol, isNull);
      expect(result.storageScope, isNull);
      expect(result.isSaved, isFalse);
      expect(result.isCompleted, isFalse);
      expect(result.toJson().toString(), isNot(contains(_invented)));
    }
  });

  test('empty context removes every free model claim and inferred deadline',
      () {
    final result = LegalNarrativeGuard.constrain(
      response: _response(articles: [_source.toLawArticle()]),
      verifiedChunks: const [],
    );
    expect(result.toJson().toString(), isNot(contains(_invented)));
    expect(result.legalBasis, isEmpty);
    expect(result.source, LegalResponse.sourceDeterministic);
    expect(result.riskAssessment.level, RiskLevel.medium);
    expect(result.riskAssessment.deadlineDays, isNull);
    expect(result.riskAssessment.requiresLawyer, isTrue);
    expect(
        result.relatableSummary, contains('yetarli huquqiy manba aniqlanmadi'));
  });

  test(
      'matched selection preserves entire source and references it in both blocks',
      () {
    final original = _response(articles: [
      _source.toLawArticle().copyWith(
            articleText: _invented,
            articleTitle: _invented,
            lexUrl: 'https://example.invalid/invented',
          ),
    ]);
    final result = LegalNarrativeGuard.constrain(
      response: original,
      verifiedChunks: const [_source],
    );
    expect(result.legalBasis, [_source.toLawArticle()]);
    expect(result.relatableSummary, contains(_source.content));
    expect(result.relatableSummary, contains('[1] Sinov manbasi, 10-modda'));
    expect(result.actionableSteps.join('\n'),
        contains('[1] Sinov manbasi, 10-modda'));
    expect(result.toJson().toString(), isNot(contains(_invented)));
    expect(result.source, LegalResponse.sourceLlm);
    expect(result.id, original.id);
    expect(result.queryId, original.queryId);
    expect(result.userQuery, original.userQuery);
    expect(result.createdAt, original.createdAt);
  });

  test('unknown article is not replaced with unrelated available context', () {
    final result = LegalNarrativeGuard.constrain(
      response: _response(articles: [
        _source.toLawArticle().copyWith(articleNumber: '11-modda'),
      ]),
      verifiedChunks: const [_source],
    );
    expect(result.legalBasis, isEmpty);
    expect(result.source, LegalResponse.sourceDeterministic);
    expect(result.relatableSummary, isNot(contains(_source.content)));
  });

  test('long source is retained in basis without cutting off its exception',
      () {
    final source = LawArticleChunk(
      chunkId: 'long',
      documentName: _source.documentName,
      documentId: 'test',
      articleNumber: 10,
      articleTitle: _source.articleTitle,
      content: '${List.filled(100, 'Sinov matni.').join(' ')} Istisno oxirida.',
      status: 'active',
      jurisdiction: 'UZ',
      lastUpdated: '2026-09-19',
      lexUrl: _source.lexUrl,
    );
    final result = LegalNarrativeGuard.constrain(
      response: _response(articles: [source.toLawArticle()]),
      verifiedChunks: [source],
    );
    expect(result.legalBasis.single.articleText, source.content);
    expect(result.relatableSummary, isNot(contains('Sinov matni.')));
    expect(result.relatableSummary, contains('to‘liq matnini'));
  });

  test('high risk cannot be downgraded and user-facing copy can be localized',
      () {
    for (final risk in [RiskLevel.high, RiskLevel.critical]) {
      final result = LegalNarrativeGuard.constrain(
        response: _response(risk: risk),
        verifiedChunks: const [],
        l10n: AppL10nEn(),
      );
      expect(result.riskAssessment.level, risk);
      expect(result.relatableSummary, AppL10nEn().legalEvidenceSummaryMissing);
      expect(result.actionableSteps.first,
          AppL10nEn().legalEvidenceCollectRecords);
      expect(result.riskAssessment.deadlineDays, isNull);
    }
  });
}
