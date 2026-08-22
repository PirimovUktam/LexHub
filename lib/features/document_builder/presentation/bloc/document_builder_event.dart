import 'package:equatable/equatable.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';

abstract class DocumentBuilderEvent extends Equatable {
  const DocumentBuilderEvent();

  @override
  List<Object?> get props => [];
}

class LoadTemplatesListEvent extends DocumentBuilderEvent {
  final String? category;
  final String? searchQuery;

  const LoadTemplatesListEvent({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class SearchTemplatesEvent extends DocumentBuilderEvent {
  final String query;

  const SearchTemplatesEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectTemplateForGenerationEvent extends DocumentBuilderEvent {
  final DocumentTemplate template;
  final Map<String, String>? initialValues;

  const SelectTemplateForGenerationEvent({
    required this.template,
    this.initialValues,
  });

  @override
  List<Object?> get props => [template, initialValues];
}

class UpdateFormFieldEvent extends DocumentBuilderEvent {
  final String fieldId;
  final String value;

  const UpdateFormFieldEvent({
    required this.fieldId,
    required this.value,
  });

  @override
  List<Object?> get props => [fieldId, value];
}

class GenerateFinalDocumentEvent extends DocumentBuilderEvent {
  const GenerateFinalDocumentEvent();
}

class ResetDocumentBuilderEvent extends DocumentBuilderEvent {
  const ResetDocumentBuilderEvent();
}
