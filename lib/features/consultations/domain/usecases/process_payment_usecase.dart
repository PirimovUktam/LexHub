import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/consultations/domain/repositories/consultation_repository.dart';

class ProcessPaymentParams extends Equatable {
  final String paymentId;
  final String provider;
  final String providerTransactionId;
  final int paidAmountTiyin;
  final String status;
  final String? errorMessage;

  const ProcessPaymentParams({
    required this.paymentId,
    required this.provider,
    required this.providerTransactionId,
    required this.paidAmountTiyin,
    this.status = 'paid',
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        paymentId,
        provider,
        providerTransactionId,
        paidAmountTiyin,
        status,
        errorMessage,
      ];
}

class ProcessPaymentUseCase
    implements UseCase<Map<String, dynamic>, ProcessPaymentParams> {
  final ConsultationRepository repository;

  ProcessPaymentUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      ProcessPaymentParams params) async {
    return repository.processPaymentWebhook(
      paymentId: params.paymentId,
      provider: params.provider,
      providerTransactionId: params.providerTransactionId,
      paidAmountTiyin: params.paidAmountTiyin,
      status: params.status,
      errorMessage: params.errorMessage,
    );
  }
}
