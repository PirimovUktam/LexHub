import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';

class GetLegalAdviceUseCase implements UseCase<LegalResponse, GetLegalAdviceParams> {
  final LegalAssistantRepository repository;

  GetLegalAdviceUseCase(this.repository);

  @override
  Future<Either<Failure, LegalResponse>> call(GetLegalAdviceParams params) async {
    if (params.queryText.trim().isEmpty) {
      return const Left(ValidationFailure(
        message: "Iltimos, yuridik savol yoki vaziyatingizni yozing.",
      ));
    }

    final query = LegalQuery(
      id: params.id,
      queryText: params.queryText.trim(),
      category: params.category,
      createdAt: DateTime.now(),
    );

    return await repository.getLegalAdvice(query);
  }
}

class GetLegalAdviceParams extends Equatable {
  final String id;
  final String queryText;
  final String? category;

  const GetLegalAdviceParams({
    required this.id,
    required this.queryText,
    this.category,
  });

  @override
  List<Object?> get props => [id, queryText, category];
}
