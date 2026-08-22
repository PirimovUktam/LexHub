import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_remote_datasource.dart';
import 'package:lexhub/features/document_builder/data/repositories/document_builder_repository_impl.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';

class FakeDocumentTemplatesRemoteDataSource implements DocumentTemplatesRemoteDataSource {
  final bool shouldFail;
  FakeDocumentTemplatesRemoteDataSource({this.shouldFail = false});

  @override
  Future<List<DocumentTemplate>> getTemplates({String? category, String? searchQuery}) async {
    if (shouldFail) throw Exception('Network error');
    return [];
  }

  @override
  Future<DocumentTemplate> getTemplateById(String id) async {
    if (shouldFail) throw Exception('Network error');
    throw UnimplementedError();
  }

  @override
  Future<SavedUserDocument> saveUserDocument(SavedUserDocument document) async {
    if (shouldFail) throw Exception('Network error');
    return document;
  }

  @override
  Future<List<SavedUserDocument>> getUserDocuments() async {
    if (shouldFail) throw Exception('Network error');
    return [];
  }

  @override
  Future<void> deleteUserDocument(String documentId) async {
    if (shouldFail) throw Exception('Network error');
  }
}

void main() {
  group('DocumentBuilderRepositoryImpl Tests', () {
    late DocumentTemplatesLocalDataSource localDataSource;

    setUp(() {
      localDataSource = DocumentTemplatesLocalDataSourceImpl();
    });

    test('1. Returns local templates if remote returns empty list (offline-first)', () async {
      final remoteDataSource = FakeDocumentTemplatesRemoteDataSource(shouldFail: false);
      final repository = DocumentBuilderRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );

      final result = await repository.getTemplates();
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should have returned templates'),
        (templates) {
          expect(templates.isNotEmpty, true);
        },
      );
    });

    test('2. Falls back to local datasource if remote throws network exception', () async {
      final remoteDataSource = FakeDocumentTemplatesRemoteDataSource(shouldFail: true);
      final repository = DocumentBuilderRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );

      final result = await repository.getTemplates(category: "Mehnat huquqi");
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should have fallen back to local'),
        (templates) {
          expect(templates.isNotEmpty, true);
          expect(templates.first.category, "Mehnat huquqi");
        },
      );
    });
  });
}
