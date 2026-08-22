import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';

/// §6: bu parser HECH QANDAY qiymatni o'ylab topmaydi.
///
/// Ilgari `scheduled_at` yoki `created_at` bo'lmasa `DateTime.now()`
/// qo'yilardi — ya'ni foydalanuvchi NOTO'G'RI uchrashuv vaqtini ko'rishi
/// mumkin edi. Bu ustunlar `consultations` jadvalida NOT NULL, shuning uchun
/// ularning yo'qligi = server javobi FORMATI xato -> `ServerException`.
class ConsultationModel extends Consultation {
  const ConsultationModel({
    required super.id,
    required super.citizenId,
    required super.expertId,
    super.expertName,
    super.specialization,
    super.citizenName,
    required super.scheduledAt,
    super.durationMinutes = 45,
    required super.priceAmountUzs,
    required super.priceAmountTiyin,
    super.commissionAmountUzs = 0.0,
    super.expertPayoutAmountUzs = 0.0,
    super.status = ConsultationStatus.pending,
    super.paymentStatus = PaymentStatus.pending,
    super.paymentId,
    super.meetingLink,
    super.meetingType = 'online',
    super.notes,
    super.cancellationReason,
    super.refundAmountUzs = 0.0,
    required super.createdAt,
  });

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final rawScheduledAt = json['scheduled_at'];
    final scheduledAt = rawScheduledAt == null
        ? null
        : DateTime.tryParse(rawScheduledAt.toString());
    final rawCreatedAt = json['created_at'];
    final createdAt =
        rawCreatedAt == null ? null : DateTime.tryParse(rawCreatedAt.toString());

    if (id.isEmpty || scheduledAt == null || createdAt == null) {
      throw ServerException(
        message: "Konsultatsiya yozuvi to'liq emas (id/sana yetishmaydi).",
        details: json,
      );
    }

    final tiyin = json['price_amount_tiyin'] as int? ?? 0;
    final priceUzs = tiyin / 100.0;
    final commTiyin = json['commission_amount_tiyin'] as int? ?? 0;
    final payoutTiyin = json['expert_payout_amount_tiyin'] as int? ?? 0;
    final refundTiyin = json['refund_amount_tiyin'] as int? ?? 0;

    return ConsultationModel(
      id: id,
      citizenId: json['citizen_id'] as String? ?? '',
      expertId: json['expert_id'] as String? ?? '',
      expertName: json['expert_name'] as String?,
      specialization: json['specialization'] as String?,
      citizenName: json['citizen_name'] as String?,
      scheduledAt: scheduledAt,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      priceAmountUzs: priceUzs,
      priceAmountTiyin: tiyin,
      commissionAmountUzs: commTiyin / 100.0,
      expertPayoutAmountUzs: payoutTiyin / 100.0,
      status: ConsultationStatusExtension.fromString(json['status'] as String?),
      paymentStatus:
          PaymentStatusExtension.fromString(json['payment_status'] as String?),
      paymentId: json['payment_id'] as String?,
      meetingLink: json['meeting_link'] as String?,
      meetingType: json['meeting_type'] as String? ?? '',
      notes: json['notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      refundAmountUzs: refundTiyin / 100.0,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizen_id': citizenId,
      'expert_id': expertId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'price_amount_tiyin': priceAmountTiyin,
      'currency': 'UZS',
      'status': status.name,
      'payment_status': paymentStatus.name,
      'payment_id': paymentId,
      'meeting_link': meetingLink,
      'meeting_type': meetingType,
      'notes': notes,
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
