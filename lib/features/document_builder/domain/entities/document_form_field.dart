import 'package:equatable/equatable.dart';

enum DocumentFieldType { text, date, number, multiline }

/// Form field definition for dynamic legal document generation
class DocumentFormField extends Equatable {
  final String id;
  final String label;
  final String placeholder;
  final bool isRequired;
  final DocumentFieldType fieldType;
  final String? initialValue;

  const DocumentFormField({
    required this.id,
    required this.label,
    required this.placeholder,
    this.isRequired = true,
    this.fieldType = DocumentFieldType.text,
    this.initialValue,
  });

  @override
  List<Object?> get props => [
        id,
        label,
        placeholder,
        isRequired,
        fieldType,
        initialValue,
      ];
}
