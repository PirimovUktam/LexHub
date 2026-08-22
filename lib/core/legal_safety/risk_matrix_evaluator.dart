import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

/// Risk Matrix Evaluator to prevent false confidence and evaluate realistic litigation outcomes
class RiskMatrixEvaluator {
  RiskMatrixEvaluator._();

  /// Evaluates risk profile based on case context, presence of written evidence, and procedural complexity
  static RiskAssessment evaluate({
    required String queryText,
    required bool hasWrittenEvidence,
    required bool isEmergency,
    int? explicitDeadlineDays,
  }) {
    if (isEmergency) {
      return RiskAssessment(
        level: RiskLevel.critical,
        summary: "Kritik xavf mavjud. Erkinlik cheklanishi yoki tergov harakatlari bo'yicha mustaqil harakat qilish qat'iyan taqiqlanadi.",
        limitations: const [
          "Advokat ishtirokisiz ko'rsatma berish jiddiy huquqiy oqibatlarga olib kelishi mumkin.",
          "Har qanday bayonnoma (protokol) bilan imzolashdan oldin to'liq tanishib chiqish shart.",
        ],
        requiresLawyer: true,
        deadlineDays: explicitDeadlineDays ?? 2,
      );
    }

    final lower = queryText.toLowerCase();

    // High Risk: Criminal or heavy disputes without documentation
    if (lower.contains('jinoyat') || lower.contains('tergov') || (!hasWrittenEvidence && (lower.contains('qarz') || lower.contains('shartnoma')))) {
      return RiskAssessment(
        level: RiskLevel.high,
        summary: "Yuqori xavf mavjud. Yozma hujjatlar (tilxat, shartnoma) yetarli bo'lmaganda yoki jinoyat ishlari bo'yicha sud orqali isbotlash murakkab.",
        limitations: const [
          "Og'zaki kelishuvlar sud tomonidan qabul qilinmasligi mumkin.",
          "Davlat boji va sud xarajatlari xavfi mavjud.",
        ],
        requiresLawyer: true,
        deadlineDays: explicitDeadlineDays,
      );
    }

    // Medium Risk: Labor or family disputes
    if (lower.contains('ishdan') || lower.contains('maosh') || lower.contains('mulk') || lower.contains('mehnat') || lower.contains('ish haqi')) {
      return RiskAssessment(
        level: RiskLevel.medium,
        summary: "O'rtacha xavf. Qonuniy da'vo muddati (1 oy) ichida murojaat qilinmasa, da'vo talabi bekor qilinishi mumkin.",
        limitations: const [
          "Ishdan bo'shatish bo'yicha da'vo muddati 1 oy.",
          "Ish beruvchining yozma buyrug'i talab etiladi.",
        ],
        requiresLawyer: false,
        deadlineDays: explicitDeadlineDays ?? 30,
      );
    }

    // Low Risk: Standard consumer rights or civil queries
    return RiskAssessment(
      level: RiskLevel.low,
      summary: "Past xavf darajasi. Rasmiy tartibda ariza yoki pretenziya topshirish orqali nizoni sudgacha hal etish ehtimoli yuqori.",
      limitations: const [
        "Javob berish muddati 15 kundan 1 oygacha.",
      ],
      requiresLawyer: false,
      deadlineDays: explicitDeadlineDays,
    );
  }
}
