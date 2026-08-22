import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';

class DocumentFormFieldModel extends DocumentFormField {
  const DocumentFormFieldModel({
    required super.id,
    required super.label,
    required super.placeholder,
    super.isRequired = true,
    super.fieldType = DocumentFieldType.text,
    super.initialValue,
  });

  factory DocumentFormFieldModel.fromJson(Map<String, dynamic> json) {
    DocumentFieldType type = DocumentFieldType.text;
    final rawType = json['field_type'] as String? ?? json['fieldType'] as String?;
    if (rawType == 'date') type = DocumentFieldType.date;
    if (rawType == 'number') type = DocumentFieldType.number;
    if (rawType == 'multiline') type = DocumentFieldType.multiline;

    return DocumentFormFieldModel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      isRequired: json['is_required'] as bool? ?? json['isRequired'] as bool? ?? true,
      fieldType: type,
      initialValue: json['initial_value'] as String? ?? json['initialValue'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String typeStr = 'text';
    if (fieldType == DocumentFieldType.date) typeStr = 'date';
    if (fieldType == DocumentFieldType.number) typeStr = 'number';
    if (fieldType == DocumentFieldType.multiline) typeStr = 'multiline';

    return {
      'id': id,
      'label': label,
      'placeholder': placeholder,
      'is_required': isRequired,
      'field_type': typeStr,
      if (initialValue != null) 'initial_value': initialValue,
    };
  }
}
