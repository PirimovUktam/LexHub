import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:lexhub/core/constants/api_endpoints.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/legal_safety/deadlines_guard.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/core/legal_safety/master_system_prompt.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/legal_safety/risk_matrix_evaluator.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/core/network/api_client.dart';
import 'package:lexhub/core/network/gemini_legal_service.dart';
import 'package:lexhub/core/network/legal_ai_proxy_service.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LegalAssistantRemoteDataSource {
  Future<LegalResponse> getLegalAdvice(LegalQuery query);
  Future<EmergencyProtocol?> detectEmergency(String queryText);
}

class LegalAssistantRemoteDataSourceImpl implements LegalAssistantRemoteDataSource {
  final ApiClient? apiClient;
  final GeminiLegalService? geminiService;

  /// Server-side Legal AI proxy. Release build'da AI'ning YAGONA haqiqiy
  /// yo'li — `injection_container.dart`da ro'yxatga olinadi.
  final LegalAiProxyService? legalAiProxyService;
  final SupabaseClient? supabaseClient;

  LegalAssistantRemoteDataSourceImpl({
    this.apiClient,
    this.geminiService,
    this.legalAiProxyService,
    this.supabaseClient,
  });

  @override
  Future<EmergencyProtocol?> detectEmergency(String queryText) async {
    final lower = queryText.toLowerCase();
    final isArrest = lower.contains('hibs') || lower.contains('ushlab turish') || lower.contains('qamash');
    final isSearch = lower.contains('tintuv') || lower.contains('tekshiruv') || lower.contains('musodara');
    final isInterrogation = lower.contains("so'roq") || lower.contains('organ') || lower.contains('ichki ishlar') || lower.contains('militsiya');
    final isViolence = lower.contains("zo'ravonlik") || lower.contains('tahdid') || lower.contains('kaltak');

    if (isArrest || isSearch || (isInterrogation && lower.contains('majburiy')) || isViolence) {
      return const EmergencyProtocol(
        isEmergency: true,
        title: "Tezkor Huquqiy Himoya: Favqulodda Huquqiy Xavf",
        redFlags: [
          "Sizni ushlab turishgan yoki erkinligingiz cheklangan.",
          "Yashash joyingizda yoki avtomobilingizda tintuv o'tkazilmoqda.",
          "Advokatsiz so'roq berishga majburlanmoqdasiz.",
        ],
        constitutionalRights: [
          "O'zbekiston Konstitutsiyasi 27-moddasi: Hech kim qonunga asoslanmagan holda hibsga olinishi yoki ushlab turilishi mumkin emas.",
          "O'zbekiston Konstitutsiyasi 28-moddasi (Miranda qoidasi): Ushlab turilgan shaxsga uning sukut saqlash va advokatga ega bo'lish huquqi darhol tushuntirilishi shart.",
          "O'zbekiston Konstitutsiyasi 29-moddasi: Hech kim o'ziga va yaqin qarindoshlariga qarshi ko'rsatuv berishga majbur emas.",
        ],
        immediateActions: [
          "1. Sukut saqlang va 'Advokatim kelmaguncha hech qanday ko'rsatuv bermayman' deb rasman bildiring.",
          "2. Yaqinlaringizga yoki advokatingizga darhol 1 marotaba bepul qo'ng'iroq qilish huquqini talab qiling.",
          "3. Sizga tushunarsiz yoki siz aytmagan so'zlar yozilgan hech qanday bayonnoma (protokol)ga qo'l qo'ymang!",
        ],
        emergencyHotline: "1002",
      );
    }
    return null;
  }

