import 'dart:convert';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';

class SavedUserDocumentModel extends SavedUserDocument {
  const SavedUserDocumentModel({
    required super.id,
    required super.userId,
    super.templateId,
    required super.title,
    required super.category,
    required super.formValues,
    required super.generatedText,
    super.legalBasis,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SavedUserDocumentModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> values = {};
    final rawValues = json['form_values'] ?? json['formValues'];
    if (rawValues is Map) {
      values = rawValues.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } else if (rawValues is String) {
      try {
        final decoded = jsonDecode(rawValues);
        if (decoded is Map) {
          values = decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
      } catch (_) {}
    }

    return SavedUserDocumentModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      templateId: json['template_id'] as String? ?? json['templateId'] as String?,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Umumiy',
      formValues: values,
      generatedText: json['generated_text'] as String? ?? json['generatedText'] as String? ?? '',
      legalBasis: json['legal_basis'] as String? ?? json['legalBasis'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (templateId != null) 'template_id': templateId,
      'title': title,
      'category': category,
      'form_values': formValues,
      'generated_text': generatedText,
      if (legalBasis != null) 'legal_basis': legalBasis,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
