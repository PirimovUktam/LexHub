import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/master_system_prompt.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

/// Service interfacing with Gemini AI for deterministic, grounded Uzbek legal analysis
class GeminiLegalService {
  final Dio dio;

  GeminiLegalService({Dio? customDio}) : dio = customDio ?? Dio();

  /// Executes Gemini AI analysis with grounding context and strict system prompts
  Future<LegalResponse?> generateLegalAdvice({
    required LegalQuery query,
    required String sanitizedQuery,
    required List<LawArticleChunk> contextChunks,
  }) async {
    final apiKey = SupabaseConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    try {
      final contextText = contextChunks.map((c) {
        return """
HUJJAT: ${c.documentName}
MODDA: ${c.articleNumber}-modda: ${c.articleTitle}
MATN: ${c.content}
STATUS: ${c.status}
RASMIY HAVOLA: ${c.lexUrl}
""";
      }).join("\n---\n");

      final promptPayload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": """
QUYIDAGI RASMIY HUQUQIY MANBALAR VA KONTEKSTGA QAT'IY ASOSLANIB JAVOB BER:

$contextText

FOYDALANUVCHI SO'ROVI:
"$sanitizedQuery"

TALAB:
Quyidagi JSON formatda to'liq o'zbek tilida, professional va xolis javob qaytar:
{
  "relatable_summary": "Oddiy xalq tilida xulosa (2-3 gap)",
  "actionable_steps": ["1-qadam...", "2-qadam...", "3-qadam..."],
  "legal_basis": [
    {
      "law_name": "Qonun nomi",
      "article_number": "XX-modda",
      "article_title": "Modda sarlavhasi",
      "article_text": "Moddaning aniq matni yoki iqtibos",
      "lex_url": "https://lex.uz/..."
    }
  ],
  "risk_assessment": {
    "level": "low" | "medium" | "high" | "critical",
    "summary": "Sud yoki moliyaviy risk xulosasi",
    "limitations": ["Cheklov 1...", "Cheklov 2..."],
    "requires_lawyer": true | false,
    "deadline_days": 10 | 30 | null
  }
}
"""
              }
            ]
          }
        ],
        "systemInstruction": {
          "parts": [
            {"text": MasterSystemPrompt.prompt}
          ]
        },
        "generationConfig": {
          "temperature": 0.2,
          "topP": 0.8,
          "responseMimeType": "application/json"
        }
      };

      final response = await dio.post(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
        data: promptPayload,
        options: Options(
          headers: {"Content-Type": "application/json"},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          final jsonText = parts?.first['text'] as String?;

          if (jsonText != null) {
            final parsedMap = jsonDecode(jsonText) as Map<String, dynamic>;
            parsedMap['id'] = "gemini_${DateTime.now().millisecondsSinceEpoch}";
            parsedMap['query_id'] = query.id;
            parsedMap['user_query'] = query.queryText;
            parsedMap['category'] = query.category;
            parsedMap['created_at'] = DateTime.now().toIso8601String();
            return LegalResponse.fromJson(parsedMap);
          }
        }
      }
      return null;
    } catch (_) {
      // Graceful fallback to local grounded knowledge engine
      return null;
    }
  }
}
