import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/models/document_template_model.dart';
import 'package:lexhub/features/document_builder/data/models/saved_user_document_model.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DocumentTemplatesRemoteDataSource {
  Future<List<DocumentTemplate>> getTemplates({String? category, String? searchQuery});
  Future<DocumentTemplate> getTemplateById(String id);
  Future<SavedUserDocument> saveUserDocument(SavedUserDocument document);
  Future<List<SavedUserDocument>> getUserDocuments();
  Future<void> deleteUserDocument(String documentId);
}

class DocumentTemplatesRemoteDataSourceImpl implements DocumentTemplatesRemoteDataSource {
  final SupabaseClient supabaseClient;
  final DocumentTemplatesLocalDataSource localDataSource;

  DocumentTemplatesRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.localDataSource,
  });

  @override
  Future<List<DocumentTemplate>> getTemplates({String? category, String? searchQuery}) async {
    try {
      var query = supabaseClient.from('document_templates').select('*');

      if (category != null && category != 'Barchasi') {
        query = query.ilike('category', '%$category%');
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('title.ilike.%$q%,description.ilike.%$q%,legal_basis.ilike.%$q%');
      }

      final response = await query
          .order('is_popular', ascending: false)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return await localDataSource.getTemplates(category: category, searchQuery: searchQuery);
      }

      return data.map((json) => DocumentTemplateModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return await localDataSource.getTemplates(category: category, searchQuery: searchQuery);
    }
  }

  @override
  Future<DocumentTemplate> getTemplateById(String id) async {
    try {
      final response = await supabaseClient
          .from('document_templates')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return await localDataSource.getTemplateById(id);
      }

      return DocumentTemplateModel.fromJson(response);
    } catch (e) {
      return await localDataSource.getTemplateById(id);
    }
  }

  @override
  Future<SavedUserDocument> saveUserDocument(SavedUserDocument document) async {
    final currentUserId = supabaseClient.auth.currentUser?.id;
    final model = SavedUserDocumentModel(
      id: document.id,
      userId: currentUserId ?? document.userId,
      templateId: document.templateId,
      title: document.title,
      category: document.category,
      formValues: document.formValues,
      generatedText: document.generatedText,
      legalBasis: document.legalBasis,
      createdAt: document.createdAt,
      updatedAt: DateTime.now(),
    );

    if (currentUserId != null) {
      try {
        await supabaseClient.from('user_documents').upsert(model.toJson());
      } catch (_) {
        // Fallback to local
      }
    }

    return model;
  }

  @override
  Future<List<SavedUserDocument>> getUserDocuments() async {
    final currentUserId = supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final response = await supabaseClient
          .from('user_documents')
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => SavedUserDocumentModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deleteUserDocument(String documentId) async {
    final currentUserId = supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await supabaseClient
          .from('user_documents')
          .delete()
          .eq('id', documentId)
          .eq('user_id', currentUserId);
    } catch (_) {}
  }
}
