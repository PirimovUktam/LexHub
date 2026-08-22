import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';

abstract class DocumentBuilderRepository {
  Future<Either<Failure, List<DocumentTemplate>>> getTemplates({String? category, String? searchQuery});
  Future<Either<Failure, DocumentTemplate>> getTemplateById(String id);
  Future<Either<Failure, SavedUserDocument>> saveUserDocument(SavedUserDocument document);
  Future<Either<Failure, List<SavedUserDocument>>> getUserDocuments();
  Future<Either<Failure, void>> deleteUserDocument(String documentId);
}
