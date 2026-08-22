import 'package:equatable/equatable.dart';

abstract class ConsultationEvent extends Equatable {
  const ConsultationEvent();

  @override
  List<Object?> get props => [];
}

class LoadExpertSlotsEvent extends ConsultationEvent {
  final String expertId;
  final DateTime date;

  const LoadExpertSlotsEvent({
    required this.expertId,
    required this.date,
  });

  @override
  List<Object?> get props => [expertId, date];
}

class BookConsultationEvent extends ConsultationEvent {
  final String expertId;
  final DateTime scheduledAt;
  final String meetingType;
  final String? notes;
  final String? questionId;
  final String provider;

  const BookConsultationEvent({
    required this.expertId,
    required this.scheduledAt,
    this.meetingType = 'online',
    this.notes,
    this.questionId,
    this.provider = 'payme',
  });

  @override
  List<Object?> get props => [
        expertId,
        scheduledAt,
        meetingType,
        notes,
        questionId,
        provider,
      ];
}

class ConfirmPaymentEvent extends ConsultationEvent {
  final String paymentId;
  final String provider;
  final String providerTransactionId;
  final int paidAmountTiyin;

  const ConfirmPaymentEvent({
    required this.paymentId,
    required this.provider,
    required this.providerTransactionId,
    required this.paidAmountTiyin,
  });

  @override
  List<Object?> get props => [
        paymentId,
        provider,
        providerTransactionId,
        paidAmountTiyin,
      ];
}

class LoadMyConsultationsEvent extends ConsultationEvent {
  const LoadMyConsultationsEvent();
}

class CancelConsultationEvent extends ConsultationEvent {
  final String consultationId;
  final String reason;

  const CancelConsultationEvent({
    required this.consultationId,
    required this.reason,
  });

  @override
  List<Object?> get props => [consultationId, reason];
}
