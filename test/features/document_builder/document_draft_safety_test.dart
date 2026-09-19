// 2026-09-19: generated drafts must not appear as law sources or risk verdicts.
// Real widget/model checks; no Supabase writes or legal-compliance guarantee.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/storage/local_case_scope.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';
import 'package:lexhub/features/document_builder/domain/repositories/document_builder_repository.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_preview_page.dart';
import 'package:lexhub/features/document_builder/presentation/widgets/document_draft_content.dart';
import 'package:lexhub/features/home/presentation/widgets/recent_cases_feed.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/features/legal_assistant/domain/repositories/legal_assistant_repository.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/risk_matrix_gauge.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

class RecordingCases implements LegalAssistantRepository {
  LegalResponse? saved;
  @override
  Future<Either<Failure, void>> saveCase(LegalResponse response) async {
    saved = response;
    return const Right(null);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingDocuments implements DocumentBuilderRepository {
  @override
  Future<Either<Failure, SavedUserDocument>> saveUserDocument(SavedUserDocument document) async => Right(document);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final draft = LegalResponse(
    id: 'draft',
    queryId: 'template',
    relatableSummary: 'My draft',
    source: LegalResponse.sourceDocument,
    documentText: 'User authored draft text',
    storageScope: 'account:test',
    riskAssessment:
        const RiskAssessment(level: RiskLevel.low, summary: 'unused'),
    createdAt: DateTime.utc(2026),
  );

  test('document type, text and owner survive serialization and copying', () {
    final decoded =
        LegalResponse.fromJson(draft.toJson()).copyWith(isSaved: true);
    expect(decoded.isDocumentDraft, isTrue);
    expect(decoded.isAiGenerated, isFalse);
    expect(decoded.documentText, draft.documentText);
    expect(decoded.storageScope, draft.storageScope);
    expect(decoded.legalBasis, isEmpty);
  });

  testWidgets('preview Save stores generated text as a draft, not a law article', (tester) async {
    await sl.reset();
    final cases = RecordingCases();
    final scope = LocalCaseScope(userId: 'account-a');
    sl.registerSingleton<LocalCaseScope>(scope);
    sl.registerSingleton<SaveCaseUseCase>(SaveCaseUseCase(cases));
    sl.registerSingleton<DocumentBuilderRepository>(RecordingDocuments());
    addTearDown(() async { scope.dispose(); await sl.reset(); });
    const template = DocumentTemplate(
      id: 'template', title: 'Draft title', category: 'test',
      legalBasisSummary: '', description: '', icon: Icons.description,
      color: Colors.blue, fields: [], templateText: 'Draft body',
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const DocumentPreviewPage(template: template,
        generatedText: 'Private user content', formValues: {}),
    ));
    await tester.pumpAndSettle();
    final save = find.byTooltip('Add to saved items');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final saved = cases.saved;
    expect(saved, isNotNull);
    expect(saved?.source, LegalResponse.sourceDocument);
    expect(saved?.documentText, 'Private user content');
    expect(saved?.legalBasis, isEmpty);
    expect(saved?.actionableSteps, isEmpty);
    expect(saved?.storageScope, scope.value);
    expect(saved?.relatableSummary, 'Draft title');
    expect(tester.takeException(), isNull);
  });

  for (final language in ['uz', 'en']) {
    testWidgets(
        'saved draft displays text and no law/risk/AI section ($language)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: RecentCaseDetailPage(response: draft),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentDraftContent), findsOneWidget);
      expect(find.text('User authored draft text'), findsOneWidget);
      expect(find.byType(LegalBasisAccordion), findsNothing);
      expect(find.byType(RiskMatrixGauge), findsNothing);
      expect(find.byType(RelatableSummaryCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
