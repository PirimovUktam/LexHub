// Guards the audited 560/27/28/29 citation, invented deadline and risk downgrade
// defects (2026-09-19). Local runtime checks; not a production deployment proof.
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/deadlines_guard.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/risk_matrix_evaluator.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/core/network/gemini_legal_service.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

LegalQuery _query(String text) => LegalQuery(
      id: 'legal-regression',
      queryText: text,
      createdAt: DateTime.utc(2026, 9, 19),
    );

class _CriticalGemini extends GeminiLegalService {
  @override
  Future<LegalResponse?> generateLegalAdvice({
    required LegalQuery query,
    required String sanitizedQuery,
    required List<LawArticleChunk> contextChunks,
  }) async =>
      LegalResponse(
        id: 'critical-model-response',
        queryId: query.id,
        relatableSummary: 'Unverified model prose',
        legalBasis: contextChunks.map((chunk) => chunk.toLawArticle()).toList(),
        riskAssessment: const RiskAssessment(
          level: RiskLevel.critical,
          summary: 'Unverified risk prose',
          requiresLawyer: true,
          deadlineDays: 7,
        ),
        createdAt: query.createdAt,
        source: LegalResponse.sourceLlm,
      );
}

void main() {
  test('reinstatement template cites 561, not unrelated part-time article 437',
      () async {
    final template = await DocumentTemplatesLocalDataSourceImpl()
        .getTemplateById('template_labor_complaint');
    expect(
        template.legalBasisSummary, 'Mehnat kodeksi 161, 560, 561-moddalari');
    expect(template.templateText, contains('161, 560 va 561-moddalariga'));
    expect(template.sourceUrl, 'https://lex.uz/docs/6257288#6269151');
  });

  test('local labor service uses delivery date and three calendar months',
      () async {
    final service = await CitizenServicesLocalDataSourceImpl()
        .getServiceById('service_labor_complaint');
    expect(service.deadlineLawReference, contains('uch oy'));
    expect(service.sourceUrl, 'https://lex.uz/docs/6257288#6269139');
    final appeal = service.steps.where((step) => step.stepNumber == 3).toList();
    expect(appeal, hasLength(1));
    expect(appeal[0].description, contains('topshirilgan kundan'));
    expect(appeal[0].description, contains('uch oy'));
    expect(appeal[0].warningNote, isNot(contains('1 oy')));
  });

  test('560 uses three calendar months and the official article anchor', () {
    final chunks = UzbekLegalKnowledgeBase.verifiedLawChunks
        .where((chunk) => chunk.chunkId == 'labor_art_560')
        .toList();
    expect(chunks, hasLength(1));
    final article = chunks[0];
    expect(article.content, contains('uch oy'));
    expect(article.content, contains('olti oy'));
    expect(article.content, isNot(contains('1 oy')));
    expect(article.lexUrl, 'https://lex.uz/docs/6257288#6269139');
    final deadline = DeadlinesGuard.evaluateDeadline("Ishdan bo'shatishdi");
    expect(deadline?.description, contains('uch oy'));
    expect(deadline?.days, isNull,
        reason: 'Calendar months are not a fixed 30/90-day countdown.');
  });

  test('Constitution citations point to the corresponding official articles',
      () {
    const anchors = {27: '6445434', 28: '6445509', 29: '6445518'};
    final chunks = UzbekLegalKnowledgeBase.verifiedLawChunks
        .where((chunk) =>
            chunk.documentId == 'lex_const_2023' &&
            anchors.containsKey(chunk.articleNumber))
        .toList();
    expect(chunks, hasLength(3));
    for (final chunk in chunks) {
      expect(chunk.lexUrl,
          'https://lex.uz/docs/6445145#${anchors[chunk.articleNumber]}');
      if (chunk.articleNumber == 27) {
        expect(chunk.content, contains('huquqlari'));
        expect(chunk.content, contains('tushuntirilishi shart'));
      } else if (chunk.articleNumber == 28) {
        expect(chunk.content, contains('sukut'));
        expect(chunk.content, contains('yaqin qarindoshlariga'));
        expect(chunk.content, isNot(contains('sudda foydalanilishi mumkin')));
      } else {
        expect(chunk.content, contains('advokat'));
      }
    }
  });

  test('emergency protocol does not misattribute rights to articles', () async {
    final emergency = await LegalAssistantRemoteDataSourceImpl()
        .detectEmergency('Meni hibsga olishdi');
    expect(emergency, isNotNull);
    final rights = emergency?.constitutionalRights ?? <String>[];
    expect(rights, hasLength(3));
    expect(rights[0], contains('27-moddasi'));
    expect(rights[0], contains('tushuntirilishi shart'));
    expect(rights[1], contains('28-moddasi'));
    expect(rights[1], contains('yaqin qarindoshlariga'));
    expect(rights[2], contains('29-moddasi'));
    expect(rights[2], contains('advokat'));
  });

  for (final text in [
    "Ishdan bo'shatishdi, ishga tiklanmoqchiman",
    'Ish haqi kechiktirildi',
    "Meni ichki ishlar bo'limida ushlab turishibdi va majburiy so'roq qilishyapti",
    'Radar jarima qarori keldi',
    'Qarz shartnomasi bajarilmadi',
  ]) {
    test('no remaining deadline without verified start date: $text', () async {
      final response = await LegalAssistantRemoteDataSourceImpl()
          .getLegalAdvice(_query(text));
      expect(response.legalBasis, isNotEmpty);
      expect(response.riskAssessment.deadlineDays, isNull);
    });
  }

  test('unknown or absent written evidence is never assumed present', () async {
    for (final text in [
      'Qarz berdim, tilxat yozmaganmiz',
      'Qarz qaytarilmayapti',
    ]) {
      final response = await LegalAssistantRemoteDataSourceImpl()
          .getLegalAdvice(_query(text));
      expect(response.riskAssessment.level, RiskLevel.high);
      expect(response.riskAssessment.requiresLawyer, isTrue);
      expect(response.riskAssessment.limitations.join(' '),
          contains('tasdiqlanmagan'));
    }
  });

  test('heuristics preserve higher model risk and remove invented countdown',
      () async {
    final response = await LegalAssistantRemoteDataSourceImpl(
      geminiService: _CriticalGemini(),
    ).getLegalAdvice(_query('Ish haqi kechiktirilmoqda'));
    expect(response.riskAssessment.level, RiskLevel.critical);
    expect(response.riskAssessment.requiresLawyer, isTrue);
    expect(response.riskAssessment.deadlineDays, isNull);
  });

  test('emergency evaluator does not manufacture a two-day deadline', () {
    final risk = RiskMatrixEvaluator.evaluate(
      queryText: 'Meni hibsga olishdi',
      hasWrittenEvidence: false,
      isEmergency: true,
    );
    expect(risk.level, RiskLevel.critical);
    expect(risk.deadlineDays, isNull);
  });
}
