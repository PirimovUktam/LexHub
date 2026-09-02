import 'package:equatable/equatable.dart';
import 'package:lexhub/core/utils/json_coerce.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

/// Represents dual-layer (Relatable + Credible) legal response
class LegalResponse extends Equatable {
  final String id;
  final String queryId;
  final String userQuery;
  final String category;
  final String relatableSummary;
  final List<String> actionableSteps;
  final List<LawArticle> legalBasis;
  final RiskAssessment riskAssessment;
  final EmergencyProtocol? emergencyProtocol;
  final DateTime createdAt;
  final bool isSaved;
  final bool isCompleted;

  /// Javob QAYERDAN kelgani — halollik maydoni.
  ///
  /// `'llm'` — `supabase/functions/legal-ai` orqali haqiqiy model javobi.
  /// `'deterministic'` — qurilmadagi qoidalar/knowledge base asosidagi javob
  /// (AI EMAS). UI faqat `'llm'` bo'lganda "AI tahlili" deb atashga haqli.
  ///
  /// Standart qiymat ATAYLAB `'deterministic'`: isbot bo'lmasa, model
  /// da'vosi qilinmaydi.
  final String source;

  static const String sourceLlm = 'llm';
  static const String sourceDeterministic = 'deterministic';

  /// Javob haqiqiy model chaqiruvidan kelganmi.
  bool get isAiGenerated => source == sourceLlm;

  const LegalResponse({
    required this.id,
    required this.queryId,
    this.userQuery = '',
    this.category = 'Umumiy huquq',
    required this.relatableSummary,
    this.actionableSteps = const [],
    this.legalBasis = const [],
    required this.riskAssessment,
    this.emergencyProtocol,
    required this.createdAt,
    this.isSaved = false,
    this.isCompleted = false,
    this.source = sourceDeterministic,
  });

  factory LegalResponse.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<LawArticle> parseLawArticles(dynamic raw) {
      if (raw is List) {
        // `whereType<Map<String, dynamic>>()` Hive cache'dan kelgan
        // `Map<dynamic, dynamic>` elementlarni JIMGINA tashlab yuborardi —
        // natijada `legal_basis` bo'sh qolib, javob asossiz ko'rinardi.
        return raw
            .map(jsonMap)
            .whereType<Map<String, dynamic>>()
            .map(LawArticle.fromJson)
            .toList();
      }
      return [];
    }

    RiskAssessment parseRisk(dynamic raw) {
      final map = jsonMap(raw);
      if (map != null) {
        return RiskAssessment.fromJson(map);
      }
      return const RiskAssessment(
        level: RiskLevel.low,
        summary: "Risk tahlili mavjud emas",
      );
    }

    EmergencyProtocol? parseEmergency(dynamic raw) {
      final map = jsonMap(raw);
      return map == null ? null : EmergencyProtocol.fromJson(map);
    }

    /// Faqat AYNAN `'llm'` satri "AI" yorlig'ini beradi.
    ///
    /// TUR XAVFSIZ: ilgari bu yerda `json['source'] as String?` bor edi va
    /// server (yoki eski cache) `"source": true` / `1` qaytarsa
    /// `type 'bool' is not a subtype of type 'String?'` bilan YIQILARDI —
    /// ya'ni butun huquqiy javob `ServerException`ga aylanardi. Endi
    /// noto'g'ri tur JIM ravishda `deterministic` bo'ladi (fail-closed).
    /// Regression: `legal_response_test.dart` "tanilmagan qiymatlar
    /// FAIL-CLOSED" testi.
    String parseSource(dynamic raw) =>
        raw is String && raw == sourceLlm ? sourceLlm : sourceDeterministic;

    final queryText = jsonText(json['user_query']) ??
        jsonText(json['userQuery']) ??
        jsonText(json['query_text']) ??
        jsonText(json['relatable_summary']) ??
        '';

    final catText = jsonText(json['category']) ??
        jsonText(json['selected_category']) ??
        'Umumiy huquq';

    return LegalResponse(
      id: jsonText(json['id']) ?? '',
      queryId: jsonText(json['query_id']) ?? jsonText(json['queryId']) ?? '',
      userQuery: queryText,
      category: catText,
      relatableSummary: jsonText(json['relatable_summary']) ??
          jsonText(json['relatableSummary']) ??
          '',
      actionableSteps: parseStringList(
        json['actionable_steps'] ?? json['actionableSteps'],
      ),
      legalBasis: parseLawArticles(
        json['legal_basis'] ?? json['legalBasis'],
      ),
      riskAssessment: parseRisk(
        json['risk_assessment'] ?? json['riskAssessment'],
      ),
      emergencyProtocol: parseEmergency(
        json['emergency_protocol'] ?? json['emergencyProtocol'],
      ),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isSaved: jsonFlag(json['is_saved']) ?? jsonFlag(json['isSaved']) ?? false,
      isCompleted:
          jsonFlag(json['is_completed']) ?? jsonFlag(json['isCompleted']) ?? false,
      // Faqat AYNAN 'llm' qabul qilinadi; boshqa har qanday qiymat (yoki
      // maydonning yo'qligi, yoki noto'g'ri tur) 'deterministic' bo'ladi —
      // soxta "AI" yorlig'i paydo bo'lmasligi uchun.
      source: parseSource(json['source'] ?? json['response_source']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query_id': queryId,
      'user_query': userQuery,
      'category': category,
      'relatable_summary': relatableSummary,
      'actionable_steps': actionableSteps,
      'legal_basis': legalBasis.map((e) => e.toJson()).toList(),
      'risk_assessment': riskAssessment.toJson(),
      'emergency_protocol': emergencyProtocol?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'is_saved': isSaved,
      'is_completed': isCompleted,
      'source': source,
    };
  }

  LegalResponse copyWith({
    String? id,
    String? queryId,
    String? userQuery,
    String? category,
    String? relatableSummary,
    List<String>? actionableSteps,
    List<LawArticle>? legalBasis,
    RiskAssessment? riskAssessment,
    EmergencyProtocol? emergencyProtocol,
    DateTime? createdAt,
    bool? isSaved,
    bool? isCompleted,
    String? source,
  }) {
    return LegalResponse(
      id: id ?? this.id,
      queryId: queryId ?? this.queryId,
      userQuery: userQuery ?? this.userQuery,
      category: category ?? this.category,
      relatableSummary: relatableSummary ?? this.relatableSummary,
      actionableSteps: actionableSteps ?? this.actionableSteps,
      legalBasis: legalBasis ?? this.legalBasis,
      riskAssessment: riskAssessment ?? this.riskAssessment,
      emergencyProtocol: emergencyProtocol ?? this.emergencyProtocol,
      createdAt: createdAt ?? this.createdAt,
      isSaved: isSaved ?? this.isSaved,
      isCompleted: isCompleted ?? this.isCompleted,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
        id,
        queryId,
        userQuery,
        category,
        relatableSummary,
        actionableSteps,
        legalBasis,
        riskAssessment,
        emergencyProtocol,
        createdAt,
        isSaved,
        isCompleted,
        source,
      ];
}
