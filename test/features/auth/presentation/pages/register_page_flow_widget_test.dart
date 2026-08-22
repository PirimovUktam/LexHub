import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import 'package:lexhub/features/auth/presentation/pages/register_page.dart';
import 'package:lexhub/features/auth/presentation/widgets/auth_gradient_button.dart';

import '../../../../support/l10n_test_app.dart';

class FakeAuthBloc extends Cubit<AuthState> implements AuthBloc {
  final List<AuthEvent> addedEvents = [];

  FakeAuthBloc(super.initialState);

  @override
  void add(AuthEvent event) {
    addedEvents.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAuthBloc fakeAuthBloc;

  setUp(() {
    fakeAuthBloc = FakeAuthBloc(const Unauthenticated());
  });

  Widget createWidgetUnderTest(FakeAuthBloc bloc) {
    return l10nTestApp(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: const RegisterPage(),
      ),
    );
  }

  group('RegisterPage UI & Flow Forensic Tests', () {
    testWidgets('1. Form validation triggers when submitting empty inputs', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(fakeAuthBloc));
      await tester.pumpAndSettle();

      final submitButton = find.byType(AuthGradientButton);
      expect(submitButton, findsOneWidget);

      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ism-sharifingizni kiriting'), findsOneWidget);
      expect(find.text('Email manzilini kiriting'), findsOneWidget);
      expect(find.text('Parolni kiriting'), findsOneWidget);
      expect(find.text('Parolni tasdiqlang'), findsNWidgets(2));
    });

    testWidgets('2. Filling inputs and submitting dispatches SignUpWithEmailEvent without Null Check error', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(fakeAuthBloc));
      await tester.pumpAndSettle();

      // Enter Name
      await tester.enterText(find.byType(TextFormField).at(0), 'Jasur Karimov');
      // Enter Email
      await tester.enterText(find.byType(TextFormField).at(1), 'jasur@lexhub.uz');
      // Enter Password
      await tester.enterText(find.byType(TextFormField).at(2), 'Secret123!');
      // Enter Confirm Password
      await tester.enterText(find.byType(TextFormField).at(3), 'Secret123!');

      await tester.pumpAndSettle();

      final submitButton = find.byType(AuthGradientButton);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(fakeAuthBloc.addedEvents.length, equals(1));
      expect(fakeAuthBloc.addedEvents.first, isA<SignUpWithEmailEvent>());
      final event = fakeAuthBloc.addedEvents.first as SignUpWithEmailEvent;
      expect(event.fullName, equals('Jasur Karimov'));
      expect(event.email, equals('jasur@lexhub.uz'));
      expect(event.password, equals('Secret123!'));
    });

    testWidgets('3. AuthFailure state displays SnackBar safely without null crash', (tester) async {
      final bloc = FakeAuthBloc(const Unauthenticated());

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pumpAndSettle();

      // Emit AuthFailure to trigger BlocConsumer listener
      bloc.emit(const AuthFailure('Juda ko\'p urinish amalga oshirildi. Iltimos, bir necha daqiqadan so\'ng qayta urinib ko\'ring.'));
      await tester.pumpAndSettle();

      expect(find.text('Juda ko\'p urinish amalga oshirildi. Iltimos, bir necha daqiqadan so\'ng qayta urinib ko\'ring.'), findsOneWidget);
    });
  });
}
