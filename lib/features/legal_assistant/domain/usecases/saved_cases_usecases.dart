import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';

class SaveCaseUseCase implements UseCase<void, LegalResponse> {
  final LegalAssistantRepository repository;

  SaveCaseUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(LegalResponse response) async {
    return await repository.saveCase(response);
  }
}

class GetSavedCasesUseCase implements UseCase<List<LegalResponse>, NoParams> {
  final LegalAssistantRepository repository;

  GetSavedCasesUseCase(this.repository);

  @override
  Future<Either<Failure, List<LegalResponse>>> call(NoParams params) async {
    return await repository.getSavedCases();
  }
}

class DeleteSavedCaseUseCase implements UseCase<void, String> {
  final LegalAssistantRepository repository;

  DeleteSavedCaseUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteSavedCase(id);
  }
}
