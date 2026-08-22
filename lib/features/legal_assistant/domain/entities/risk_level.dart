import 'package:json_annotation/json_annotation.dart';

/// Risk levels for legal cases and queries
enum RiskLevel {
  @JsonValue('low')
  low,

  @JsonValue('medium')
  medium,

  @JsonValue('high')
  high,

  @JsonValue('critical')
  critical;

  /// UI YORLIG'I ATAYLAB BU YERDA YO'Q.
  ///
  /// Ilgari `displayName` getter'i o'zbek matnini domain qatlamida saqlagan
  /// (`'Past xavf'` ...). Ko'p tilli interfeysda bu yorliq tanlangan tilga
  /// bog'liq bo'lishi kerak, shuning uchun u
  /// `lib/core/localization/legal_ai_labels.dart` -> `riskLevelLabel()`
  /// ichiga ko'chirildi. `@JsonValue` qiymatlari esa kontrakt — TARJIMA
  /// QILINMAYDI.
  bool get isHighOrCritical => this == RiskLevel.high || this == RiskLevel.critical;
}
