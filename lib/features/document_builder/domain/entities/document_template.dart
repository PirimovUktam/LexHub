import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';

/// Official Legal Document Template for Document Builder
class DocumentTemplate extends Equatable {
  final String id;
  final String title;
  final String category;
  final String legalBasisSummary;
  final String description;
  final IconData icon;
  final Color color;
  final List<DocumentFormField> fields;
  final String templateText;
  final String? targetAuthority;
  final String? sourceUrl;
  final DateTime? lastVerifiedAt;
  final String status;
  final bool isPopular;

  const DocumentTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.legalBasisSummary,
    required this.description,
    required this.icon,
    required this.color,
    required this.fields,
    required this.templateText,
    this.targetAuthority,
    this.sourceUrl,
    this.lastVerifiedAt,
    this.status = 'active',
    this.isPopular = false,
  });

  /// Fills template text placeholders {{field_id}} with provided values map
  String buildDocument(Map<String, String> values) {
    String output = templateText;
    for (final field in fields) {
      final val = values[field.id]?.trim();
      final replacement = (val != null && val.isNotEmpty)
          ? val
          : "[${field.label.toUpperCase()}]";
      output = output.replaceAll("{{${field.id}}}", replacement);
    }
    return output;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        legalBasisSummary,
        description,
        icon,
        color,
        fields,
        templateText,
        targetAuthority,
        sourceUrl,
        lastVerifiedAt,
        status,
        isPopular,
      ];
}
