import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/repositories/document_builder_repository.dart';

class GetDocumentTemplatesUseCase implements UseCase<List<DocumentTemplate>, String?> {
  final DocumentBuilderRepository repository;

  GetDocumentTemplatesUseCase(this.repository);

  @override
  Future<Either<Failure, List<DocumentTemplate>>> call(String? category, {String? searchQuery}) async {
    return await repository.getTemplates(category: category, searchQuery: searchQuery);
  }
}

class GetTemplateByIdUseCase implements UseCase<DocumentTemplate, String> {
  final DocumentBuilderRepository repository;

  GetTemplateByIdUseCase(this.repository);

  @override
  Future<Either<Failure, DocumentTemplate>> call(String id) async {
    return await repository.getTemplateById(id);
  }
}
