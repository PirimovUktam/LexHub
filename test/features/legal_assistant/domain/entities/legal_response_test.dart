import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

void main() {
  group('LegalResponse & Domain Entities Test', () {
    test('should correctly serialize and deserialize LawArticle', () {
      const article = LawArticle(
        lawName: "O'zbekiston Respublikasi Mehnat Kodeksi",
        articleNumber: "161-modda",
        articleTitle: "Mehnat shartnomasini bekor qilish asoslari",
        articleText: "Qonuniy asoslar matni",
        lexUrl: "https://lex.uz/docs/6257288",
      );

      final json = article.toJson();
      final fromJson = LawArticle.fromJson(json);

      expect(fromJson, equals(article));
      expect(fromJson.articleNumber, "161-modda");
    });

    test('should correctly serialize and deserialize RiskAssessment', () {
      const assessment = RiskAssessment(
        level: RiskLevel.medium,
        summary: "O'rtacha risk darajasi",
        limitations: ["Da'vo muddati 1 oy"],
        requiresLawyer: false,
        deadlineDays: 30,
      );

      final json = assessment.toJson();
      final fromJson = RiskAssessment.fromJson(json);

      expect(fromJson.level, RiskLevel.medium);
      expect(fromJson.summary, "O'rtacha risk darajasi");
      expect(fromJson.limitations.length, 1);
    });

    test('should correctly serialize and deserialize EmergencyProtocol', () {
      const emergency = EmergencyProtocol(
        isEmergency: true,
        title: "Tezkor Huquqiy Himoya",
        redFlags: ["Hibsga olish holati"],
        constitutionalRights: ["Miranda qoidasi"],
        immediateActions: ["Sukut saqlang"],
        emergencyHotline: "1002",
      );

      final json = emergency.toJson();
      final fromJson = EmergencyProtocol.fromJson(json);

      expect(fromJson.isEmergency, true);
      expect(fromJson.emergencyHotline, "1002");
      expect(fromJson.redFlags.first, "Hibsga olish holati");
    });

    test('should correctly serialize and deserialize full LegalResponse', () {
      final response = LegalResponse(
        id: "resp_123",
        queryId: "q_123",
        relatableSummary: "Ishdan bo'shatish noqonuniy",
        actionableSteps: const ["Sudga ariza bering"],
        legalBasis: const [
          LawArticle(
            lawName: "Mehnat kodeksi",
            articleNumber: "161-modda",
            articleTitle: "Asoslar",
            articleText: "Matn",
            lexUrl: "https://lex.uz",
          ),
        ],
        riskAssessment: const RiskAssessment(
          level: RiskLevel.low,
          summary: "Past xavf",
        ),
        emergencyProtocol: const EmergencyProtocol(
          isEmergency: false,
          title: "Oddiy holat",
        ),
        createdAt: DateTime.parse("2026-08-14T20:00:00.000Z"),
        isSaved: true,
      );

      final json = response.toJson();
      final fromJson = LegalResponse.fromJson(json);

      expect(fromJson.id, "resp_123");
      expect(fromJson.relatableSummary, "Ishdan bo'shatish noqonuniy");
      expect(fromJson.legalBasis.length, 1);
      expect(fromJson.riskAssessment.level, RiskLevel.low);
      expect(fromJson.isSaved, true);
    });
  });

  /// HALOLLIK INVARIANTI: `source` maydoni UI'da "AI tahlili" yorlig'ini
  /// yoqadi/o'chiradi (`legal_assistant_page.dart` badge'i). Agar bu maydon
  /// jimgina `llm` bo'lib qolsa, DETERMINISTIK javob (qurilmadagi qoidalar)
  /// "AI" deb ko'rsatiladi — bu foydalanuvchini chalg'itish va CLAUDE.md §0
  /// buzilishi. Shuning uchun fail-closed xatti-harakat TESTLANADI.
  group('LegalResponse.source — javob manbasi halolligi', () {
    LegalResponse build({String? source}) => LegalResponse(
          id: 'r1',
          queryId: 'q1',
          relatableSummary: 'Xulosa',
          riskAssessment: const RiskAssessment(
            level: RiskLevel.low,
            summary: 'Past xavf',
          ),
          createdAt: DateTime.parse('2026-08-25T10:00:00.000Z'),
          source: source ?? LegalResponse.sourceDeterministic,
        );

    test('standart qiymat deterministic — isbotsiz "AI" da\'vosi yo\'q', () {
      final response = LegalResponse(
        id: 'r1',
        queryId: 'q1',
        relatableSummary: 'Xulosa',
        riskAssessment: const RiskAssessment(
          level: RiskLevel.low,
          summary: 'Past xavf',
        ),
        createdAt: DateTime.parse('2026-08-25T10:00:00.000Z'),
      );
      expect(response.source, LegalResponse.sourceDeterministic);
      expect(response.isAiGenerated, isFalse);
    });

    test('fromJson: AYNAN "llm" -> AI deb belgilanadi', () {
      final json = build(source: LegalResponse.sourceLlm).toJson();
      final parsed = LegalResponse.fromJson(json);
      expect(parsed.source, LegalResponse.sourceLlm);
      expect(parsed.isAiGenerated, isTrue);
    });

    test('fromJson: source YO\'Q -> deterministic', () {
      final json = build().toJson()..remove('source');
      expect(LegalResponse.fromJson(json).isAiGenerated, isFalse);
    });

    test('fromJson: tanilmagan qiymatlar FAIL-CLOSED (deterministic)', () {
      // 'LLM' (registr), 'gemini', 'ai', bo'sh satr, hatto `true` — hech
      // biri "AI" yorlig'ini bermasligi kerak.
      for (final raw in <Object>['LLM', 'gemini', 'ai', '', 'model', true]) {
        final json = build().toJson()..['source'] = raw;
        final parsed = LegalResponse.fromJson(json);
        expect(parsed.source, LegalResponse.sourceDeterministic,
            reason: '"$raw" qiymati AI yorlig\'ini bermasligi kerak');
        expect(parsed.isAiGenerated, isFalse);
      }
    });

    test('fromJson: `response_source` alias ham qabul qilinadi', () {
      final json = build().toJson()
        ..remove('source')
        ..['response_source'] = LegalResponse.sourceLlm;
      expect(LegalResponse.fromJson(json).isAiGenerated, isTrue);
    });

    test('toJson source ni saqlaydi (round-trip)', () {
      final json = build(source: LegalResponse.sourceLlm).toJson();
      expect(json['source'], LegalResponse.sourceLlm);
    });

    test('copyWith source ni almashtiradi', () {
      final copy = build().copyWith(source: LegalResponse.sourceLlm);
      expect(copy.isAiGenerated, isTrue);
    });

    test('props source ni hisobga oladi — BLoC yangi state chiqaradi', () {
      // Agar `source` `props` ichida bo'lmasa, Equatable ikkala javobni TENG
      // deb hisoblaydi va bloc state o'zgarmaganda badge YANGILANMAYDI.
      expect(build(), isNot(equals(build(source: LegalResponse.sourceLlm))));
    });
  });
}
