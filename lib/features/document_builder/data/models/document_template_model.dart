import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/features/document_builder/data/models/document_form_field_model.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';

class DocumentTemplateModel extends DocumentTemplate {
  const DocumentTemplateModel({
    required super.id,
    required super.title,
    required super.category,
    required super.legalBasisSummary,
    required super.description,
    required super.icon,
    required super.color,
    required super.fields,
    required super.templateText,
    super.targetAuthority,
    super.sourceUrl,
    super.lastVerifiedAt,
    super.status = 'active',
    super.isPopular = false,
  });

  factory DocumentTemplateModel.fromJson(Map<String, dynamic> json) {
    // 1. Resolve Fields
    List<DocumentFormField> parsedFields = [];
    final rawFields = json['required_fields'] ?? json['fields'];
    if (rawFields is List) {
      parsedFields = rawFields.map((f) {
        if (f is Map<String, dynamic>) {
          return DocumentFormFieldModel.fromJson(f);
        } else if (f is String) {
          try {
            return DocumentFormFieldModel.fromJson(jsonDecode(f) as Map<String, dynamic>);
          } catch (_) {
            return DocumentFormField(id: f, label: f, placeholder: f);
          }
        }
        return DocumentFormField(id: f.toString(), label: f.toString(), placeholder: f.toString());
      }).toList();
    } else if (rawFields is String) {
      try {
        final decoded = jsonDecode(rawFields);
        if (decoded is List) {
          parsedFields = decoded
              .map((f) => DocumentFormFieldModel.fromJson(f as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    final category = json['category'] as String? ?? "Umumiy";

    // Icon & Color mapping
    IconData icon = Icons.description_outlined;
    Color color = AppColors.primary;

    if (category.toLowerCase().contains("iste'molchi")) {
      icon = Icons.shopping_bag_outlined;
      color = AppColors.emerald;
    } else if (category.toLowerCase().contains("mehnat")) {
      icon = Icons.work_outline_rounded;
      color = AppColors.primary;
    } else if (category.toLowerCase().contains("oila")) {
      icon = Icons.family_restroom_rounded;
      color = AppColors.indigo;
    } else if (category.toLowerCase().contains("yo'l") || category.toLowerCase().contains("jarima")) {
      icon = Icons.directions_car_outlined;
      color = AppColors.amber;
    } else if (category.toLowerCase().contains("meros") || category.toLowerCase().contains("mulk")) {
      icon = Icons.home_work_outlined;
      color = AppColors.lexBlue;
    }

    DateTime? verifiedAt;
    if (json['last_verified_at'] != null) {
      verifiedAt = DateTime.tryParse(json['last_verified_at'].toString());
    }

    return DocumentTemplateModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: category,
      legalBasisSummary: json['legal_basis'] as String? ??
          json['legalBasisSummary'] as String? ??
          "O'zbekiston Respublikasi Qonunchiligi",
      description: json['description'] as String? ?? '',
      icon: icon,
      color: color,
      fields: parsedFields,
      templateText: json['body_template'] as String? ?? json['templateText'] as String? ?? '',
      targetAuthority: json['target_authority'] as String?,
      sourceUrl: json['source_url'] as String?,
      lastVerifiedAt: verifiedAt,
      status: json['status'] as String? ?? 'active',
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'target_authority': targetAuthority ?? '',
      'legal_basis': legalBasisSummary,
      'source_url': sourceUrl,
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
      'status': status,
      'is_popular': isPopular,
      'required_fields': fields.map((f) {
        if (f is DocumentFormFieldModel) return f.toJson();
        return DocumentFormFieldModel(
          id: f.id,
          label: f.label,
          placeholder: f.placeholder,
          isRequired: f.isRequired,
          fieldType: f.fieldType,
          initialValue: f.initialValue,
        ).toJson();
      }).toList(),
      'body_template': templateText,
    };
  }
}
