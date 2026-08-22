import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';

class DetectEmergencyUseCase implements UseCase<EmergencyProtocol?, String> {
  final LegalAssistantRepository repository;

  DetectEmergencyUseCase(this.repository);

  @override
  Future<Either<Failure, EmergencyProtocol?>> call(String queryText) async {
    return await repository.detectEmergency(queryText);
  }
}
