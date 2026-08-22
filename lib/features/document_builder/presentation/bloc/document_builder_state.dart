import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';

abstract class DocumentBuilderState extends Equatable {
  const DocumentBuilderState();

  @override
  List<Object?> get props => [];
}

class DocumentBuilderInitial extends DocumentBuilderState {}

class DocumentTemplatesLoading extends DocumentBuilderState {}

class DocumentTemplatesLoaded extends DocumentBuilderState {
  final List<DocumentTemplate> templates;
  final String? selectedCategory;

  const DocumentTemplatesLoaded({
    required this.templates,
    this.selectedCategory,
  });

  @override
  List<Object?> get props => [templates, selectedCategory];
}

class DocumentFormEditing extends DocumentBuilderState {
  final DocumentTemplate template;
  final Map<String, String> formValues;
  final Map<String, String> validationErrors;

  const DocumentFormEditing({
    required this.template,
    required this.formValues,
    this.validationErrors = const {},
  });

  DocumentFormEditing copyWith({
    DocumentTemplate? template,
    Map<String, String>? formValues,
    Map<String, String>? validationErrors,
  }) {
    return DocumentFormEditing(
      template: template ?? this.template,
      formValues: formValues ?? this.formValues,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  @override
  List<Object?> get props => [template, formValues, validationErrors];
}

class DocumentGeneratedSuccess extends DocumentBuilderState {
  final DocumentTemplate template;
  final String generatedText;
  final Map<String, String> formValues;

  const DocumentGeneratedSuccess({
    required this.template,
    required this.generatedText,
    required this.formValues,
  });

  @override
  List<Object?> get props => [template, generatedText, formValues];
}

class DocumentBuilderError extends DocumentBuilderState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const DocumentBuilderError(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}
