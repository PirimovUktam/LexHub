// Guards the login/registration TLD limit found by local staging smoke.
// Observed 2026-09-20: valid long-TLD addresses were rejected before AuthBloc.
// These real-page widget tests prove form dispatch, not remote authentication.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import 'package:lexhub/features/auth/presentation/pages/login_page.dart';
import 'package:lexhub/features/auth/presentation/pages/register_page.dart';
import 'package:lexhub/features/auth/presentation/widgets/auth_gradient_button.dart';

import '../../../../support/l10n_test_app.dart';

// Used only in this recording fake; no account is created or authenticated.
const _syntheticInput = 'synthetic-widget-only';

class _RecordingAuthBloc extends Cubit<AuthState> implements AuthBloc {
  _RecordingAuthBloc() : super(const Unauthenticated());

  final events = <AuthEvent>[];

  @override
  void add(AuthEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _submitEmail(
  WidgetTester tester,
  _RecordingAuthBloc bloc, {
  required bool register,
  required String email,
}) async {
  await tester.pumpWidget(l10nTestApp(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: register ? const RegisterPage() : const LoginPage(),
    ),
  ));
  await tester.pumpAndSettle();

  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(register ? 4 : 2));
  if (register) {
    await tester.enterText(fields.at(0), 'Synthetic User');
  }
  await tester.enterText(fields.at(register ? 1 : 0), email);
  await tester.enterText(fields.at(register ? 2 : 1), _syntheticInput);
  if (register) {
    await tester.enterText(fields.at(3), _syntheticInput);
  }

  final submit = find.byType(AuthGradientButton);
  expect(submit, findsOneWidget);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  for (final register in [false, true]) {
    final pageName = register ? 'RegisterPage' : 'LoginPage';

    for (final suffix in ['uz', 'invalid', 'technology', 'a' * 63]) {
      testWidgets('$pageName accepts ${suffix.length}-character TLD',
          (tester) async {
        final bloc = _RecordingAuthBloc();
        addTearDown(bloc.close);
        final email = 'smoke@example.$suffix';

        await _submitEmail(tester, bloc, register: register, email: ' $email ');

        final expected = register
            ? SignUpWithEmailEvent(
                email: email,
                password: _syntheticInput,
                fullName: 'Synthetic User',
              )
            : SignInWithEmailEvent(email: email, password: _syntheticInput);
        expect(bloc.events, [expected]);
        expect(find.text("To'g'ri email formatini kiriting"), findsNothing);
      });
    }

    final invalidEmails = [
      '',
      'not-an-email',
      'smoke@example',
      'smoke@example.x',
      'smoke@@example.invalid',
      'smoke@example.${'a' * 64}',
    ];
    for (var index = 0; index < invalidEmails.length; index++) {
      testWidgets('$pageName rejects invalid email case $index',
          (tester) async {
        final bloc = _RecordingAuthBloc();
        addTearDown(bloc.close);
        final email = invalidEmails[index];

        await _submitEmail(tester, bloc, register: register, email: email);

        expect(bloc.events, isEmpty);
        expect(
          find.text(email.isEmpty
              ? 'Email manzilini kiriting'
              : "To'g'ri email formatini kiriting"),
          findsOneWidget,
        );
      });
    }
  }
}
