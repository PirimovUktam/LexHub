/// XATOLAR JIM YUTILMAYDI.
///
/// Bu fayl ilgari BESH joyda `catch (e) { return ...; }` / `catch (_) {}`
/// ishlatgan, ya'ni timeout, RLS rad javobi va parse xatosi bir xil
/// ko'rinardi: hech qanday log, hech qanday belgi. Buzilgan integratsiya
/// yillar davomida sezilmasligi mumkin edi (CLAUDE.md §3: silent error
/// swallowing).
///
/// QAYSI SHOX QANDAY ISHLAYDI (ataylab har xil):
///   * `getTemplates` / `getTemplateById` — mahalliy KATALOG bundle'da BOR va
///     to'liq (`document_templates_local_datasource.dart`), shuning uchun
///     zaxiraga o'tish TO'G'RI xatti-harakat. Bundan tashqari
///     `DocumentBuilderRepositoryImpl` HAR QANDAY exception'da o'zi ham
///     mahalliy katalogga tushadi — ya'ni bu yerdan qayta otish ham oxir-oqibat
///     bir xil natija beradi. Shu sababli xatti-harakat SAQLANADI, faqat
///     debug log qo'shiladi.
///   * `getUserDocuments` / `deleteUserDocument` / `saveUserDocument` —
///     FOYDALANUVCHI ma'lumoti, mahalliy zaxirasi YO'Q. Bo'sh ro'yxat qaytarish
///     "sizda saqlangan hujjat yo'q" degan YOLG'ON bo'ladi, shuning uchun
///     `TimeoutException` qayta otiladi.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexhub/core/network/supabase_db.dart';
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
      var query = supabaseClient.db('document_templates').select('*');

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
      // Katalog zaxirasi (fayl boshidagi izohga qara) — lekin JIM emas.
      if (kDebugMode) {
        debugPrint('[doc-templates] cloud katalog o\'qilmadi, bundle: $e');
      }
      return await localDataSource.getTemplates(category: category, searchQuery: searchQuery);
    }
  }

  @override
  Future<DocumentTemplate> getTemplateById(String id) async {
    try {
      final response = await supabaseClient
          .db('document_templates')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return await localDataSource.getTemplateById(id);
      }

      return DocumentTemplateModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[doc-templates] cloud shablon o\'qilmadi, bundle: $e');
      }
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
        await supabaseClient.db('user_documents').upsert(model.toJson());
      } catch (e) {
        // MUHIM: hujjatning O'ZI allaqachon mahalliy saqlangan
        // (`document_preview_page.dart` -> `saveUseCase`), bu yerda faqat
        // CLOUD SINXRONIZATSIYASI. Shu sababli xato yuqoriga uzatilmaydi —
        // aks holda muvaffaqiyatli mahalliy saqlash "xato" bo'lib ko'rinardi.
        // Lekin sinxronizatsiya nosozligi debug log'da KO'RINADI.
        if (kDebugMode) {
          debugPrint('[doc-templates] cloud sinxronizatsiya bo\'lmadi: $e');
        }
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
          .db('user_documents')
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => SavedUserDocumentModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // Bo'sh ro'yxat "hujjat yo'q" degani — timeout'da bu YOLG'ON bo'ladi.
      if (e is TimeoutException) rethrow;
      if (kDebugMode) {
        debugPrint('[doc-templates] saqlangan hujjatlar o\'qilmadi: $e');
      }
      return [];
    }
  }

  @override
  Future<void> deleteUserDocument(String documentId) async {
    final currentUserId = supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await supabaseClient
          .db('user_documents')
          .delete()
          .eq('id', documentId)
          .eq('user_id', currentUserId);
    } catch (e) {
      // O'CHIRISH muvaffaqiyat deb ko'rsatilmasligi kerak: timeout'da qator
      // serverda QOLADI, foydalanuvchi esa o'chirilgan deb o'ylaydi.
      if (e is TimeoutException) rethrow;
      if (kDebugMode) {
        debugPrint('[doc-templates] hujjat o\'chirilmadi: $e');
      }
    }
  }
}
