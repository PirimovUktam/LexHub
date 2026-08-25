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

  /// O'ZBEK HUQUQIY HUJJAT NOMLARIDA UMUMIY bo'lgan tokenlar — hujjatni
  /// solishtirishdan CHIQARIB tashlanadi.
  ///
  /// NIMA UCHUN SHART: "Mehnat kodeksi" va "Jinoyat kodeksi" `kodeksi`
  /// tokenida mos keladi. Bu ro'yxat bo'lmasa, filtr modelning "Jinoyat
  /// kodeksi 161-modda" to'qimasini Mehnat kodeksining 161-moddasi chunk'i
  /// bilan "TASDIQLAB" qo'yardi.
  ///
  /// SERVER BILAN AYNAN BIR XIL BO'LISHI SHART:
  /// `supabase/functions/legal-ai/grounding.ts` -> `STOP_TOKENS`.
  /// Drift'ni `test/core/security/legal_grounding_parity_test.dart` qulflaydi.
  static const Set<String> documentStopTokens = {
    'kodeks', 'kodeksi', 'kodeksining', 'qonun', 'qonuni', 'qonunining',
    'respublikasi', 'respublikasining', 'zbekiston', 'ozbekiston',
    'modda', 'moddasi', 'qism', 'qismi', 'band', 'bandi',
    'tahrir', 'tahriri', 'sonli', 'qarori', 'farmoni', 'toris', 'sidagi',
  };

  /// `unicode: true` MAJBURIY — busiz Dart'da `\p{L}` sinf sifatida
  /// ishlamaydi. Apostrof ham ajratuvchi: "O'zbekiston" -> `o` + `zbekiston`
  /// (shu sababli `zbekiston` stop-token ro'yxatida).
  static final RegExp _tokenSplitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Hujjat nomidan FARQLOVCHI tokenlarni ajratadi (server `docTokens` nusxasi).
  static List<String> documentTokens(String name) => name
      .toLowerCase()
      .split(_tokenSplitter)
      .where((t) => t.length > 3 && !documentStopTokens.contains(t))
      .toList();

  /// Maxsus MAYDONdan (`article_number`) birinchi butun sonni oladi.
  ///
  /// `extractArticleNumbers`dan FARQI: u ERKIN MATN uchun mo'ljallangan va
  /// "modda" so'zini talab qiladi (sana yoki summani modda deb o'qimasligi
  /// uchun). Bu yerda maydonning o'zi modda raqami, shuning uchun `"161"` ham
  /// qabul qilinadi — server `firstInteger` bilan bir xil.
  static int firstArticleInteger(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }

  /// FAIL-CLOSED grounding tekshiruvi: modda AYNAN `chunks` ichida FAOL
  /// holatda topilmasa — `false`.
  ///
  /// ILGARIGI TESHIK (audit topilmasi P1): bu mantiq
  /// `filterAndGroundArticles` ichida
  /// `firstWhere(..., orElse: () => LawArticleChunk(status: 'active'))`
  /// shaklida edi. Mos chunk topilmaganda `orElse` SUN'IY "active" chunk
  /// YASAB berardi, `match.isActive` esa `true` bo'lardi — natijada modelning
  /// KONTEKSTDA UMUMAN BO'LMAGAN moddasi "grounded" deb o'tib ketardi. Ya'ni
  /// "faqat tasdiqlangan moddalar ko'rsatiladi" da'vosi bajarilmayotgan edi.
  static bool isGrounded({
    required String lawName,
    required String articleNumber,
    required List<LawArticleChunk> chunks,
  }) {
    final number = firstArticleInteger(articleNumber);
    if (number == 0) return false;

    final wanted = documentTokens(lawName);
    // Farqlovchi token qolmasa (masalan lawName = "Kodeks") qaysi hujjat
    // ekanini TASDIQLAB bo'lmaydi -> rad etamiz.
    if (wanted.isEmpty) return false;

    for (final chunk in chunks) {
      if (chunk.articleNumber != number) continue;
      // Bekor qilingan/eskirgan chunk tasdiq bo'lib xizmat qilmaydi.
      if (!chunk.isActive) continue;
      final have = documentTokens(chunk.documentName);
      if (wanted.any(have.contains)) return true;
    }
    return false;
  }

  /// Validates a list of LawArticles against active RAG metadata
  ///
  /// `verifiedChunks` BERILGANDA (va bo'sh bo'lmaganda) — FAIL-CLOSED: har bir
  /// modda shu chunk'lar ichida FAOL holatda topilishi shart, aks holda
  /// tashlanadi.
  ///
  /// `verifiedChunks == null` yoki bo'sh — grounding korpusi YO'Q, shuning
  /// uchun faqat `isValidArticleNumber` chegara evristikasi qo'llanadi. Bu
  /// rejim ATAYLAB saqlangan: chegara testlari korpussiz ishlaydi. Production
  /// yo'li (`legal_assistant_remote_datasource.dart:169`) HAR DOIM chunk
  /// beradi.
  static List<LawArticle> filterAndGroundArticles({
    required List<LawArticle> articles,
    List<LawArticleChunk>? verifiedChunks,
  }) {
    final List<LawArticle> grounded = [];
    // `null` YOKI bo'sh ro'yxat = grounding korpusi berilmagan.
    final List<LawArticleChunk>? corpus =
        verifiedChunks != null && verifiedChunks.isNotEmpty
            ? verifiedChunks
            : null;

    for (final article in articles) {
      final artNum = firstArticleInteger(article.articleNumber);

      // 1-filtr: qonunning ma'lum chegarasidan oshgan raqam -> to'qima.
      if (artNum > 0 && !isValidArticleNumber(article.lawName, artNum)) {
        continue;
      }

      // 2-filtr (FAIL-CLOSED): korpus bor bo'lsa, modda unda TASDIQLANISHI
      // shart. Mos chunk yo'q -> modda TASHLANADI.
      if (corpus != null &&
          !isGrounded(
            lawName: article.lawName,
            articleNumber: article.articleNumber,
            chunks: corpus,
          )) {
        continue;
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
