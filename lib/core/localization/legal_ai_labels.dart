// LexHub — LEGAL AI yorliqlari (UI label) va uzatiladigan QIYMATLAR chegarasi.
//
// QAT'IY QOIDA (§16): bu yerda FAQAT ekranda ko'rinadigan matn tarjima
// qilinadi. `RiskLevel` enum'ining JSON qiymatlari (`low`/`medium`/`high`/
// `critical`) va tezkor chip'larning `label` qiymati (u `SubmitLegalQueryEvent`
// ga `category` bo'lib ketadi) O'ZGARMAYDI.

import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// Risk darajasining UI yorlig'i (ilgari `RiskLevel.displayName` bo'lgan).
String riskLevelLabel(AppL10n l10n, RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return l10n.riskLevelLow;
    case RiskLevel.medium:
      return l10n.riskLevelMedium;
    case RiskLevel.high:
      return l10n.riskLevelHigh;
    case RiskLevel.critical:
      return l10n.riskLevelCritical;
  }
}

/// Legal AI sahifasidagi tezkor chip yorliqlari.
///
/// Kirish — chip'ning XOM `label` qiymati: u bir vaqtda so'rov kategoriyasi
/// sifatida ham uzatiladi, shuning uchun qiymat tarjima qilinmaydi, faqat
/// ekranda ko'rinadigan matn almashtiriladi. Noma'lum label o'zi qaytariladi.
String legalAiChipLabel(AppL10n l10n, String rawLabel) {
  switch (QuestionCategoryCatalog.normalizeName(rawLabel)) {
    case "ishdan nohaq bo'shatish":
      return l10n.aiChipUnfairDismissal;
    case "iste'molchi huquqi (tovarni qaytarish)":
      return l10n.aiChipConsumerReturn;
    case 'aliment undirish':
      return l10n.aiChipAlimony;
    case "yo'l harakati jarimasi":
      return l10n.aiChipTrafficFine;
    case 'qarz va tilxat':
      return l10n.aiChipDebtReceipt;
    default:
      return rawLabel;
  }
}