  @override
  Future<LegalResponse> getLegalAdvice(LegalQuery query) async {
    try {
      // Step 1: Emergency Red Flag Detection
      final emergency = await detectEmergency(query.queryText);

      // Step 2: Procedural Deadlines Guard
      final deadlineInfo = DeadlinesGuard.evaluateDeadline(query.queryText);

      // Step 3: Strict PII Sanitization BEFORE outbound AI transmission
      final sanitizedQueryText = PiiAnonymizer.anonymize(query.queryText);

      // Step 4: Hybrid RAG Retrieval (Supabase Cloud + Embedded Verified Law Chunks)
      final relevantChunks = await _retrieveLegalChunks(sanitizedQueryText);

      // Step 5: Legal AI Inference with RAG Context & Master Prompt.
      //
      // TARTIB MUHIM: birinchi navbatda SERVER-SIDE proxy
      // (`supabase/functions/legal-ai`), keyin — faqat debug build'da —
      // client-side Gemini. Sabab: `SupabaseConfig.geminiApiKey`
      // `kReleaseMode`da bo'sh string qaytaradi, ya'ni [geminiService]
      // release APK'da HAR DOIM `null` qaytaradi. Kalitni APK'ga solish esa
      // uni oshkor qilish bilan teng. Shuning uchun "AI" da'vosini haqiqiy
      // qiladigan yo'l — proxy.
      LegalResponse? aiResponse;
      if (legalAiProxyService != null && legalAiProxyService!.isConfigured) {
        aiResponse = await legalAiProxyService!.generateLegalAdvice(
          query: query,
          sanitizedQuery: sanitizedQueryText,
          contextChunks: relevantChunks,
        );
        if (aiResponse == null) {
          // JIM YUTMAYMIZ: aniq sabab (`ai_not_configured`, `rate_limited`,
          // `ai_timeout`, `unauthenticated`, ...) log'da ko'rinishi kerak,
          // aks holda "AI ishlamayapti" muammosi diagnozsiz qoladi.
          debugPrint(
            '[legal-ai] proxy javob bermadi: ${legalAiProxyService!.lastErrorCode}',
          );
        }
      }

      if (aiResponse == null && geminiService != null) {
        aiResponse = await geminiService!.generateLegalAdvice(
          query: query,
          sanitizedQuery: sanitizedQueryText,
          contextChunks: relevantChunks,
        );
      }

      // Step 5b: O'z backend'i orqali fallback — FAQAT manzil ataylab
      // sozlangan bo'lsa. `ApiEndpoints.hasBackend` tekshiruvi P0 tuzatish:
      // ilgari bu blok `https://api.lexhub.uz/v1`ga (DNS'da MAVJUD BO'LMAGAN
      // hostga) foydalanuvchining yuridik so'rovini POST qilardi. Domenni
      // istalgan uchinchi shaxs ro'yxatdan o'tkazsa — maxfiy huquqiy matn
      // to'g'ridan-to'g'ri unga ketardi. Batafsil: `ApiEndpoints.baseUrl`.
      if (aiResponse == null && apiClient != null && apiClient!.hasBaseUrl) {
        try {
          final response = await apiClient!.post(
            ApiEndpoints.analyzeQuery,
            data: {
              'system_instruction': MasterSystemPrompt.prompt,
              'query_id': query.id,
              'query_text': sanitizedQueryText,
              'category': query.category,
              'retrieved_chunks': relevantChunks.map((c) => c.toJson()).toList(),
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            aiResponse = LegalResponse.fromJson(response.data as Map<String, dynamic>);
          }
        } catch (e) {
          // JIM YUTMAYMIZ: pastda 5c grounded engine ishlaydi, ya'ni
          // foydalanuvchi javobsiz qolmaydi — lekin backend nosozligi
          // debug log'da KO'RINISHI kerak, aks holda buzilgan integratsiya
          // yillar davomida sezilmaydi (§3 "silent error swallowing").
          if (kDebugMode) {
            debugPrint('LegalAssistant backend fallback ishlamadi: $e');
          }
        }
      }

      // Step 5c: Grounded Knowledge Engine Fallback
      aiResponse ??= _generateGroundedUzbekLegalResponse(
        query: query,
        sanitizedText: sanitizedQueryText,
        chunks: relevantChunks,
        emergency: emergency,
        deadlineInfo: deadlineInfo,
      );

      // Step 6: Post-Processing & Anti-Hallucination Grounding Validation
      final groundedArticles = LegalGroundingValidator.filterAndGroundArticles(
        articles: aiResponse.legalBasis.isNotEmpty
            ? aiResponse.legalBasis
            : LegalKnowledgeRetriever.toDomainArticles(relevantChunks),
        verifiedChunks: relevantChunks,
      );

      final finalRisk = RiskMatrixEvaluator.evaluate(
        queryText: sanitizedQueryText,
        hasWrittenEvidence: true,
        isEmergency: emergency != null,
        explicitDeadlineDays: deadlineInfo?.days,
      );

      return aiResponse.copyWith(
        legalBasis: groundedArticles.isNotEmpty ? groundedArticles : LegalKnowledgeRetriever.toDomainArticles(relevantChunks),
        riskAssessment: finalRisk,
        emergencyProtocol: emergency ?? aiResponse.emergencyProtocol,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: "Yuridik tahlilni yuklashda xatolik: $e");
    }
  }

  /// Hybrid Retriever: Queries Supabase law_article_chunks or local verified knowledge base
  Future<List<LawArticleChunk>> _retrieveLegalChunks(String sanitizedQuery) async {
    final List<LawArticleChunk> cloudChunks = [];

    if (supabaseClient != null) {
      try {
        final response = await supabaseClient!
            .from('law_article_chunks')
            .select()
            .eq('status', 'active')
            .limit(5);

        final rawList = response as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          for (final item in rawList) {
            cloudChunks.add(LawArticleChunk.fromJson(item as Map<String, dynamic>));
          }
        }
      } catch (_) {}
    }

    // Combine with local verified legal knowledge base.
    //
    // TARTIB MUHIM: MAHALLIY chunk'lar OLDINDA turadi. Sabab — yuqoridagi
    // Supabase so'rovi mavzuga qarab FILTRLANMAYDI (`status = active` +
    // `limit(5)`, ya'ni jadvaldagi BIRINCHI 5 qator). Ilgari cloud chunk'lar
    // oldinda turgani va pastda `.take(4)` bo'lgani uchun, jadval to'ldirilishi
    // bilanoq har qanday so'rovga BIR XIL 5 modda "huquqiy asos" sifatida
    // qaytardi va kalit so'z bo'yicha topilgan ALOQADOR moddalarni siqib
    // chiqarardi. Hozir jadval bo'sh (production'da 0 qator — tekshirilgan),
    // shuning uchun bu latent nuqson edi. Tartib almashtirildi: relevantlik
    // bo'yicha saralangan mahalliy natija hech qachon yo'qolmaydi.
    //
    // Cloud tomonida to'liq yechim — semantik/matn filtri (`textSearch` yoki
    // pgvector) — jadval to'ldirilganda qo'shilishi kerak. Bugun uni yozib
    // qo'yish MUMKIN, lekin 0 qatorli jadvalda ISBOTLAB bo'lmaydi.
    final localChunks = LegalKnowledgeRetriever.retrieveRelevantChunks(sanitizedQuery, maxResults: 3);
    final allChunks = [...localChunks, ...cloudChunks];
    
    // De-duplicate by documentName and articleNumber
    final seen = <String>{};
    final unique = <LawArticleChunk>[];
    for (final c in allChunks) {
      final key = "${c.documentName}_${c.articleNumber}";
      if (!seen.contains(key) && c.isActive) {
        seen.add(key);
        unique.add(c);
      }
    }

    return unique.isNotEmpty ? unique.take(4).toList() : localChunks;
  }

