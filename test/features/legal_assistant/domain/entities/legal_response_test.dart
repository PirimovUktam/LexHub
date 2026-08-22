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
}
