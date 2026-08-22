import 'package:equatable/equatable.dart';

class ConsultationSlot extends Equatable {
  final DateTime slotTime;
  final bool isAvailable;
  final int durationMinutes;
  final double priceAmountUzs;

  const ConsultationSlot({
    required this.slotTime,
    required this.isAvailable,
    this.durationMinutes = 45,
    required this.priceAmountUzs,
  });

  @override
  List<Object?> get props => [
        slotTime,
        isAvailable,
        durationMinutes,
        priceAmountUzs,
      ];
}

class PaymentCheckoutResult extends Equatable {
  final bool success;
  final String consultationId;
  final String paymentId;
  final String idempotencyKey;
  final double priceAmountUzs;
  final int priceAmountTiyin;
  final double commissionAmountUzs;
  final String expertName;
  final DateTime scheduledAt;
  final String status;
  final String provider;
  final String? checkoutUrl;

  const PaymentCheckoutResult({
    required this.success,
    required this.consultationId,
    required this.paymentId,
    required this.idempotencyKey,
    required this.priceAmountUzs,
    required this.priceAmountTiyin,
    this.commissionAmountUzs = 0.0,
    required this.expertName,
    required this.scheduledAt,
    required this.status,
    required this.provider,
    this.checkoutUrl,
  });

  @override
  List<Object?> get props => [
        success,
        consultationId,
        paymentId,
        idempotencyKey,
        priceAmountUzs,
        priceAmountTiyin,
        commissionAmountUzs,
        expertName,
        scheduledAt,
        status,
        provider,
        checkoutUrl,
      ];
}
