import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';

abstract class ConsultationRepository {
  Future<Either<Failure, List<ConsultationSlot>>> getExpertAvailableSlots({
    required String expertId,
    required DateTime date,
  });

  Future<Either<Failure, PaymentCheckoutResult>> bookConsultation({
    required String expertId,
    required DateTime scheduledAt,
    String meetingType = 'online',
    String? notes,
    String? questionId,
    String provider = 'payme',
  });

  Future<Either<Failure, Map<String, dynamic>>> processPaymentWebhook({
    required String paymentId,
    required String provider,
    required String providerTransactionId,
    required int paidAmountTiyin,
    String status = 'paid',
    String? errorMessage,
  });

  Future<Either<Failure, List<Consultation>>> getMyConsultations();

  Future<Either<Failure, Map<String, dynamic>>> cancelConsultation({
    required String consultationId,
    String reason = 'Foydalanuvchi tomonidan bekor qilindi',
  });
}
