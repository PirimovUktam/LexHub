import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/deadlines_guard.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/core/legal_safety/risk_matrix_evaluator.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

void main() {
  group('LegalGroundingValidator Tests', () {
    test('extracts article numbers accurately using regex', () {
      final numbers = LegalGroundingValidator.extractArticleNumbers(
        "Mehnat kodeksining 161-moddasi va Konstitutsiyaning 28-moddasiga ko'ra",
      );

      expect(numbers.contains(161), isTrue);
      expect(numbers.contains(28), isTrue);
    });

    test('validates and catches hallucinated article numbers beyond max count', () {
      // 2023 Konstitutsiya has 155 articles
      expect(LegalGroundingValidator.isValidArticleNumber("Konstitutsiya", 155), isTrue);
      expect(LegalGroundingValidator.isValidArticleNumber("Konstitutsiya", 999), isFalse);

      // Jinoyat kodeksi has 302 articles
      expect(LegalGroundingValidator.isValidArticleNumber("Jinoyat kodeksi", 302), isTrue);
      expect(LegalGroundingValidator.isValidArticleNumber("Jinoyat kodeksi", 999), isFalse);
    });

    test('filters out invalid and repealed law articles', () {
      final articles = [
        const LawArticle(
          lawName: "Konstitutsiya",
          articleNumber: "28-modda",
          articleTitle: "Miranda qoidasi",
          articleText: "Matn",
          lexUrl: "https://lex.uz",
        ),
        const LawArticle(
          lawName: "Jinoyat kodeksi",
          articleNumber: "999-modda", // Hallucinated
          articleTitle: "Soxta modda",
          articleText: "Soxta",
          lexUrl: "https://lex.uz",
        ),
      ];

      final filtered = LegalGroundingValidator.filterAndGroundArticles(articles: articles);

      expect(filtered.length, 1);
      expect(filtered.first.articleNumber, "28-modda");
    });
  });

  group('DeadlinesGuard Tests', () {
    test('detects 1 month labor dispute court deadline', () {
      final deadline = DeadlinesGuard.evaluateDeadline(
        "Meni asossiz ishdan bo'shatishdi, ishga tiklanmoqchiman",
      );

      expect(deadline, isNotNull);
      expect(deadline!.days, 30);
      expect(deadline.isCritical, isTrue);
      expect(deadline.lawReference, contains("560-modda"));
    });

    test('detects 10 days administrative fine appeal deadline', () {
      final deadline = DeadlinesGuard.evaluateDeadline(
        "Radar tushib jarima qarori keldi, noroziman",
      );

      expect(deadline, isNotNull);
      expect(deadline!.days, 10);
      expect(deadline.isCritical, isTrue);
    });

    test('detects 10 days consumer product return deadline', () {
      final deadline = DeadlinesGuard.evaluateDeadline(
        "Dokondan yangi tovar sotib olgandim, cheki bor",
      );

      expect(deadline, isNotNull);
      expect(deadline!.days, 10);
      expect(deadline.isCritical, isFalse);
    });
  });

  group('RiskMatrixEvaluator Tests', () {
    test('marks emergency cases as critical risk with mandatory lawyer requirement', () {
      final assessment = RiskMatrixEvaluator.evaluate(
        queryText: "Meni IIB xodimlari ushlab turishgan",
        hasWrittenEvidence: false,
        isEmergency: true,
      );

      expect(assessment.level, RiskLevel.critical);
      expect(assessment.requiresLawyer, isTrue);
    });

    test('marks ungrounded loan dispute without written evidence as high risk', () {
      final assessment = RiskMatrixEvaluator.evaluate(
        queryText: "Qarz bergan edim, lekin hech qanday tilxat yozmaganmiz",
        hasWrittenEvidence: false,
        isEmergency: false,
      );

      expect(assessment.level, RiskLevel.high);
      expect(assessment.requiresLawyer, isTrue);
    });

    test('marks standard labor or consumer case as medium/low risk', () {
      final assessment = RiskMatrixEvaluator.evaluate(
        queryText: "Ish haqi kechiktirilmoqda",
        hasWrittenEvidence: true,
        isEmergency: false,
      );

      expect(assessment.level, RiskLevel.medium);
    });
  });

  group('LawArticleChunk RAG Model Test', () {
    test('converts RAG chunk into domain LawArticle correctly', () {
      const chunk = LawArticleChunk(
        chunkId: "uz_mk_art_161",
        documentName: "O'zbekiston Respublikasi Mehnat Kodeksi",
        documentId: "lex_6257288",
        articleNumber: 161,
        articleTitle: "Bekor qilish asoslari",
        content: "Mehnat shartnomasi quyidagi asoslarga ko'ra...",
        status: "active",
        jurisdiction: "Mehnat huquqi",
        lastUpdated: "2023-04-30",
        lexUrl: "https://lex.uz/docs/6257288#161",
      );

      expect(chunk.isActive, isTrue);
      final domainArticle = chunk.toLawArticle();
      expect(domainArticle.articleNumber, "161-modda");
      expect(domainArticle.lawName, chunk.documentName);
    });
  });
}
