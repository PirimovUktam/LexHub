import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_remote_datasource.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';
import 'package:lexhub/features/document_builder/domain/repositories/document_builder_repository.dart';

class DocumentBuilderRepositoryImpl implements DocumentBuilderRepository {
  final DocumentTemplatesRemoteDataSource remoteDataSource;
  final DocumentTemplatesLocalDataSource localDataSource;

  List<DocumentTemplate>? _cachedTemplates;
  DateTime? _lastCacheTime;

  DocumentBuilderRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<DocumentTemplate>>> getTemplates({
    String? category,
    String? searchQuery,
  }) async {
    // Fast path: if cache is valid and query is simple, filter from cache immediately
    final isCacheValid = _cachedTemplates != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < const Duration(minutes: 10);

    if (isCacheValid && _cachedTemplates!.isNotEmpty) {
      final filtered = _filterTemplates(_cachedTemplates!, category: category, searchQuery: searchQuery);
      return Right(filtered);
    }

    try {
      final templates = await remoteDataSource.getTemplates(
        category: category,
        searchQuery: searchQuery,
      );

      if (templates.isNotEmpty) {
        if (category == null && (searchQuery == null || searchQuery.isEmpty)) {
          _cachedTemplates = templates;
          _lastCacheTime = DateTime.now();
        }
        return Right(templates);
      }

      final local = await localDataSource.getTemplates(
        category: category,
        searchQuery: searchQuery,
      );
      _cachedTemplates = local;
      _lastCacheTime = DateTime.now();
      return Right(local);
    } catch (e) {
      try {
        final local = await localDataSource.getTemplates(
          category: category,
          searchQuery: searchQuery,
        );
        _cachedTemplates = local;
        _lastCacheTime = DateTime.now();
        return Right(local);
      } catch (localErr) {
        return Left(ErrorHandler.handle(localErr));
      }
    }
  }

  List<DocumentTemplate> _filterTemplates(
    List<DocumentTemplate> list, {
    String? category,
    String? searchQuery,
  }) {
    return list.where((t) {
      final matchesCategory = category == null ||
          category == 'Barchasi' ||
          t.category.toLowerCase().contains(category.toLowerCase());

      final matchesQuery = searchQuery == null ||
          searchQuery.trim().isEmpty ||
          t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.legalBasisSummary.toLowerCase().contains(searchQuery.toLowerCase());

      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Future<Either<Failure, DocumentTemplate>> getTemplateById(String id) async {
    // Check in-memory cache first
    if (_cachedTemplates != null) {
      final found = _cachedTemplates!.where((t) => t.id == id).firstOrNull;
      if (found != null && found.templateText.isNotEmpty) {
        return Right(found);
      }
    }

    try {
      final template = await remoteDataSource.getTemplateById(id);
      return Right(template);
    } catch (e) {
      try {
        final local = await localDataSource.getTemplateById(id);
        return Right(local);
      } catch (localErr) {
        return Left(ErrorHandler.handle(localErr));
      }
    }
  }

  @override
  Future<Either<Failure, SavedUserDocument>> saveUserDocument(SavedUserDocument document) async {
    try {
      final saved = await remoteDataSource.saveUserDocument(document);
      return Right(saved);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<SavedUserDocument>>> getUserDocuments() async {
    try {
      final list = await remoteDataSource.getUserDocuments();
      return Right(list);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUserDocument(String documentId) async {
    try {
      await remoteDataSource.deleteUserDocument(documentId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
