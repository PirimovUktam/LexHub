import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'dart:async';

import 'package:lexhub/core/constants/api_endpoints.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/legal_safety/deadlines_guard.dart';
import 'package:lexhub/core/legal_safety/emergency_detector.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_coverage.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/core/legal_safety/master_system_prompt.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/legal_safety/risk_matrix_evaluator.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/core/network/api_client.dart';
import 'package:lexhub/core/network/gemini_legal_service.dart';
import 'package:lexhub/core/network/legal_ai_proxy_service.dart';
import 'package:lexhub/core/network/request_timeout.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
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
    // KLASSIFIKATSIYA `EmergencyDetector`ga ko'chirildi: u sof funksiya, ya'ni
    // datasource qurmasdan o'lchanadi. Bu yerda faqat protokol MATNI qoladi.
    //
    // NUQSON TARIXI: shu joyda `lower.contains('tekshiruv')` YOLG'IZ O'ZI
    // bannerni ochardi va soliq tekshiruvi so'rovi Miranda qoidasini
    // ko'rsatardi; `lower.contains('organ')` esa "vakolatli organ" kabi
    // butunlay neytral iborani so'roq majburlash deb belgilardi.
    final signal = EmergencyDetector.classify(queryText);
    if (!signal.isEmergency) {
      if (kDebugMode && signal.wasSuppressed) {
        // JIM YUTMAYMIZ: kuchsiz atama uchradi, lekin jinoyat-protsessual
        // kontekst yo'q. Noto'g'ri bostirish bo'lsa log'da ko'rinadi.
        debugPrint(
          '[emergency] bostirildi: "${signal.suppressedTerm}"'
          '${signal.suppressedBy == null ? '' : ' — kontekst: "${signal.suppressedBy}"'}',
        );
      }
      return null;
    }

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
      //
      // `groundArticles` (yangi) — `filterAndGroundArticles` dan farqi: u
      // ko'rsatiladigan maydonlarni (matn, sarlavha, hujjat nomi, lex.uz
      // havolasi) TASDIQLOVCHI CHUNK'DAN oladi va modelning tekshirilmagan
      // iqtibosini rasmiy matn bilan almashtiradi. Bu shart, chunki
      // `aiResponse.legalBasis` yuqoridagi `geminiService` yoki o'z backend'i
      // shoxlarida MODEL JSON'idan keladi — o'sha yerda to'g'ri modda raqami
      // ostida to'qilgan matn va boshqa moddaga ketadigan havola bo'lishi
      // mumkin. `legal-ai` Edge Function bu ishni serverda bajaradi.
      final groundingResult = LegalGroundingValidator.groundArticles(
        articles: aiResponse.legalBasis.isNotEmpty
            ? aiResponse.legalBasis
            : LegalKnowledgeRetriever.toDomainArticles(relevantChunks),
        verifiedChunks: relevantChunks,
      );
      final groundedArticles = groundingResult.articles;
      // JIM TUZATISH YO'Q (§20): almashtirish sodir bo'lsa, u log'da ko'rinadi.
      // Server tomonda ayni son javobda `replaced_quotes` bo'lib qaytadi.
      if (groundingResult.replacedQuotes > 0) {
        debugPrint(
          '[grounding] tekshirilmagan iqtibos rasmiy matn bilan '
          'almashtirildi: ${groundingResult.replacedQuotes}',
        );
      }

      final finalRisk = RiskMatrixEvaluator.evaluate(
        queryText: sanitizedQueryText,
        hasWrittenEvidence: true,
        isEmergency: emergency != null,
        explicitDeadlineDays: deadlineInfo?.days,
      );

      // ANTI-HALLUCINATION NATIJASI QAYTA TIRILTIRILMAYDI.
      //
      // O'LCHANGAN DEFEKT (2026-08-26): bu satr ilgari
      // `groundedArticles.isNotEmpty ? groundedArticles
      //  : LegalKnowledgeRetriever.toDomainArticles(relevantChunks)` edi —
      // ya'ni `filterAndGroundArticles` HAMMASINI rad etganda, filtrlanmagan
      // xom chunk'lar baribir "Huquqiy asos" sifatida ko'rsatilardi. Bu
      // grounding validatorining butun maqsadini bekor qiladi: uning
      // "tasdiqlanmadi" qarori ustidan yozib ketilardi.
      //
      // Yuqoridagi `retrieveRelevantChunks` fail-closed bo'lgani bilan birga
      // bu ikkita nuqson foydalanuvchi ko'rgan natijani berardi: korpusdan
      // tashqaridagi savolga aloqasiz Konstitutsiya moddalari.
      //
      // Endi grounding bo'sh qaytarsa `legalBasis` ham bo'sh qoladi va UI
      // buni OSHKORA aytadi. Javob matni (`relatableSummary`, `actionableSteps`)
      // saqlanadi — faqat "qonuniy asos" DA'VOSI olib tashlanadi.
      return aiResponse.copyWith(
        legalBasis: groundedArticles,
        riskAssessment: _applyCoverageHonesty(
          risk: finalRisk,
          coverage: LegalCoverage.classify(sanitizedQueryText),
          hasGroundedBasis: groundedArticles.isNotEmpty,
        ),
        emergencyProtocol: emergency ?? aiResponse.emergencyProtocol,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi. Bu shox `$e` ni foydalanuvchi ko'radigan
      // matnga qo'shadi, ya'ni yutilsa ekranda XOM
      // `TimeoutException after 0:00:20.000000: ...` chiqadi va ingliz UI
      // `FailureCode.timeout` ARB matnini tanlay olmaydi. `TimeoutException`
      // `AppException` EMAS — yuqoridagi shox uni ushlamaydi.
      if (e is TimeoutException) rethrow;
      throw ServerException(message: "Yuridik tahlilni yuklashda xatolik: $e");
    }
  }

  /// XAVF BAHOSINI QAMROV HAQIQATIGA MOSLASHTIRADI.
  ///
  /// [RiskMatrixEvaluator] sof kalit so'z evristikasi: u qonun bazasida modda
  /// bor-yo'qligini BILMAYDI. Shu sababli qamrovdan tashqaridagi savolga ham
  /// ishonchli ohangdagi baho qaytarardi.
  ///
  /// REAL QURILMADA O'LCHANGAN DEFEKT (Pixel_9, 2026-08-27, s06.png):
  /// "Tovar belgisini ro'yxatdan o'tkazish..." savoliga modda TOPILMAGAN
  /// (kartochkada "Mos keladigan modda topilmadi" yozilgan), lekin xuddi shu
  /// ekranda quyidagilar ko'rsatilgan edi:
  ///  * "Past xavf" + 25% ko'rsatkich;
  ///  * "Murojaat qilish uchun qolgan taxminiy muddat: 10 kun";
  ///  * "Javob berish muddati 15 kundan 1 oygacha.";
  ///  * "Rasmiy tartibda ariza yoki pretenziya topshirish orqali nizoni
  ///    sudgacha hal etish ehtimoli yuqori."
  ///
  /// Bularning hammasi PROTSESSUAL DA'VO va hech qanday moddaga bog'lanmagan.
  /// "10 kun" eng xavflisi: iste'molchi qonunidan olingan muddat intellektual
  /// mulk savoliga qo'yilgan — foydalanuvchi o'z haqiqiy muddatini o'tkazib
  /// yuborishi mumkin. Bu "aloqasiz modda ko'rsatish" defektining AYNAN o'zi,
  /// faqat "Huquqiy asos" bloki o'rniga "Risk va Muddatlar" blokida.
  ///
  /// Shuning uchun asos bo'lmasa baho PATCH QILINMAYDI — QAYTA QURILADI:
  /// evristik summary va protsessual cheklovlar TASHLANADI, `deadlineDays`
  /// NULL bo'ladi.
  ///
  /// DARAJA PASAYTIRILMAYDI, balki ko'tariladi: tekshirilgan asossiz holatda
  /// "Past xavf" degan yorliq foydalanuvchini xotirjam qiladi — bu esa
  /// fail-closed prinsipiga TESKARI. `critical` saqlanadi (favqulodda holat
  /// signalini bosib qo'yish mumkin emas), qolgani `high`ga ko'tariladi va
  /// matnda ochiq "BAHOLANMADI" deb yoziladi.
  RiskAssessment _applyCoverageHonesty({
    required RiskAssessment risk,
    required CoverageResult coverage,
    required bool hasGroundedBasis,
  }) {
    final extra = <String>[];

    // HARD STOP: jinoyat huquqi bazada umuman yo'q. Boshqa soha (masalan
    // mehnat) bo'yicha modda topilgan bo'lsa ham, ayblanish holatini jim
    // o'tkazib bo'lmaydi — bu erkinlikdan mahrum qilish xavfi.
    final hardStop = coverage.hardStopTopic;
    if (hardStop != null) {
      extra.add(
        "Savolda jinoiy javobgarlik belgilari bor. Jinoyat huquqi LexHub "
        "qamrovida EMAS: ${hardStop.organName} bilan zudlik bilan bog'laning.",
      );
    }

    if (!hasGroundedBasis) {
      final organName = coverage.uncoveredTopic?.organName;
      return RiskAssessment(
        level: risk.level == RiskLevel.critical
            ? RiskLevel.critical
            : RiskLevel.high,
        summary: "Xavf darajasi BAHOLANMADI: savol LexHub tasdiqlagan qonun "
            "bazasi qamrovidan tashqarida, ya'ni hech qanday modda, muddat "
            "yoki protsessual baho ko'rsatilmaydi."
            "${organName != null ? ' Muddat va tartibni vakolatli organdan aniqlang: $organName.' : ''}",
        limitations: [
          "Bu blok qonun moddasiga BOG'LANMAGAN — huquqiy xulosa sifatida "
              "ishlatilmasligi kerak.",
          "MUDDAT KO'RSATILMAYDI. Sizning holatingizga tegishli muddat "
              "LexHub bazasida yo'q; noto'g'ri muddatga tayanish huquqni "
              "yo'qotishga olib keladi.",
          ...extra,
        ],
        requiresLawyer: true,
        // ATAYLAB null: `DeadlinesGuard` kalit so'zga qarab ishlaydi va
        // qamrovdan tashqaridagi savolga BOSHQA sohaning muddatini beradi.
        deadlineDays: null,
      );
    }

    if (extra.isEmpty) return risk;

    return risk.copyWith(
      limitations: [...risk.limitations, ...extra],
      requiresLawyer: true,
    );
  }

  /// Hybrid Retriever: Queries Supabase law_article_chunks or local verified knowledge base
  Future<List<LawArticleChunk>> _retrieveLegalChunks(String sanitizedQuery) async {
    final List<LawArticleChunk> cloudChunks = [];

    // SERVER SO'ROVI MAVZUGA QARAB FILTRLANADI.
    //
    // ILGARIGI NUQSON (2026-08-29 gacha): `select() + eq('status','active') +
    // limit(5)` — `order` YO'Q, mavzu filtri YO'Q, ya'ni jadvaldagi BIRINCHI 5
    // qator. Jonli bazada o'lchangan: har qanday savolga Konstitutsiyaning
    // 27/28/29/42/44 moddalari. Jadval 17 qatordan oshsa mahalliy bazada YO'Q,
    // lekin ALOQADOR modda hech qachon olinmaydi.
    //
    // ENDI: `search_law_articles(search_query, match_count, filter_jurisdiction)`
    // RPC — `article_title / content / document_name` bo'yicha ILIKE.
    // `filter_jurisdiction` ATAYLAB null: qamrov bir nechta sohaga ruxsat
    // berishi mumkin, RPC esa BITTA satr qabul qiladi. Soha filtri pastda
    // `coverage.allowsChunk` orqali baribir qo'llanadi, ya'ni bu yerda soha
    // mantig'i IKKINCHI MARTA yozilmaydi.
    final searchTerm = LegalKnowledgeRetriever.serverSearchTerm(sanitizedQuery);

    if (supabaseClient != null && searchTerm != null) {
      try {
        final response = await supabaseClient!
            .rpc(
              'search_law_articles',
              params: {
                'search_query': searchTerm,
                // 5 EMAS: RPC `article_number ASC` bo'yicha saralaydi (ball
                // bo'yicha emas), ya'ni chegara kesishi TASODIFIY. 12 ta
                // moslik pastdagi ball darvozasiga yetarli zaxira beradi,
                // payload esa AI inferensiyasidan oldin kichik qoladi.
                'match_count': 12,
              },
            )
            // TIMEOUT MAJBURIY: bu so'rov AI inferensiyasidan OLDIN turadi
            // (Step 4). Chegara bo'lmasa yarim-ochiq socket butun huquqiy
            // tahlilni cheksiz bloklaydi — foydalanuvchi aylanayotgan
            // shimmer'ni ko'rib, so'rov bajarilayotganiga ishonadi.
            .withTimeout(kDbRequestTimeout, label: 'search_law_articles');

        final rawList = response as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          for (final item in rawList) {
            cloudChunks.add(LawArticleChunk.fromJson(item as Map<String, dynamic>));
          }
        }
      } catch (e) {
        // Cloud chunk'lar IXTIYORIY: mahalliy tasdiqlangan baza pastda
        // qo'shiladi, shuning uchun xato yuqoriga uzatilmaydi. Lekin JIM
        // yutilmaydi — timeout yoki RLS xatosi debug log'da ko'rinadi.
        if (kDebugMode) {
          debugPrint('[legal-rag] search_law_articles o\'qilmadi: $e');
        }
      }
    }

    // Combine with local verified legal knowledge base.
    //
    // TARTIB MUHIM: MAHALLIY chunk'lar OLDINDA turadi va serverdan kelganlar
    // ham AYNI darvozalardan (qamrov → soha → `_minRelevanceScore`) o'tadi.
    //
    // NIMA UCHUN IKKI QATLAM: RPC ILIKE `%termin%` bilan qidiradi, ya'ni
    // "aliment" termini "alimentga oid bo'lmagan" matnga ham tushishi mumkin.
    // Serverdan kelgan qator "huquqiy asos" bo'lib chiqishi uchun mahalliy
    // baza bilan BIR XIL ball chegarasidan o'tishi shart —
    // `retrieveRelevantChunks` ning `corpus` parametri aynan shu uchun bor:
    // relevantlik mantig'i IKKINCHI MARTA yozilmaydi, manba ahamiyatsiz
    // bo'lib qoladi.
    //
    // O'LCHANGAN NUQSON TARIXI (2026-08-29, production): ilgari server so'rovi
    // `select() + eq('status','active') + limit(5)` edi — jadvaldagi BIRINCHI
    // 5 qator, savol nima bo'lishidan qat'i nazar Konstitutsiyaning
    // 27/28/29/42/44 moddalari. Darvozalar esa faqat mahalliy chunk'larga
    // qo'llanardi, shuning uchun aliment so'roviga [Oila 96, Oila 99,
    // Oila 136, Konstitutsiya 27] qaytardi. Regressiya testlari:
    // `test/core/legal_safety/cloud_chunk_relevance_test.dart` (darvoza) va
    // `test/core/legal_safety/server_search_term_test.dart` (mavzuga
    // filtrlangan server so'rovi).
    final localChunks = LegalKnowledgeRetriever.retrieveRelevantChunks(sanitizedQuery, maxResults: 3);
    final relevantCloudChunks = cloudChunks.isEmpty
        ? const <LawArticleChunk>[]
        : LegalKnowledgeRetriever.retrieveRelevantChunks(
            sanitizedQuery,
            maxResults: 3,
            corpus: cloudChunks,
          );
    final allChunks = [...localChunks, ...relevantCloudChunks];
    
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
    final domainArticles = LegalKnowledgeRetriever.toDomainArticles(chunks);
    final coverage = LegalCoverage.classify(sanitizedText);

    // MATN QATLAMI TOPILGAN MODDALARGA BOG'LANADI, SO'ROVGA EMAS.
    //
    // NIMA UCHUN: soha qamrovda bo'lishi shu sohaning HAR BIR savoliga
    // bazada modda borligini BILDIRMAYDI. Misol: "meros" so'rovi
    // `fuqarolik` sohasini ochadi, lekin bazada meros moddasi yo'q (faqat
    // 150 va 732). Matn so'rov sohasiga qarab yozilsa — foydalanuvchiga
    // asossiz "qarz" maslahati beriladi. Shuning uchun yagona manba —
    // haqiqatan TOPILGAN chunk'larning `jurisdiction` qiymati.
    final domain = LegalCoverage.dominantDomain(chunks);

    String summary;
    List<String> steps;

    if (chunks.isEmpty || domain == null) {
      // ================== FAIL-CLOSED MATN ==================
      //
      // O'LCHANGAN DEFEKT (2026-08-27): bu shoxda ilgari
      // "Siz taqdim etgan holat O'zbekiston Respublikasining amaldagi
      //  qonunchiligi bilan kafolatlangan va himoyalangan."
      // deb yozilardi — HAR QANDAY savolga, hatto qamrovdan butunlay
      // tashqaridagi (soliq, bojxona, litsenziya) savolga ham. Bu
      // ASOSSIZ HUQUQIY DA'VO: qonun bazasida mos modda topilmagan holda
      // "kafolatlangan va himoyalangan" degan xulosa chiqarilgan.
      //
      // Modda qatlami (`legalBasis`) allaqachon fail-closed edi, lekin MATN
      // qatlami emas — ya'ni foydalanuvchi moddasiz, lekin ishonchli
      // ohangdagi "himoyalangansiz" xulosasini o'qirdi. Endi ikkala qatlam
      // ham bir xil haqiqatni aytadi.
      final organName = coverage.uncoveredTopic?.organName;
      summary = organName != null
          ? "Bu savol LexHub tasdiqlagan qonun bazasi qamrovidan tashqarida, "
              "shu sababli aniq qonun moddasi ko'rsatilmaydi va quyidagi matn "
              "huquqiy xulosa emas. Mavzu bo'yicha vakolatli organ: $organName."
          : "LexHub tasdiqlagan qonun bazasidan bu savolga aniq mos keladigan "
              "modda topilmadi. Quyidagi matn UMUMIY xarakterda va qonuniy asos "
              "sifatida ishlatilmasligi kerak.";
      steps = [
        if (organName != null)
          "Vakolatli organga murojaat qiling: $organName."
        else
          "Masala yuzasidan vakolatli davlat organiga yozma murojaat qiling "
              "(my.gov.uz orqali murojaat qabul qilinadi).",
        "Qonun matnini rasmiy manbadan tekshiring — lex.uz (O'zbekiston "
            "Respublikasi qonun hujjatlari ma'lumotlar bazasi).",
        "Aniq huquqiy xulosa uchun litsenziyaga ega yurist yoki advokat bilan "
            "maslahatlashing.",
        // MUDDAT ATAYLAB KO'RSATILMAYDI. `DeadlinesGuard` ham kalit so'zga
        // asoslangan; qamrovdan tashqaridagi savolda u tasodifan ishga
        // tushsa, foydalanuvchiga ASOSSIZ protsessual muddat beriladi —
        // bu esa huquqni yo'qotishga olib keladigan xato. Modda yo'q joyda
        // muddat ham da'vo qilinmaydi.
      ];
    } else {
      switch (domain) {
        case LegalDomain.mehnat:
          summary = "Mehnat munosabatlarida ish beruvchi xodimni asossiz ishdan bo'shatishi yoki maoshini kechiktirishi qat'iyan taqiqlanadi. 2023-yilgi yangi tahrirdagi Mehnat kodeksiga ko'ra, har bir xodimga o'z vaqtida haq olish va noqonuniy bo'shatish ustidan sudga murojaat qilish kafolatlangan.";
          steps = [
            "Ish beruvchiga o'z huquqlaringiz buzilayotgani to'g'risida 2 nusxada yozma ariza topshiring.",
            "Davlat mehnat inspeksiyasiga (1176 yoki my.gov.uz orqali) xabar bering.",
            if (deadlineInfo != null)
              "MUHIM MUDDAT: ${deadlineInfo.description}"
            else
              "Ishdan noqonuniy bo'shatilgan taqdirda, buyruq nusxasi berilgan kundan boshlab 1 oy ichida fuqarolik sudiga da'vo kiriting.",
          ];
        case LegalDomain.mamuriy:
          summary = "Ma'muriy huquqbuzarliklar bo'yicha tayinlangan jarimalar ustidan norozi bo'lsangiz, qonuniy tartibda shikoyat berish huquqiga egasiz.";
          steps = [
            if (deadlineInfo != null)
              "MUHIM MUDDAT: ${deadlineInfo.description}"
            else
              "Qaror nusxasi kelgan kundan e'tiboran 10 kun ichida YHQ ma'muriy organiga yoki Ma'muriy sudga shikoyat yuboring.",
            "Foto/video dalillar va radar sertifikatini so'rab murojaat qiling.",
          ];
        case LegalDomain.oila:
          summary = "Oila qonunchiligiga ko'ra, voyaga yetmagan bolalar ta'minoti uchun aliment to'lash ota-onaning majburiyatidir. Sud buyrug'i orqali aliment 3 kun ichida tayinlanishi va MIB orqali undirilishi mumkin.";
          steps = [
            "Fuqarolik ishlari bo'yicha tuman sudiga aliment undirish bo'yicha sud buyrug'i chiqarish haqida ariza bering.",
            "Farzandning tug'ilganlik haqidagi guvohnomasi va nikoh/ajrim hujjatlarini ilova qiling.",
            "Chiqarilgan ijro hujjatini Majburiy ijro byurosiga topshiring.",
          ];
        case LegalDomain.istemolchi:
          summary = "Iste'molchi sifatida nuqsonli tovar sotilganda tovarni almashtirish, bepul tuzattirish yoki pulni qaytarib olish huquqiga egasiz.";
          steps = [
            "Tovar xarid chekini va nuqsonini qayd etuvchi dalillarni saqlang.",
            "Sotuvchiga yozma pretenziya taqdim eting.",
          ];
        case LegalDomain.fuqarolik:
          summary = "Fuqarolik munosabatlarida yozma shartnoma yoki tilxat mavjud bo'lganda sud orqali talabni undirish imkoniyati yuqori bo'ladi.";
          steps = [
            "Qarshi tomonga rasmiy yozma talabnoma (pretenziya) yuboring.",
            "Fuqarolik ishlari bo'yicha sudga da'vo arizasi kiriting.",
            if (deadlineInfo != null) "MUHIM MUDDAT: ${deadlineInfo.description}",
          ];
        case LegalDomain.konstitutsiya:
          // Bu shoxda umumiy "kafolatlangan" formulasi ASOSLI: quyida
          // haqiqatan Konstitutsiya moddalari qonuniy asos sifatida
          // topilgan va ular aynan kafolat beruvchi normalar.
          summary = "Sizning holatingizga O'zbekiston Respublikasi Konstitutsiyasining quyida keltirilgan moddalari bevosita taalluqli — bu normalar to'g'ridan-to'g'ri amal qiladi va hech qanday idora tomonidan cheklanishi mumkin emas.";
          steps = [
            "Quyidagi Konstitutsiya moddalariga havola qilib, o'z huquqingizni og'zaki va yozma ravishda rasman bildiring.",
            "Bayonnoma (protokol) mazmuni siz aytganga mos kelmasa — qo'l qo'ymang va e'tirozingizni shu hujjatga yozib qo'ying.",
            "Litsenziyaga ega advokat bilan bog'laning; advokatga ega bo'lish huquqi Konstitutsiya bilan kafolatlangan.",
          ];
      }
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
