import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/book_consultation_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/get_expert_available_slots_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/get_my_consultations_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/process_payment_usecase.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_event.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_state.dart';

class ConsultationBloc extends Bloc<ConsultationEvent, ConsultationState> {
  final GetExpertAvailableSlotsUseCase getExpertAvailableSlotsUseCase;
  final BookConsultationUseCase bookConsultationUseCase;
  final ProcessPaymentUseCase processPaymentUseCase;
  final GetMyConsultationsUseCase getMyConsultationsUseCase;
  final CancelConsultationUseCase cancelConsultationUseCase;

  ConsultationBloc({
    required this.getExpertAvailableSlotsUseCase,
    required this.bookConsultationUseCase,
    required this.processPaymentUseCase,
    required this.getMyConsultationsUseCase,
    required this.cancelConsultationUseCase,
  }) : super(const ConsultationInitialState()) {
    on<LoadExpertSlotsEvent>(_onLoadExpertSlots);
    on<BookConsultationEvent>(_onBookConsultation);
    on<ConfirmPaymentEvent>(_onConfirmPayment);
    on<LoadMyConsultationsEvent>(_onLoadMyConsultations);
    on<CancelConsultationEvent>(_onCancelConsultation);
  }

  Future<void> _onLoadExpertSlots(
    LoadExpertSlotsEvent event,
    Emitter<ConsultationState> emit,
  ) async {
    emit(const ConsultationLoadingState());
    final result = await getExpertAvailableSlotsUseCase(
      GetExpertAvailableSlotsParams(
        expertId: event.expertId,
        date: event.date,
      ),
    );

    result.fold(
      (failure) => emit(ConsultationErrorState(failure.message, code: failure.code)),
      (slots) => emit(SlotsLoadedState(slots: slots, selectedDate: event.date)),
    );
  }

  Future<void> _onBookConsultation(
    BookConsultationEvent event,
    Emitter<ConsultationState> emit,
  ) async {
    emit(const ConsultationLoadingState());
    final result = await bookConsultationUseCase(
      BookConsultationParams(
        expertId: event.expertId,
        scheduledAt: event.scheduledAt,
        meetingType: event.meetingType,
        notes: event.notes,
        questionId: event.questionId,
        provider: event.provider,
      ),
    );

    result.fold(
      (failure) => emit(ConsultationErrorState(failure.message, code: failure.code)),
      (checkout) => emit(BookingInitiatedState(checkout)),
    );
  }

  /// §6: TO'QIMA UCHRASHUV HAVOLASI OLIB TASHLANDI.
  ///
  /// Ilgari bu handler `meeting_link` bo'lmasa
  /// `'https://meet.lexhub.uz/room/<consultation_id>'` havolasini O'ZI
  /// YASARDI. `process_payment_webhook` idempotent tarmog'i (to'lov allaqachon
  /// `paid` bo'lsa) `meeting_link` NI QAYTARMAYDI, ya'ni bu mavjud bo'lmagan
  /// havola real foydalanuvchiga ko'rinardi. Endi: havola faqat serverdan.
  ///
  /// `consultation_id` bo'sh bo'lsa — bu server javobi FORMATI xatosi, shuning
  /// uchun "muvaffaqiyat" ekrani emas, XATO ko'rsatiladi (fail-closed).
  Future<void> _onConfirmPayment(
    ConfirmPaymentEvent event,
    Emitter<ConsultationState> emit,
  ) async {
    emit(const PaymentProcessingState());
    final result = await processPaymentUseCase(
      ProcessPaymentParams(
        paymentId: event.paymentId,
        provider: event.provider,
        providerTransactionId: event.providerTransactionId,
        paidAmountTiyin: event.paidAmountTiyin,
        status: 'paid',
      ),
    );

    result.fold(
      (failure) => emit(ConsultationErrorState(failure.message, code: failure.code)),
      (res) {
        final consultationId = res['consultation_id'] as String? ?? '';
        if (consultationId.isEmpty) {
          emit(
            const ConsultationErrorState(
              "To'lov javobi to'liq emas (konsultatsiya raqami yo'q). "
              "Iltimos, 'Mening konsultatsiyalarim' bo'limini tekshiring.",
            ),
          );
          return;
        }
        final rawLink = res['meeting_link'] as String?;
        emit(
          PaymentSuccessState(
            consultationId: consultationId,
            meetingLink:
                (rawLink == null || rawLink.isEmpty) ? null : rawLink,
          ),
        );
      },
    );
  }

  Future<void> _onLoadMyConsultations(
    LoadMyConsultationsEvent event,
    Emitter<ConsultationState> emit,
  ) async {
    emit(const ConsultationLoadingState());
    final result = await getMyConsultationsUseCase(const NoParams());

    result.fold(
      (failure) => emit(ConsultationErrorState(failure.message, code: failure.code)),
      (consultations) => emit(MyConsultationsLoadedState(consultations)),
    );
  }

  Future<void> _onCancelConsultation(
    CancelConsultationEvent event,
    Emitter<ConsultationState> emit,
  ) async {
    emit(const ConsultationLoadingState());
    final result = await cancelConsultationUseCase(
      CancelConsultationParams(
        consultationId: event.consultationId,
        reason: event.reason,
      ),
    );

    result.fold(
      (failure) => emit(ConsultationErrorState(failure.message, code: failure.code)),
      (res) {
        emit(
          ConsultationCancelledState(
            consultationId: event.consultationId,
            refundAmountUzs:
                (res['refund_amount_uzs'] as num? ?? 0.0).toDouble(),
          ),
        );
        add(const LoadMyConsultationsEvent());
      },
    );
  }
}
