import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/document_builder/domain/usecases/get_document_templates_usecase.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_event.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_state.dart';

class DocumentBuilderBloc extends Bloc<DocumentBuilderEvent, DocumentBuilderState> {
  final GetDocumentTemplatesUseCase getDocumentTemplatesUseCase;
  final GetTemplateByIdUseCase getTemplateByIdUseCase;

  String? _currentCategory;

  DocumentBuilderBloc({
    required this.getDocumentTemplatesUseCase,
    required this.getTemplateByIdUseCase,
  }) : super(DocumentBuilderInitial()) {
    on<LoadTemplatesListEvent>(_onLoadTemplatesList);
    on<SearchTemplatesEvent>(_onSearchTemplates);
    on<SelectTemplateForGenerationEvent>(_onSelectTemplateForGeneration);
    on<UpdateFormFieldEvent>(_onUpdateFormField);
    on<GenerateFinalDocumentEvent>(_onGenerateFinalDocument);
    on<ResetDocumentBuilderEvent>(_onResetDocumentBuilder);
  }

  Future<void> _onLoadTemplatesList(
    LoadTemplatesListEvent event,
    Emitter<DocumentBuilderState> emit,
  ) async {
    _currentCategory = event.category;
    emit(DocumentTemplatesLoading());
    final result = await getDocumentTemplatesUseCase(event.category, searchQuery: event.searchQuery);
    result.fold(
      (failure) => emit(DocumentBuilderError(failure.message, code: failure.code)),
      (templates) => emit(DocumentTemplatesLoaded(
        templates: templates,
        selectedCategory: event.category,
      )),
    );
  }

  Future<void> _onSearchTemplates(
    SearchTemplatesEvent event,
    Emitter<DocumentBuilderState> emit,
  ) async {
    final result = await getDocumentTemplatesUseCase(_currentCategory, searchQuery: event.query);
    result.fold(
      (failure) => emit(DocumentBuilderError(failure.message, code: failure.code)),
      (templates) => emit(DocumentTemplatesLoaded(
        templates: templates,
        selectedCategory: _currentCategory,
      )),
    );
  }

  void _onSelectTemplateForGeneration(
    SelectTemplateForGenerationEvent event,
    Emitter<DocumentBuilderState> emit,
  ) {
    final values = <String, String>{};
    for (final field in event.template.fields) {
      if (event.initialValues != null && event.initialValues!.containsKey(field.id)) {
        values[field.id] = event.initialValues![field.id]!;
      } else if (field.initialValue != null) {
        values[field.id] = field.initialValue!;
      } else {
        values[field.id] = '';
      }
    }

    emit(DocumentFormEditing(
      template: event.template,
      formValues: values,
    ));
  }

  void _onUpdateFormField(
    UpdateFormFieldEvent event,
    Emitter<DocumentBuilderState> emit,
  ) {
    if (state is DocumentFormEditing) {
      final current = state as DocumentFormEditing;
      final newValues = Map<String, String>.from(current.formValues);
      newValues[event.fieldId] = event.value;

      final newErrors = Map<String, String>.from(current.validationErrors);
      if (event.value.trim().isNotEmpty) {
        newErrors.remove(event.fieldId);
      }

      emit(current.copyWith(
        formValues: newValues,
        validationErrors: newErrors,
      ));
    }
  }

  void _onGenerateFinalDocument(
    GenerateFinalDocumentEvent event,
    Emitter<DocumentBuilderState> emit,
  ) {
    if (state is DocumentFormEditing) {
      final current = state as DocumentFormEditing;
      final errors = <String, String>{};

      // Validate required fields
      for (final field in current.template.fields) {
        if (field.isRequired) {
          final val = current.formValues[field.id]?.trim() ?? '';
          if (val.isEmpty) {
            errors[field.id] = "${field.label} to'ldirilishi shart";
          }
        }
      }

      if (errors.isNotEmpty) {
        emit(current.copyWith(validationErrors: errors));
        return;
      }

      final generatedText = current.template.buildDocument(current.formValues);

      emit(DocumentGeneratedSuccess(
        template: current.template,
        generatedText: generatedText,
        formValues: current.formValues,
      ));
    }
  }

  void _onResetDocumentBuilder(
    ResetDocumentBuilderEvent event,
    Emitter<DocumentBuilderState> emit,
  ) {
    emit(DocumentBuilderInitial());
  }
}