  /// Grounded deterministic fallback response builder adhering to Dual-Layer structure
  LegalResponse _generateGroundedUzbekLegalResponse({
    required LegalQuery query,
    required String sanitizedText,
    required List<LawArticleChunk> chunks,
    required EmergencyProtocol? emergency,
    required DeadlineInfo? deadlineInfo,
  }) {
    final lower = sanitizedText.toLowerCase();
    final domainArticles = LegalKnowledgeRetriever.toDomainArticles(chunks);

    String summary = "Siz taqdim etgan holat O'zbekiston Respublikasining amaldagi qonunchiligi bilan kafolatlangan va himoyalangan.";
    List<String> steps = [
      "Vaziyat bo'yicha barcha yozma hujjatlar, dalillar va xabarlarni to'plang.",
      "O'z huquqlaringizni himoya qilish yuzasidan vakolatli organga yozma murojaat qiling.",
    ];

    final isLabor = lower.contains('mehnat') || lower.contains('maosh') || lower.contains("bo'shat") || lower.contains('ish beruvchi') || lower.contains('ish haqi') || lower.contains('ishdan');
    final isFamily = lower.contains('aliment') || lower.contains('nikoh') || lower.contains('ajrash') || lower.contains('farzand') || lower.contains('bola');
    final isAdminOrFine = lower.contains('jarima') || lower.contains('radar') || lower.contains('yhq') || lower.contains("ma'muriy");
    final isConsumer = lower.contains('tovar') || lower.contains("do'kon") || lower.contains('xarid') || lower.contains('qaytarish');
    final isDebt = lower.contains('qarz') || lower.contains('tilxat');

    if (isLabor) {
      summary = "Mehnat munosabatlarida ish beruvchi xodimni asossiz ishdan bo'shatishi yoki maoshini kechiktirishi qat'iyan taqiqlanadi. 2023-yilgi yangi tahrirdagi Mehnat kodeksiga ko'ra, har bir xodimga o'z vaqtida haq olish va noqonuniy bo'shatish ustidan sudga murojaat qilish kafolatlangan.";
      steps = [
        "Ish beruvchiga o'z huquqlaringiz buzilayotgani to'g'risida 2 nusxada yozma ariza topshiring.",
        "Davlat mehnat inspeksiyasiga (1176 yoki my.gov.uz orqali) xabar bering.",
        if (deadlineInfo != null)
          "MUHIM MUDDAT: ${deadlineInfo.description}"
        else
          "Ishdan noqonuniy bo'shatilgan taqdirda, buyruq nusxasi berilgan kundan boshlab 1 oy ichida fuqarolik sudiga da'vo kiriting.",
      ];
    } else if (isAdminOrFine) {
      summary = "Ma'muriy huquqbuzarliklar bo'yicha tayinlangan jarimalar ustidan norozi bo'lsangiz, qonuniy tartibda shikoyat berish huquqiga egasiz.";
      steps = [
        if (deadlineInfo != null)
          "MUHIM MUDDAT: ${deadlineInfo.description}"
        else
          "Qaror nusxasi kelgan kundan e'tiboran 10 kun ichida YHQ ma'muriy organiga yoki Ma'muriy sudga shikoyat yuboring.",
        "Foto/video dalillar va radar sertifikatini so'rab murojaat qiling.",
      ];
    } else if (isFamily) {
      summary = "Oila qonunchiligiga ko'ra, voyaga yetmagan bolalar ta'minoti uchun aliment to'lash ota-onaning majburiyatidir. Sud buyrug'i orqali aliment 3 kun ichida tayinlanishi va MIB orqali undirilishi mumkin.";
      steps = [
        "Fuqarolik ishlari bo'yicha tuman sudiga aliment undirish bo'yicha sud buyrug'i chiqarish haqida ariza bering.",
        "Farzandning tug'ilganlik haqidagi guvohnomasi va nikoh/ajrim hujjatlarini ilova qiling.",
        "Chiqarilgan ijro hujjatini Majburiy ijro byurosiga topshiring.",
      ];
    } else if (isConsumer) {
      summary = "Iste'molchi sifatida nuqsonli tovar sotilganda tovarni almashtirish, bepul tuzattirish yoki pulni qaytarib olish huquqiga egasiz.";
      steps = [
        "Tovar xarid chekini va nuqsonini qayd etuvchi dalillarni saqlang.",
        "Sotuvchiga yozma pretenziya taqdim eting.",
      ];
    } else if (isDebt) {
      summary = "Qarz munosabatlarida yozma shartnoma yoki tilxat mavjud bo'lganda sud orqali qarzni undirish imkoniyati yuqori bo'ladi.";
      steps = [
        "Qarz oluvchiga rasmiy yozma talabnoma yuboring.",
        "Fuqarolik ishlari bo'yicha sudga da'vo arizasi kiriting.",
      ];
    }

    final risk = RiskMatrixEvaluator.evaluate(
      queryText: sanitizedText,
      hasWrittenEvidence: true,
      isEmergency: emergency != null,
      explicitDeadlineDays: deadlineInfo?.days,
    );

    return LegalResponse(
      id: "resp_${DateTime.now().millisecondsSinceEpoch}",
      queryId: query.id,
      userQuery: query.queryText,
      category: query.category ?? 'Umumiy huquq',
      relatableSummary: summary,
      actionableSteps: steps,
      legalBasis: domainArticles,
      riskAssessment: risk,
      emergencyProtocol: emergency,
      createdAt: DateTime.now(),
      // OSHKORA: bu javob MODEL emas — qurilmadagi qoidalar va tasdiqlangan
      // knowledge base natijasi. UI uni "AI tahlili" deb ATAMASLIGI kerak.
      source: LegalResponse.sourceDeterministic,
    );
  }
}
