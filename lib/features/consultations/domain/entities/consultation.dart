import 'package:equatable/equatable.dart';

enum ConsultationStatus {
  pending,
  awaitingPayment,
  confirmed,
  inProgress,
  completed,
  cancelled,
  expired,
  disputed,
}

/// §16: `displayName` getter'i O'CHIRILDI — u domain qatlamida o'zbek
/// matnini saqlagan va ingliz tilida ham o'zbekcha ko'rinardi. Ekran
/// yorlig'i uchun `consultationStatusLabel(l10n, status)` ishlatiladi
/// (`lib/core/localization/consultation_labels.dart`).
///
/// `fromString` — DB kontrakti, XOM qiymatlar o'sha-o'sha qoladi.
extension ConsultationStatusExtension on ConsultationStatus {
  static ConsultationStatus fromString(String? value) {
    switch (value) {
      case 'awaiting_payment':
        return ConsultationStatus.awaitingPayment;
      case 'confirmed':
        return ConsultationStatus.confirmed;
      case 'in_progress':
        return ConsultationStatus.inProgress;
      case 'completed':
        return ConsultationStatus.completed;
      case 'cancelled':
        return ConsultationStatus.cancelled;
      case 'expired':
        return ConsultationStatus.expired;
      case 'disputed':
        return ConsultationStatus.disputed;
      case 'pending':
      default:
        return ConsultationStatus.pending;
    }
  }
}

enum PaymentStatus {
  pending,
  processing,
  paid,
  failed,
  refunding,
  refunded,
  partiallyRefunded,
}

/// §16 + §3: `displayName` getter'i O'CHIRILDI. U (a) domain qatlamida
/// o'zbek matnini saqlagan va (b) UI'da HECH QAYERDA ishlatilmagan —
/// ya'ni o'lik kod bo'lgan. `payments.status` ekranda ko'rsatilishi kerak
/// bo'lsa, yorliq ARB'ga qo'shiladi, bu yerga QAYTARILMAYDI.
///
/// `fromString` — DB kontrakti, XOM qiymatlar o'sha-o'sha qoladi.
extension PaymentStatusExtension on PaymentStatus {
  static PaymentStatus fromString(String? value) {
    switch (value) {
      case 'processing':
        return PaymentStatus.processing;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunding':
        return PaymentStatus.refunding;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'partially_refunded':
        return PaymentStatus.partiallyRefunded;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }
}

class Consultation extends Equatable {
  final String id;
  final String citizenId;
  final String expertId;
  final String? expertName;
  final String? specialization;
  final String? citizenName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final double priceAmountUzs;
  final int priceAmountTiyin;
  final double commissionAmountUzs;
  final double expertPayoutAmountUzs;
  final ConsultationStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentId;
  final String? meetingLink;
  final String meetingType;
  final String? notes;
  final String? cancellationReason;
  final double refundAmountUzs;
  final DateTime createdAt;

  const Consultation({
    required this.id,
    required this.citizenId,
    required this.expertId,
    this.expertName,
    this.specialization,
    this.citizenName,
    required this.scheduledAt,
    this.durationMinutes = 45,
    required this.priceAmountUzs,
    required this.priceAmountTiyin,
    this.commissionAmountUzs = 0.0,
    this.expertPayoutAmountUzs = 0.0,
    this.status = ConsultationStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentId,
    this.meetingLink,
    this.meetingType = 'online',
    this.notes,
    this.cancellationReason,
    this.refundAmountUzs = 0.0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        citizenId,
        expertId,
        expertName,
        specialization,
        citizenName,
        scheduledAt,
        durationMinutes,
        priceAmountUzs,
        priceAmountTiyin,
        commissionAmountUzs,
        expertPayoutAmountUzs,
        status,
        paymentStatus,
        paymentId,
        meetingLink,
        meetingType,
        notes,
        cancellationReason,
        refundAmountUzs,
        createdAt,
      ];
}
