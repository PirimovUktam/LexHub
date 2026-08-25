import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-side Legal AI proxy client.
///
/// NIMA UCHUN [GeminiLegalService] O'RNIGA: u `SupabaseConfig.geminiApiKey`ni
/// o'qiydi, u esa `kReleaseMode`da ATAYLAB bo'sh string qaytaradi — ya'ni
/// release APK'da AI hech qachon ishlamaydi. Kalitni APK'ga solish esa uni
/// oshkor qilish bilan teng (APK'ni har kim dekompilyatsiya qila oladi).
/// Shu sababli model chaqiruvi `supabase/functions/legal-ai` Edge Function'iga
/// ko'chirildi; kalit faqat `supabase secrets set GEMINI_API_KEY=...` orqali
/// serverda yashaydi.
///
/// Bu klass [GeminiLegalService.generateLegalAdvice] bilan AYNAN bir xil
/// imzoga ega — shuning uchun `LegalAssistantRemoteDataSourceImpl`ning
/// Step 5'ida drop-in almashtirish mumkin.
class LegalAiProxyService {
  final Dio dio;
  final SupabaseClient supabaseClient;

  LegalAiProxyService({
    required this.supabaseClient,
    Dio? customDio,
  }) : dio = customDio ?? Dio();

  /// `LEGAL_AI_PROXY_URL` berilganmi. Berilmagan bo'lsa bu servis umuman
  /// chaqirilmasligi kerak (DI'da shu getter bilan tanlanadi).
  bool get isConfigured => SupabaseConfig.hasLegalAiProxy;

  /// Oxirgi urinishdagi xato kodi (`ai_not_configured`, `rate_limited`,
  /// `ai_timeout`, `unauthenticated`, ...). UI "AI javob bermadi" degan
  /// umumiy xabar o'rniga ANIQ sababni ko'rsatishi uchun saqlanadi.
  /// Muvaffaqiyatli chaqiruvdan keyin `null` bo'ladi.
  String? lastErrorCode;

  /// Proxy orqali huquqiy tahlil oladi.
  ///
  /// `null` qaytarsa — chaqiruvchi DETERMINISTIK fallback'ga o'tishi kerak va
  /// natijani "AI tahlili" deb ATAMASLIGI kerak. Sabab [lastErrorCode]da.
  Future<LegalResponse?> generateLegalAdvice({
    required LegalQuery query,
    required String sanitizedQuery,
    required List<LawArticleChunk> contextChunks,
  }) async {
    lastErrorCode = null;

    if (!isConfigured) {
      lastErrorCode = 'proxy_not_configured';
      return null;
    }

    // Foydalanuvchi sessiyasi SHART: funksiya anon/publishable kalitni
    // ataylab rad etadi (401 `invalid_or_anonymous_token`). Shuning uchun
    // tokensiz umuman so'rov yubormaymiz — bekorga tarmoq va kvota sarfi.
    final accessToken = supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      lastErrorCode = 'unauthenticated';
      return null;
    }

    try {
      final response = await dio.post<dynamic>(
        SupabaseConfig.legalAiProxyUrl,
        data: {
          'query_id': query.id,
          // DIQQAT: serverga SANITIZATSIYA QILINGAN matn ketadi
          // (`PiiAnonymizer.anonymize`), asl matn emas.
          'query_text': sanitizedQuery,
          'category': query.category,
          'retrieved_chunks': contextChunks.map((c) => c.toJson()).toList(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
            // Supabase Edge Functions gateway'i `apikey` header'ini talab
            // qiladi; u autorizatsiya BERMAYDI, faqat routing uchun.
            'apikey': SupabaseConfig.anonKey,
          },
          // O'LCHANGAN (2026-08-26, production live test): `gemini-3.7-flash`
          // to'liq master prompt + 3 chunk + JSON javob uchun 20 sekunddan
          // ko'proq vaqt oladi — server 20s timeout'i bilan `ai_timeout`
          // qaytarardi va foydalanuvchi HAR SAFAR deterministik fallback
          // olardi. Server byudjeti 40s (`LEGAL_AI_TIMEOUT_MS`), client esa
          // undan KO'PROQ kutadi: kesishni HAR DOIM server bajarishi kerak,
          // aks holda client uzilib qoladi va aniq `error.code` yo'qoladi.
          receiveTimeout: const Duration(seconds: 55),
          sendTimeout: const Duration(seconds: 15),
          // 4xx/5xx uchun ham exception tashlamaymiz — `error.code`ni
          // o'qib aniq sababni bilishimiz kerak.
          validateStatus: (_) => true,
        ),
      );
      return _parse(response, query);
    } on DioException catch (e) {
      lastErrorCode = e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionTimeout
          ? 'client_timeout'
          : 'network_error';
      debugPrint('[legal-ai] proxy xatosi: $lastErrorCode (${e.type})');
      return null;
    } catch (e) {
      lastErrorCode = 'client_exception';
      debugPrint('[legal-ai] proxy istisnosi: ${e.runtimeType}');
      return null;
    }
  }

  LegalResponse? _parse(Response<dynamic> response, LegalQuery query) {
    final status = response.statusCode ?? 0;
    if (status != 200) {
      lastErrorCode = _errorCodeOf(response.data) ?? 'http_$status';
      debugPrint('[legal-ai] proxy HTTP $status → $lastErrorCode');
      return null;
    }

    final data = response.data;
    final Map<String, dynamic> map;
    if (data is Map<String, dynamic>) {
      map = Map<String, dynamic>.of(data);
    } else if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        lastErrorCode = 'malformed_response';
        return null;
      }
      map = Map<String, dynamic>.of(decoded);
    } else {
      lastErrorCode = 'malformed_response';
      return null;
    }

    if ((map['relatable_summary'] as String? ?? '').trim().isEmpty) {
      lastErrorCode = 'empty_response';
      return null;
    }

    // `user_query` ni MAJBURIY o'zimiz qo'yamiz. Sabab: server uni ataylab
    // qaytarmaydi, `LegalResponse.fromJson` esa u yo'q bo'lsa
    // `relatable_summary`ga tushadi (`legal_response.dart:72-76`) — natijada
    // UI'da foydalanuvchining savoli o'rniga AI xulosasi ko'rinardi.
    // Bu yerda ASL (sanitizatsiya qilinmagan) matn qo'yiladi, chunki u faqat
    // qurilmada ko'rsatiladi va serverga qaytib ketmaydi.
    map['user_query'] = query.queryText;
    map['id'] ??= 'proxy_${DateTime.now().millisecondsSinceEpoch}';
    map['query_id'] ??= query.id;
    map['category'] ??= query.category;
    map['created_at'] ??= DateTime.now().toIso8601String();
    map['source'] ??= 'llm';

    return LegalResponse.fromJson(map);
  }

  String? _errorCodeOf(dynamic data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) return error['code'] as String?;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return _errorCodeOf(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
