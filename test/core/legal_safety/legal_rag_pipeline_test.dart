import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/deadlines_guard.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/legal_safety/risk_matrix_evaluator.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

void main() {
  group('Sprint 4: Legal AI + RAG Safety & Grounding Pipeline Suite', () {
    test('1. PII Sanitization removes all sensitive identifiers', () {
      const rawText = """
Foydalanuvchi: Alisher Valiyev, Pasport: AA 1234567, Tel: +998 90 123 45 67, 
Karta: 8600 1234 5678 9012, PINFL: 31201951234567, Email: alisher@example.uz
""";

      final sanitized = PiiAnonymizer.anonymize(rawText);

      expect(sanitized.contains('AA 1234567'), false);
      expect(sanitized.contains('+998 90 123 45 67'), false);
      expect(sanitized.contains('8600 1234 5678 9012'), false);
      expect(sanitized.contains('31201951234567'), false);
      expect(sanitized.contains('alisher@example.uz'), false);

      expect(sanitized.contains('[Pasport yashirildi]'), true);
      expect(sanitized.contains('[Telefon yashirildi]'), true);
      expect(sanitized.contains('[Karta raqami yashirildi]'), true);
      expect(sanitized.contains('[JSHSHIR yashirildi]'), true);
      expect(sanitized.contains('[Email yashirildi]'), true);
    });

    test('2. Emergency Protocol triggers Miranda rights on arrest/detention', () async {
      final dataSource = LegalAssistantRemoteDataSourceImpl();

      final emergency = await dataSource.detectEmergency("Meni ichki ishlar bo'limida ushlab turishibdi va majburiy so'roq qilishyapti");

      expect(emergency, isNotNull);
      expect(emergency!.isEmergency, true);
      expect(emergency.constitutionalRights.any((r) => r.contains('28-moddasi (Miranda qoidasi)')), true);
      expect(emergency.constitutionalRights.any((r) => r.contains('29-moddasi')), true);
      expect(emergency.emergencyHotline, '1002');
    });

    test('3. Legal Knowledge Retriever retrieves active verified Uzbek law chunks', () {
      // Labor query
      final laborChunks = LegalKnowledgeRetriever.retrieveRelevantChunks("Ish beruvchi meni asossiz ishdan bo'shatmoqchi");
      expect(laborChunks.isNotEmpty, true);
      expect(laborChunks.any((c) => c.documentName.contains("Mehnat kodeksi")), true);
      expect(laborChunks.every((c) => c.isActive), true);

      // Family query
      final familyChunks = LegalKnowledgeRetriever.retrieveRelevantChunks("Farzandim uchun aliment undirish tartibi qanday?");
      expect(familyChunks.isNotEmpty, true);
      expect(familyChunks.any((c) => c.documentName.contains("Oila kodeksi")), true);

      // Consumer query
      final consumerChunks = LegalKnowledgeRetriever.retrieveRelevantChunks("Do'kondan sotib olingan nuqsonli tovarni qaytarish");
      expect(consumerChunks.isNotEmpty, true);
      expect(consumerChunks.any((c) => c.documentName.contains("Iste'molchilar")), true);
    });

    test('4. Legal Grounding Validator catches and filters hallucinated articles', () {
      final testArticles = [
        const LawArticle(
          lawName: "O'zbekiston Respublikasining Mehnat kodeksi",
          articleNumber: "161-modda", // Valid (<= 581)
          articleTitle: "Shartnomani bekor qilish",
          articleText: "Qonuniy asoslar...",
          lexUrl: "https://lex.uz/docs/6257288",
        ),
        const LawArticle(
          lawName: "O'zbekiston Respublikasining Mehnat kodeksi",
          articleNumber: "899-modda", // Hallucinated (> 581)
          articleTitle: "Gallyutsinatsiya modda",
          articleText: "Mavjud bo'lmagan modda...",
          lexUrl: "https://lex.uz/docs/6257288",
        ),
        const LawArticle(
          lawName: "O'zbekiston Respublikasining Konstitutsiyasi",
          articleNumber: "200-modda", // Hallucinated (> 155)
          articleTitle: "Konstitutsiya xato modda",
          articleText: "Mavjud emas...",
          lexUrl: "https://lex.uz/docs/6445145",
        ),
      ];

      final filtered = LegalGroundingValidator.filterAndGroundArticles(articles: testArticles);

      expect(filtered.length, 1);
      expect(filtered.first.articleNumber, "161-modda");
    });

    test('5. Deadlines Guard correctly extracts strict procedural deadlines', () {
      // Labor 1 month
      final laborDeadline = DeadlinesGuard.evaluateDeadline("Ishdan bo'shatish bo'yicha buyruq chiqarildi");
      expect(laborDeadline, isNotNull);
      expect(laborDeadline!.days, 30);
      expect(laborDeadline.isCritical, true);

      // Traffic fine 10 days
      final fineDeadline = DeadlinesGuard.evaluateDeadline("Radar jarima qarori keldi");
      expect(fineDeadline, isNotNull);
      expect(fineDeadline!.days, 10);
      expect(fineDeadline.isCritical, true);

      // Civil claim 3 years
      final civilDeadline = DeadlinesGuard.evaluateDeadline("Qarz shartnomasi bo'yicha pulni qaytarmadi");
      expect(civilDeadline, isNotNull);
      expect(civilDeadline!.days, 1095);
    });

    test('6. Risk Matrix Evaluator computes realistic risk level & lawyer requirements', () {
      // Critical on emergency
      final criticalRisk = RiskMatrixEvaluator.evaluate(
        queryText: "Meni hibsga olishdi",
        hasWrittenEvidence: false,
        isEmergency: true,
      );
      expect(criticalRisk.level, RiskLevel.critical);
      expect(criticalRisk.requiresLawyer, true);

      // High on criminal / unwritten debt
      final highRisk = RiskMatrixEvaluator.evaluate(
        queryText: "Qarz berdim lekin hech qanday tilxat yozmaganmiz",
        hasWrittenEvidence: false,
        isEmergency: false,
      );
      expect(highRisk.level, RiskLevel.high);
      expect(highRisk.requiresLawyer, true);

      // Low on standard consumer
      final lowRisk = RiskMatrixEvaluator.evaluate(
        queryText: "Do'kondan kiyim sotib olgandim cheki bor",
        hasWrittenEvidence: true,
        isEmergency: false,
      );
      expect(lowRisk.level, RiskLevel.low);
      expect(lowRisk.requiresLawyer, false);
    });

    test('7. End-to-End Legal Assistant RemoteDataSource generates grounded Dual-Layer response', () async {
      final dataSource = LegalAssistantRemoteDataSourceImpl();

      final query = LegalQuery(
        id: 'test_q_100',
        queryText: "Mening pasportim AA 1234567. Ish beruvchi oylik maoshimni 2 oydan beri bermayapti va ishdan bo'shatish bilan qo'rqityapti.",
        category: "Mehnat huquqi",
        createdAt: DateTime.now(),
      );

      final response = await dataSource.getLegalAdvice(query);

      expect(response.relatableSummary.isNotEmpty, true);
      expect(response.actionableSteps.isNotEmpty, true);
      expect(response.legalBasis.isNotEmpty, true);
      expect(response.riskAssessment.summary.isNotEmpty, true);
      expect(LegalGroundingValidator.validateDualLayerStructure(response), true);
    });
  });
}
