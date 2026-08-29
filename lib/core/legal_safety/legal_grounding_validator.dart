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
  }) =>
      findGroundingChunk(
        lawName: lawName,
        articleNumber: articleNumber,
        chunks: chunks,
      ) !=
      null;

  /// `isGrounded` ning ASOSI: tasdiqlovchi chunk'ning O'ZINI qaytaradi.
  ///
  /// NIMA UCHUN KERAK: modda RAQAMI tasdiqlangani modelning o'sha modda
  /// MATNINI, SARLAVHASINI va HAVOLASINI to'g'ri yozganini BILDIRMAYDI.
  /// Ko'rsatiladigan maydonlarni chunk'dan olish uchun boolean yetmaydi.
  ///
  /// Server nusxasi: `grounding.ts` -> `findGroundingChunk`.
  static LawArticleChunk? findGroundingChunk({
    required String lawName,
    required String articleNumber,
    required List<LawArticleChunk> chunks,
  }) {
    final number = firstArticleInteger(articleNumber);
    if (number == 0) return null;

    final wanted = documentTokens(lawName);
    // Farqlovchi token qolmasa (masalan lawName = "Kodeks") qaysi hujjat
    // ekanini TASDIQLAB bo'lmaydi -> rad etamiz.
    if (wanted.isEmpty) return null;

    for (final chunk in chunks) {
      if (chunk.articleNumber != number) continue;
      // Bekor qilingan/eskirgan chunk tasdiq bo'lib xizmat qilmaydi.
      if (!chunk.isActive) continue;
      final have = documentTokens(chunk.documentName);
      if (wanted.any(have.contains)) return chunk;
    }
    return null;
  }

  /// IQTIBOSNI SOLISHTIRISH uchun normallashtirish: registr va bo'shliq farqi
  /// iqtibosni YOLG'ON qilmaydi. Tinish belgilari ATAYLAB SAQLANADI — ularni
  /// tashlash "emas" kabi inkorlarni yashirishga yo'l ochib berardi.
  ///
  /// Server nusxasi: `grounding.ts` -> `normalizeQuote`.
  static String _normalizeQuote(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+', unicode: true), ' ').trim();

  /// IQTIBOS ENG KAM UZUNLIGI. Qisqa bo'lak manba ichida TASODIFAN topiladi:
  /// `"a"` harfi deyarli har qanday o'zbek matnida bor, ya'ni bir harfli
  /// "iqtibos" tekshiruvni bekorga o'tkazib yuborardi (bu teshik AYNAN
  /// `grounding_test.ts` da o'lchandi). Server bilan bir xil bo'lishi shart:
  /// `grounding.ts` -> `MIN_QUOTE_CHARS`.
  static const int minQuoteChars = 12;

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
  }) =>
      groundArticles(articles: articles, verifiedChunks: verifiedChunks)
          .articles;

  /// `filterAndGroundArticles` ning TO'LIQ natijasi: filtrlangan moddalar VA
  /// nechta iqtibos rasmiy matn bilan ALMASHTIRILGANI.
  ///
  /// NIMA UCHUN ALMASHTIRISH KERAK: `legalBasis` modelning JSON javobidan
  /// kelishi mumkin (`geminiService` va o'z backend'i shoxlari). Ilgari modda
  /// RAQAMI tasdiqlansa, `articleText`, `lexUrl`, `articleTitle` va `lawName`
  /// MODELDAN o'tib ketardi — ya'ni to'g'ri modda raqami ostida TO'QILGAN
  /// iqtibos va BOSHQA moddaga olib boradigan lex.uz havolasi ko'rsatilishi
  /// mumkin edi. Bu ochiq-oydin soxta moddadan XAVFLIROQ: u tasdiqlangan
  /// ko'rinadi. `legal-ai` Edge Function serverda ayni tuzatishni bajaradi
  /// (`grounding.ts` -> `groundLegalBasis`), bu esa MODELGA TO'G'RIDAN-TO'G'RI
  /// boradigan klient shoxlarini yopadi.
  ///
  /// `replacedQuotes` JIM QOLMAYDI (§20): chaqiruvchi uni log'ga chiqaradi.
  static ({List<LawArticle> articles, int replacedQuotes}) groundArticles({
    required List<LawArticle> articles,
    List<LawArticleChunk>? verifiedChunks,
  }) {
    final List<LawArticle> grounded = [];
    int replacedQuotes = 0;
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

      // Korpus berilmagan rejim ATAYLAB saqlanadi (chegara testlari shunga
      // tayanadi): tasdiqlovchi chunk YO'Q, demak almashtiradigan RASMIY matn
      // ham yo'q — modda o'zgarishsiz o'tadi.
      if (corpus == null) {
        grounded.add(article);
        continue;
      }

      // 2-filtr (FAIL-CLOSED): modda korpusda TASDIQLANISHI shart.
      final chunk = findGroundingChunk(
        lawName: article.lawName,
        articleNumber: article.articleNumber,
        chunks: corpus,
      );
      if (chunk == null) continue;

      // IQTIBOS TEKSHIRUVI: modelning matni chunk ichida AYNAN topilmasa,
      // u ISHONCHLI EMAS va chunk'ning rasmiy matni bilan almashtiriladi.
      // Yo'nalish ataylab: tekshirilmagan iqtibosdan ko'ra rasmiy matn.
      final modelText = article.articleText;
      final normalized = _normalizeQuote(modelText);
      final quoteVerified = normalized.length >= minQuoteChars &&
          _normalizeQuote(chunk.content).contains(normalized);
      if (modelText.isNotEmpty && !quoteVerified) replacedQuotes++;

      grounded.add(article.copyWith(
        // HUJJAT NOMI, SARLAVHA, HAVOLA — CHUNK'DAN. Model qiymati faqat
        // TOKEN MOSLIGI bo'yicha tekshirilgan, havola esa umuman
        // tekshirilmagan. Chunk bo'sh bersa BO'SH qoladi (fail-closed):
        // noto'g'ri havoladan ko'ra havolasizlik yaxshi.
        lawName: chunk.documentName,
        articleTitle: chunk.articleTitle,
        articleText: quoteVerified ? modelText : chunk.content,
        lexUrl: chunk.lexUrl,
      ));
    }

    return (articles: grounded, replacedQuotes: replacedQuotes);
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
