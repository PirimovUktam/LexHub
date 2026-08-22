import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';
import 'package:lexhub/features/document_builder/domain/repositories/document_builder_repository.dart';
import 'package:lexhub/features/document_builder/domain/usecases/get_document_templates_usecase.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_bloc.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_event.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_state.dart';

class MockDocumentBuilderRepository implements DocumentBuilderRepository {
  final DocumentTemplate mockTemplate = const DocumentTemplate(
    id: 'test_template',
    title: 'Sinov Talabnomasi',
    category: 'Iste\'molchi',
    legalBasisSummary: '13-modda',
    description: 'Tavsif',
    icon: Icons.description,
    color: Colors.green,
    fields: [
      DocumentFormField(id: 'name', label: 'F.I.Sh', placeholder: 'Ism'),
      DocumentFormField(id: 'price', label: 'Narx', placeholder: '0'),
    ],
    templateText: "KIMDAN: {{name}}\nNARX: {{price}}",
  );

  @override
  Future<Either<Failure, List<DocumentTemplate>>> getTemplates({String? category, String? searchQuery}) async {
    return Right([mockTemplate]);
  }

  @override
  Future<Either<Failure, DocumentTemplate>> getTemplateById(String id) async {
    return Right(mockTemplate);
  }

  @override
  Future<Either<Failure, SavedUserDocument>> saveUserDocument(SavedUserDocument document) async {
    return Right(document);
  }

  @override
  Future<Either<Failure, List<SavedUserDocument>>> getUserDocuments() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, void>> deleteUserDocument(String documentId) async {
    return const Right(null);
  }
}

void main() {
  late MockDocumentBuilderRepository mockRepo;
  late GetDocumentTemplatesUseCase getDocumentTemplatesUseCase;
  late GetTemplateByIdUseCase getTemplateByIdUseCase;
  late DocumentBuilderBloc bloc;

  setUp(() {
    mockRepo = MockDocumentBuilderRepository();
    getDocumentTemplatesUseCase = GetDocumentTemplatesUseCase(mockRepo);
    getTemplateByIdUseCase = GetTemplateByIdUseCase(mockRepo);

    bloc = DocumentBuilderBloc(
      getDocumentTemplatesUseCase: getDocumentTemplatesUseCase,
      getTemplateByIdUseCase: getTemplateByIdUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state is DocumentBuilderInitial', () {
    expect(bloc.state, isA<DocumentBuilderInitial>());
  });

  test('emits [DocumentTemplatesLoading, DocumentTemplatesLoaded] when LoadTemplatesListEvent added', () async {
    bloc.add(const LoadTemplatesListEvent());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<DocumentTemplatesLoading>(),
        isA<DocumentTemplatesLoaded>().having(
          (s) => s.templates.length,
          'templates length',
          1,
        ),
      ]),
    );
  });

  test('emits DocumentFormEditing when SelectTemplateForGenerationEvent added', () async {
    bloc.add(SelectTemplateForGenerationEvent(
      template: mockRepo.mockTemplate,
    ));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<DocumentFormEditing>().having(
          (s) => s.formValues['name'],
          'initial empty name',
          '',
        ),
      ]),
    );
  });

  test('emits DocumentGeneratedSuccess when form is valid and GenerateFinalDocumentEvent is added', () async {
    bloc.add(SelectTemplateForGenerationEvent(
      template: mockRepo.mockTemplate,
    ));
    await pumpEventQueue();

    bloc.add(const UpdateFormFieldEvent(fieldId: 'name', value: 'Alisher'));
    bloc.add(const UpdateFormFieldEvent(fieldId: 'price', value: '100000'));
    await pumpEventQueue();

    bloc.add(const GenerateFinalDocumentEvent());

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<DocumentGeneratedSuccess>().having(
          (s) => s.generatedText,
          'generated text',
          contains('Alisher'),
        ),
      ),
    );
  });
}
