// Guards responsive form overflow, lost actions and width/keyboard regressions.
// Authored 2026-09-21. Synthetic widget data is not live Auth/AI evidence.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/adaptive_card_list.dart';
import 'package:lexhub/core/theme/app_page_body.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import 'package:lexhub/features/auth/presentation/pages/login_page.dart';
import 'package:lexhub/features/auth/presentation/pages/register_page.dart';
import 'package:lexhub/features/auth/presentation/widgets/auth_gradient_button.dart';
import 'package:lexhub/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/action_steps_timeline.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/main_navigation/presentation/widgets/lex_bottom_nav.dart';

import '../support/l10n_test_app.dart';

const _viewports = [
  Size(320, 568),
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
  Size(820, 1180),
  Size(1024, 768),
  Size(1280, 720),
  Size(1440, 900),
  Size(1920, 1080),
];

class _AuthRecorder extends Cubit<AuthState> implements AuthBloc {
  _AuthRecorder() : super(const Unauthenticated());
  final events = <AuthEvent>[];
  @override
  void add(AuthEvent event) => events.add(event);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget child, Size size,
      {bool dark = false, double scale = 1, double keyboard = 0}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(l10nTestApp(
      MediaQuery(
        data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true),
        child: child,
      ),
      locale: const Locale('en'),
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    ));
    await tester.pumpAndSettle();
  }

  for (final size in _viewports) {
    for (final dark in [false, true]) {
      testWidgets('auth forms $size dark=$dark', (t) async {
        final auth = _AuthRecorder();
        addTearDown(auth.close);
        for (final register in [false, true]) {
          await pump(
              t,
              BlocProvider<AuthBloc>.value(
                  value: auth,
                  child: register ? const RegisterPage() : const LoginPage()),
              size,
              dark: dark);
          final fields = find.byType(TextFormField);
          expect(fields, findsNWidgets(register ? 4 : 2));
          expect(t.getSize(fields.first).width, lessThanOrEqualTo(480));
          final submit = find.byType(AuthGradientButton);
          await t.ensureVisible(submit);
          await t.tap(submit);
          await t.pumpAndSettle();
          expect(auth.events, isEmpty,
              reason: 'Empty form must not reach Auth');
          expect(find.text('Please enter your email address'), findsOneWidget);
          expect(t.takeException(), isNull);
        }
      });

      testWidgets('result and source readability $size dark=$dark', (t) async {
        await pump(
            t,
            Scaffold(
                body: AppPageBody(
                    child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                RelatableSummaryCard(
                  summary:
                      List.filled(16, 'Synthetic long summary for layout only.')
                          .join(' '),
                  source: LegalResponse.sourceDeterministic,
                ),
                const ActionStepsTimeline(
                    steps: ['Synthetic first step', 'Synthetic second step']),
                const LegalBasisAccordion(articles: [
                  LawArticle(
                    lawName: 'Synthetic source with a long descriptive name',
                    articleNumber: 'S-1',
                    articleTitle: 'Synthetic source title',
                    articleText:
                        'Synthetic reference text. This is not legal content.',
                    lexUrl: '',
                  )
                ]),
              ]),
            ))),
            size,
            dark: dark);
        final source =
            find.text('Synthetic source with a long descriptive name');
        expect(
            find.text('Synthetic reference text. This is not legal content.'),
            findsOneWidget);
        await t.ensureVisible(source);
        await t.tap(source);
        await t.pumpAndSettle();
        expect(
            find.text('Synthetic reference text. This is not legal content.'),
            findsNothing);
        await t.tap(source);
        await t.pumpAndSettle();
        expect(
            find.text('Synthetic reference text. This is not legal content.'),
            findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing,
            reason: 'Deterministic result must not gain a model badge');
        expect(t.takeException(), isNull);
      });
    }
  }

  for (final register in [false, true]) {
    testWidgets('2x text and keyboard preserve auth submit register=$register',
        (t) async {
      final auth = _AuthRecorder();
      addTearDown(auth.close);
      await pump(
          t,
          BlocProvider<AuthBloc>.value(
              value: auth,
              child: register ? const RegisterPage() : const LoginPage()),
          const Size(320, 568),
          scale: 2,
          keyboard: 230);
      final submit = find.byType(AuthGradientButton);
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();
      await t.ensureVisible(submit);
      await t.pumpAndSettle();
      expect(t.getRect(submit).bottom, lessThanOrEqualTo(338));
      expect(auth.events, isEmpty);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('catalog uses two content-sized columns, single column at 2x',
      (t) async {
    Widget catalog() => Scaffold(
            body: AdaptiveCardList(
          itemCount: 3,
          itemBuilder: (_, index) => ModernContainer(
            child: Text('Synthetic catalog item $index ' * 8,
                key: ValueKey(index)),
          ),
        ));
    await pump(t, catalog(), const Size(1024, 768));
    expect(t.getTopLeft(find.byKey(const ValueKey(0))).dy,
        t.getTopLeft(find.byKey(const ValueKey(1))).dy);
    expect(t.getTopLeft(find.byKey(const ValueKey(1))).dx,
        greaterThan(t.getTopLeft(find.byKey(const ValueKey(0))).dx));
    await pump(t, catalog(), const Size(1024, 768), scale: 2);
    expect(t.getTopLeft(find.byKey(const ValueKey(1))).dy,
        greaterThan(t.getTopLeft(find.byKey(const ValueKey(0))).dy));
    expect(t.takeException(), isNull);
  });

  testWidgets('side navigation sends every original stack index', (t) async {
    final selected = <int>[];
    await pump(
        t,
        Scaffold(
            body: LexSideNav(
                currentIndex: 1, onSelect: selected.add, extended: true)),
        const Size(1280, 720));
    final targets = find.byType(InkWell);
    expect(targets, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      await t.tap(targets.at(i));
    }
    expect(selected, [0, 1, 2, 3, 4]);
  });

  testWidgets('auth input resolves real theme border and hint in both modes',
      (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    for (final dark in [false, true]) {
      await pump(
          t,
          Scaffold(
              body: AuthTextField(
                  controller: controller,
                  label: 'Synthetic label',
                  hintText: 'Synthetic hint',
                  prefixIcon: Icons.person)),
          const Size(390, 844),
          dark: dark);
      final decoration =
          t.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
      expect(decoration.enabledBorder?.borderSide.color,
          dark ? AppColors.borderStrongDark : AppColors.borderStrongLight);
      expect(decoration.hintStyle?.color,
          dark ? AppColors.textMutedDark : AppColors.textMutedLight);
    }
  });

  testWidgets('reduced motion leaves localized loading readable and stops loop',
      (t) async {
    await pump(
        t,
        const Scaffold(
            body: SingleChildScrollView(child: LegalAnalysisShimmer())),
        const Size(320, 568));
    expect(find.text('Looking up articles in the legal database...'),
        findsOneWidget);
    await t.pump(const Duration(seconds: 20));
    expect(find.text('Looking up articles in the legal database...'),
        findsOneWidget);
    expect(t.binding.transientCallbackCount, 0);
  });
}
