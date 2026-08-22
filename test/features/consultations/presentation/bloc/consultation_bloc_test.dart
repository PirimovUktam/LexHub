import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';
import 'package:lexhub/features/consultations/domain/usecases/book_consultation_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/get_expert_available_slots_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/get_my_consultations_usecase.dart';
import 'package:lexhub/features/consultations/domain/usecases/process_payment_usecase.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_bloc.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_event.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_state.dart';

class MockConsultationRepository implements ConsultationRepository {
  @override
  Future<Either<Failure, List<ConsultationSlot>>> getExpertAvailableSlots({
    required String expertId,
    required DateTime date,
  }) async {
    return Right([
      ConsultationSlot(
        slotTime: DateTime(2026, 8, 25, 10, 0),
        isAvailable: true,
        priceAmountUzs: 200000.0,
      ),
    ]);
  }

  @override
  Future<Either<Failure, PaymentCheckoutResult>> bookConsultation({
    required String expertId,
    required DateTime scheduledAt,
    String meetingType = 'online',
    String? notes,
    String? questionId,
    String provider = 'payme',
  }) async {
    return Right(
      PaymentCheckoutResult(
        success: true,
        consultationId: 'c_test_1',
        paymentId: 'p_test_1',
        idempotencyKey: 'idem_1',
        priceAmountUzs: 200000.0,
        priceAmountTiyin: 20000000,
        commissionAmountUzs: 20000.0,
        expertName: 'Test Expert',
        scheduledAt: scheduledAt,
        status: 'awaiting_payment',
        provider: provider,
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> processPaymentWebhook({
    required String paymentId,
    required String provider,
    required String providerTransactionId,
    required int paidAmountTiyin,
    String status = 'paid',
    String? errorMessage,
  }) async {
    return const Right({
      'success': true,
      'consultation_id': 'c_test_1',
      'payment_id': 'p_test_1',
      'status': 'confirmed',
      'payment_status': 'paid',
      'meeting_link': 'https://meet.lexhub.uz/room/c_test_1',
    });
  }

  @override
  Future<Either<Failure, List<Consultation>>> getMyConsultations() async {
    return Right([
      Consultation(
        id: 'c_test_1',
        citizenId: 'user_1',
        expertId: 'expert_1',
        expertName: 'Test Expert',
        scheduledAt: DateTime(2026, 8, 25, 10, 0),
        priceAmountUzs: 200000.0,
        priceAmountTiyin: 20000000,
        status: ConsultationStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        createdAt: DateTime(2026, 8, 21),
      ),
    ]);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> cancelConsultation({
    required String consultationId,
    String reason = 'Foydalanuvchi tomonidan bekor qilindi',
  }) async {
    return const Right({
      'success': true,
      'consultation_id': 'c_test_1',
      'status': 'cancelled',
      'refund_percent': 100,
      'refund_amount_uzs': 200000.0,
    });
  }
}

void main() {
  late MockConsultationRepository repository;
  late ConsultationBloc bloc;

  setUp(() {
    repository = MockConsultationRepository();
    bloc = ConsultationBloc(
      getExpertAvailableSlotsUseCase: GetExpertAvailableSlotsUseCase(repository),
      bookConsultationUseCase: BookConsultationUseCase(repository),
      processPaymentUseCase: ProcessPaymentUseCase(repository),
      getMyConsultationsUseCase: GetMyConsultationsUseCase(repository),
      cancelConsultationUseCase: CancelConsultationUseCase(repository),
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('Sprint 9: ConsultationBloc State Tests', () {
    test('1. Emits SlotsLoadedState on LoadExpertSlotsEvent', () async {
      final date = DateTime(2026, 8, 25);
      final expected = [
        const ConsultationLoadingState(),
        isA<SlotsLoadedState>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(LoadExpertSlotsEvent(expertId: 'expert_1', date: date));
    });

    test('2. Emits BookingInitiatedState on BookConsultationEvent', () async {
      final scheduledAt = DateTime(2026, 8, 25, 10, 0);
      final expected = [
        const ConsultationLoadingState(),
        isA<BookingInitiatedState>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(
        BookConsultationEvent(
          expertId: 'expert_1',
          scheduledAt: scheduledAt,
          provider: 'payme',
        ),
      );
    });

    test('3. Emits PaymentProcessingState and PaymentSuccessState on ConfirmPaymentEvent', () async {
      final expected = [
        const PaymentProcessingState(),
        isA<PaymentSuccessState>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(
        const ConfirmPaymentEvent(
          paymentId: 'p_test_1',
          provider: 'payme',
          providerTransactionId: 'tx_payme_999',
          paidAmountTiyin: 20000000,
        ),
      );
    });

    test('4. Emits MyConsultationsLoadedState on LoadMyConsultationsEvent', () async {
      final expected = [
        const ConsultationLoadingState(),
        isA<MyConsultationsLoadedState>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const LoadMyConsultationsEvent());
    });
  });
}
