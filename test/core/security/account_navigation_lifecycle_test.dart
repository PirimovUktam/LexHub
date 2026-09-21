// 2026-09-21: account changes must discard private routes without detaching
// MaterialApp's focus tree. Real widgets; not remote Auth/RLS verification.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/storage/local_case_scope.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import 'package:lexhub/main.dart';
import '../../support/locale_test_cubit.dart';

class _InitialAuth extends Cubit<AuthState> implements AuthBloc {
  _InitialAuth() : super(const AuthInitial());
  @override
  void add(AuthEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'account and logout reset routes; locale preserves navigator and app focus root',
      (tester) async {
    final scope = LocalCaseScope(userId: 'synthetic-a');
    final locale = LocaleCubit(store: FakeLocaleStore());
    sl.registerSingleton<LocalCaseScope>(scope);
    sl.registerSingleton<LocaleCubit>(locale);
    sl.registerFactory<AuthBloc>(_InitialAuth.new);
    addTearDown(() async {
      await sl.reset();
      await locale.close();
      scope.dispose();
    });
    await tester.pumpWidget(const LexHubApp());
    await tester.pump(const Duration(milliseconds: 500));
    final appState = tester.state(find.byType(MaterialApp));
    final first = tester.state<NavigatorState>(find.byType(Navigator));
    first.push(MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Text('Synthetic private route A'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Synthetic private route A'), findsOneWidget);

    scope.updateUser('synthetic-b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Synthetic private route A'), findsNothing);
    expect(first.mounted, isFalse);
    expect(identical(tester.state(find.byType(MaterialApp)), appState), isTrue);
    final second = tester.state<NavigatorState>(find.byType(Navigator));
    second.push(MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Text('Synthetic private route B'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await locale.select(const Locale('en'));
    await tester.pump();
    expect(
        identical(tester.state<NavigatorState>(find.byType(Navigator)), second),
        isTrue);
    expect(find.text('Synthetic private route B'), findsOneWidget);

    scope.updateUser(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Synthetic private route B'), findsNothing);
    expect(second.mounted, isFalse);
    expect(identical(tester.state(find.byType(MaterialApp)), appState), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
