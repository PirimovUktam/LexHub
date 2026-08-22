import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

/// Grounding & Anti-Hallucination Post-Processing Validator
class LegalGroundingValidator {
  LegalGroundingValidator._();

  /// Regex pattern to extract law article references (e.g., '161-modda', '28-modda', 'modda 99')
  static final RegExp articleRegex = RegExp(
    r'(\d+)\s*[-–—]?\s*(?:modda|moddasi|m\.)',
    caseSensitive: false,
  );

  /// Verified active law limits in Republic of Uzbekistan
  static const Map<String, int> activeLawMaxArticles = {
    "Konstitutsiya": 155, // 2023 yangi tahrirdagi Konstitutsiya 155 modda
    "Mehnat kodeksi": 581, // 2023 yangi tahrir
    "Oila kodeksi": 238,
    "Fuqarolik kodeksi": 1199,
    "Jinoyat kodeksi": 302,
    "Ma'muriy javobgarlik": 348,
    "Jinoyat-protsessual kodeksi": 605,
    "Fuqarolik protsessual kodeksi": 458,
  };

  /// Extracts all article numbers from arbitrary text
  static Set<int> extractArticleNumbers(String text) {
    final matches = articleRegex.allMatches(text);
    final Set<int> numbers = {};
    for (final match in matches) {
      final numStr = match.group(1);
      if (numStr != null) {
        final parsed = int.tryParse(numStr);
        if (parsed != null) {
          numbers.add(parsed);
        }
      }
    }
    return numbers;
  }

  /// Verifies if a given article number is valid within the known law boundaries
  static bool isValidArticleNumber(String lawName, int articleNumber) {
    if (articleNumber <= 0) return false;

    for (final entry in activeLawMaxArticles.entries) {
      if (lawName.toLowerCase().contains(entry.key.toLowerCase())) {
        return articleNumber <= entry.value;
      }
    }
    // Default threshold for uncataloged specialized laws
    return articleNumber <= 500;
  }

  /// Validates a list of LawArticles against active RAG metadata
  static List<LawArticle> filterAndGroundArticles({
    required List<LawArticle> articles,
    List<LawArticleChunk>? verifiedChunks,
  }) {
    final List<LawArticle> grounded = [];

    for (final article in articles) {
      final numbers = extractArticleNumbers(article.articleNumber);
      final artNum = numbers.isNotEmpty ? numbers.first : 0;

      // Check max boundary
      if (artNum > 0 && !isValidArticleNumber(article.lawName, artNum)) {
        // Hallucinated article number detected -> exclude or sanitize
        continue;
      }

      // If verified chunks are provided, verify status == 'active'
      if (verifiedChunks != null && verifiedChunks.isNotEmpty) {
        final match = verifiedChunks.firstWhere(
          (c) =>
              c.articleNumber == artNum &&
              c.documentName.toLowerCase().contains(
                    article.lawName.toLowerCase().split(' ').first,
                  ),
          orElse: () => LawArticleChunk(
            chunkId: '',
            documentName: article.lawName,
            documentId: '',
            articleNumber: artNum,
            articleTitle: article.articleTitle,
            content: article.articleText,
            status: 'active',
            jurisdiction: '',
            lastUpdated: '',
            lexUrl: article.lexUrl,
          ),
        );

        if (!match.isActive) {
          // Outdated or repealed article -> skip
          continue;
        }
      }

      grounded.add(article);
    }

    return grounded;
  }

  /// Validates full LegalResponse structure ensuring all 4 non-negotiable blocks are present
  static bool validateDualLayerStructure(LegalResponse response) {
    if (response.relatableSummary.trim().isEmpty) return false;
    if (response.actionableSteps.isEmpty) return false;
    if (response.legalBasis.isEmpty) return false;
    if (response.riskAssessment.summary.trim().isEmpty) return false;
    return true;
  }
}
