import 'package:equatable/equatable.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';

abstract class ConsultationState extends Equatable {
  const ConsultationState();

  @override
  List<Object?> get props => [];
}

class ConsultationInitialState extends ConsultationState {
  const ConsultationInitialState();
}

class ConsultationLoadingState extends ConsultationState {
  const ConsultationLoadingState();
}

class SlotsLoadedState extends ConsultationState {
  final List<ConsultationSlot> slots;
  final DateTime selectedDate;

  const SlotsLoadedState({
    required this.slots,
    required this.selectedDate,
  });

  @override
  List<Object?> get props => [slots, selectedDate];
}

class BookingInitiatedState extends ConsultationState {
  final PaymentCheckoutResult checkoutResult;

  const BookingInitiatedState(this.checkoutResult);

  @override
  List<Object?> get props => [checkoutResult];
}

class PaymentProcessingState extends ConsultationState {
  const PaymentProcessingState();
}

/// §6: `meetingLink` NULLABLE.
///
/// Ilgari bloc `res['meeting_link']` bo'lmasa
/// `'https://meet.lexhub.uz/room/${consultation_id}'` degan havolani
/// O'YLAB TOPARDI. `process_payment_webhook` esa idempotent (takroriy
/// to'lov) holatida `meeting_link` NI QAYTARMAYDI — ya'ni bu to'qima
/// havola real production holatida ko'rinardi. Endi havola bo'lmasa UI
/// halol xabar ko'rsatadi.
class PaymentSuccessState extends ConsultationState {
  final String consultationId;
  final String? meetingLink;

  const PaymentSuccessState({
    required this.consultationId,
    this.meetingLink,
  });

  @override
  List<Object?> get props => [consultationId, meetingLink];
}

class MyConsultationsLoadedState extends ConsultationState {
  final List<Consultation> consultations;

  const MyConsultationsLoadedState(this.consultations);

  @override
  List<Object?> get props => [consultations];
}

class ConsultationCancelledState extends ConsultationState {
  final String consultationId;
  final double refundAmountUzs;

  const ConsultationCancelledState({
    required this.consultationId,
    required this.refundAmountUzs,
  });

  @override
  List<Object?> get props => [consultationId, refundAmountUzs];
}

class ConsultationErrorState extends ConsultationState {
  final String message;

  const ConsultationErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
