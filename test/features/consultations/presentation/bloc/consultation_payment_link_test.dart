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

/// §6 REGRESSION GUARD — TO'QIMA UCHRASHUV HAVOLASI.
///
/// `process_payment_webhook` uchrashuv havolasini FAQAT to'lov birinchi marta
/// tasdiqlanganda qaytaradi. Takroriy (idempotent) chaqiruvda javob
/// `{'success': true, 'is_duplicate': true, 'status': 'paid', ...}` bo'lib,
/// `meeting_link` UNDA YO'Q. Ilgari bloc bu holatda
/// `https://meet.lexhub.uz/room/<consultation_id>` havolasini O'ZI YASARDI —
/// ya'ni real production holatida foydalanuvchi MAVJUD BO'LMAGAN xonani
/// ko'rardi. Bu test o'sha to'qima havola qaytmasligini qo'riqlaydi.
class _StubConsultationRepository implements ConsultationRepository {
  _StubConsultationRepository(this.webhookResponse);

  final Map<String, dynamic> webhookResponse;

  @override
  Future<Either<Failure, Map<String, dynamic>>> processPaymentWebhook({
    required String paymentId,
    required String provider,
    required String providerTransactionId,
    required int paidAmountTiyin,
    String status = 'paid',
    String? errorMessage,
  }) async =>
      Right(webhookResponse);

  @override
  Future<Either<Failure, List<ConsultationSlot>>> getExpertAvailableSlots({
    required String expertId,
    required DateTime date,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, PaymentCheckoutResult>> bookConsultation({
    required String expertId,
    required DateTime scheduledAt,
    String meetingType = 'online',
    String? notes,
    String? questionId,
    String provider = 'payme',
  }) async =>
      const Left(ServerFailure(message: 'not used'));

  @override
  Future<Either<Failure, List<Consultation>>> getMyConsultations() async =>
      const Right([]);

  @override
  Future<Either<Failure, Map<String, dynamic>>> cancelConsultation({
    required String consultationId,
    String reason = 'Foydalanuvchi tomonidan bekor qilindi',
  }) async =>
      const Right({});
}

ConsultationBloc _blocWith(Map<String, dynamic> webhookResponse) {
  final repository = _StubConsultationRepository(webhookResponse);
  return ConsultationBloc(
    getExpertAvailableSlotsUseCase: GetExpertAvailableSlotsUseCase(repository),
    bookConsultationUseCase: BookConsultationUseCase(repository),
    processPaymentUseCase: ProcessPaymentUseCase(repository),
    getMyConsultationsUseCase: GetMyConsultationsUseCase(repository),
    cancelConsultationUseCase: CancelConsultationUseCase(repository),
  );
}

Future<ConsultationState> _confirmPayment(ConsultationBloc bloc) {
  final settled = bloc.stream.firstWhere(
    (s) => s is PaymentSuccessState || s is ConsultationErrorState,
  );
  bloc.add(
    const ConfirmPaymentEvent(
      paymentId: 'p1',
      provider: 'payme',
      providerTransactionId: 'tx_1',
      paidAmountTiyin: 20000000,
    ),
  );
  return settled;
}

void main() {
  group('§6: PaymentSuccessState.meetingLink', () {
    test('server havola bergan holat -> aynan o\'sha havola', () async {
      final bloc = _blocWith(const {
        'success': true,
        'consultation_id': 'c1',
        'status': 'confirmed',
        'meeting_link': 'https://real.example.uz/room/abc',
      });
      addTearDown(bloc.close);

      final state = await _confirmPayment(bloc);

      expect(state, isA<PaymentSuccessState>());
      expect((state as PaymentSuccessState).meetingLink,
          'https://real.example.uz/room/abc');
    });

    test('IDEMPOTENT takroriy to\'lov (meeting_link YO\'Q) -> null', () async {
      // `process_payment_webhook` ning haqiqiy takroriy javobi.
      final bloc = _blocWith(const {
        'success': true,
        'is_duplicate': true,
        'message': 'Payment already processed successfully.',
        'consultation_id': 'c1',
        'status': 'paid',
      });
      addTearDown(bloc.close);

      final state = await _confirmPayment(bloc);

      expect(state, isA<PaymentSuccessState>());
      final link = (state as PaymentSuccessState).meetingLink;
      expect(link, isNull,
          reason: "Havola YO'Q bo'lsa, u O'YLAB TOPILMASLIGI kerak.");
      expect(state.props.join(), isNot(contains('meet.lexhub.uz')));
    });

    test('bo\'sh `meeting_link` -> null (bo\'sh havola ko\'rsatilmaydi)', () async {
      final bloc = _blocWith(const {
        'success': true,
        'consultation_id': 'c1',
        'meeting_link': '',
      });
      addTearDown(bloc.close);

      final state = await _confirmPayment(bloc);

      expect((state as PaymentSuccessState).meetingLink, isNull);
    });

    test("`consultation_id` yo'q -> ConsultationErrorState (fail-closed)",
        () async {
      final bloc = _blocWith(const {'success': true, 'status': 'paid'});
      addTearDown(bloc.close);

      final state = await _confirmPayment(bloc);

      expect(state, isA<ConsultationErrorState>(),
          reason: "Konsultatsiya raqami yo'q bo'lsa, 'muvaffaqiyat' ekrani "
              'ko\'rsatilmaydi.');
    });
  });
}
