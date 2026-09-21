// Guards catalog badges, document labels and small-window overflow (2026-09-21).
// Real presentation widgets with synthetic BLoC states; not DB/AI evidence.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_bloc.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_event.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_state.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/citizen_services_page.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_bloc.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_event.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_state.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_generator_page.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_templates_page.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_preview_page.dart';
import '../support/l10n_test_app.dart';

const _template = DocumentTemplate(
  id: 'synthetic',
  title: 'Synthetic template with a long title',
  category: "Iste'molchi huquqlari",
  legalBasisSummary: 'Synthetic source label',
  description: 'Synthetic description for responsive verification only.',
  icon: Icons.description_outlined,
  color: Colors.indigo,
  fields: [
    DocumentFormField(
        id: 'name',
        label: 'Synthetic form label long enough to wrap on a small screen',
        placeholder: 'Synthetic input')
  ],
  templateText: 'Synthetic draft {{name}}',
  isPopular: true,
);

class _Services extends Cubit<CitizenServicesState>
    implements CitizenServicesBloc {
  _Services()
      : super(const CitizenServicesLoaded(services: [
          CitizenService(
            id: 'synthetic',
            title: 'Synthetic service for layout verification',
            category: "Iste'molchi huquqi",
            department: 'Synthetic department',
            description:
                'Synthetic description for responsive verification only.',
            isPopular: true,
          )
        ]));
  @override
  void add(CitizenServicesEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Documents extends Cubit<DocumentBuilderState>
    implements DocumentBuilderBloc {
  _Documents(super.state);
  final events = <DocumentBuilderEvent>[];
  @override
  void add(DocumentBuilderEvent event) => events.add(event);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final size in const [
    Size(320, 568),
    Size(360, 800),
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(820, 1180),
    Size(1024, 768),
    Size(1280, 720),
    Size(1440, 900),
    Size(1920, 1080)
  ]) {
    for (final scale in [
      1.0,
      if (size.width == 320 || size.width == 768) 2.0
    ]) {
      testWidgets('catalog and document surfaces $size scale=$scale',
          (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        sl.registerFactory<CitizenServicesBloc>(() => _Services());
        DocumentBuilderState state =
            const DocumentTemplatesLoaded(templates: [_template]);
        sl.registerFactory<DocumentBuilderBloc>(() => _Documents(state));
        addTearDown(() async {
          await sl.unregister<CitizenServicesBloc>();
          await sl.unregister<DocumentBuilderBloc>();
        });
        Future<void> pump(Widget page) async {
          await t.pumpWidget(l10nTestApp(
              MediaQuery(
                  data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true),
                  child: page),
              locale: const Locale('en'),
              theme: AppTheme.lightTheme));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }

        await pump(const CitizenServicesPage());
        expect(find.text('Synthetic service for layout verification'),
            findsOneWidget);
        await pump(const DocumentTemplatesPage());
        expect(find.text(_template.title), findsOneWidget);
        state = const DocumentFormEditing(template: _template, formValues: {});
        await pump(const DocumentGeneratorPage(template: _template));
        expect(find.byType(TextFormField), findsOneWidget);
        await t.enterText(find.byType(TextFormField), 'Synthetic user');
        final context = t.element(find.byType(TextFormField));
        final bloc = context.read<DocumentBuilderBloc>() as _Documents;
        expect(bloc.events.whereType<UpdateFormFieldEvent>().last.value,
            'Synthetic user');
        await pump(const DocumentPreviewPage(
            template: _template,
            generatedText: 'Synthetic draft for layout verification.',
            formValues: {}));
        expect(find.byType(SelectableText), findsOneWidget);
      });
    }
  }
}
