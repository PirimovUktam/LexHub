import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/consultations/data/datasources/consultation_remote_datasource.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';

/// §6: bu repository'da JIMJIT mock fallback YO'Q — `localDataSource`
/// maydoni butunlay olib tashlandi (to'qilgan konsultatsiya/to'lov
/// ma'lumotlari bilan birga). Xato -> `Left(Failure)` -> UI xato + retry.
class ConsultationRepositoryImpl implements ConsultationRepository {
  final ConsultationRemoteDataSource remoteDataSource;

  ConsultationRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, List<ConsultationSlot>>> getExpertAvailableSlots({
    required String expertId,
    required DateTime date,
  }) async {
    try {
      final slots = await remoteDataSource.getAvailableSlots(
        expertId: expertId,
        date: date,
      );
      return Right(slots);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
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
    try {
      final result = await remoteDataSource.bookConsultation(
        expertId: expertId,
        scheduledAt: scheduledAt,
        meetingType: meetingType,
        notes: notes,
        questionId: questionId,
        provider: provider,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
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
    try {
      final result = await remoteDataSource.processPaymentWebhook(
        paymentId: paymentId,
        provider: provider,
        providerTransactionId: providerTransactionId,
        paidAmountTiyin: paidAmountTiyin,
        status: status,
        errorMessage: errorMessage,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<Consultation>>> getMyConsultations() async {
    try {
      final list = await remoteDataSource.getMyConsultations();
      return Right(list);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> cancelConsultation({
    required String consultationId,
    String reason = 'Foydalanuvchi tomonidan bekor qilindi',
  }) async {
    try {
      final result = await remoteDataSource.cancelConsultation(
        consultationId: consultationId,
        reason: reason,
      );
      return Right(result);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
