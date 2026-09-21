// 2026-09-21: real form validation, readonly Auth email and responsive layout.
// Synthetic widgets; not device picker, live storage or database persistence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/presentation/bloc/profile_editor_cubit.dart';
import 'package:lexhub/features/auth/presentation/pages/edit_profile_page.dart';
import 'package:lexhub/features/auth/presentation/widgets/profile_details_card.dart';
import '../../../../support/l10n_test_app.dart';
import '../bloc/profile_editor_cubit_test.dart';

void main() {
  late SavingRepository repository;
  late ProfileEditorCubit cubit;
  final profile = UserProfileEntity(
      id: 'synthetic',
      fullName: 'Existing',
      email: 'synthetic@example.invalid',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  setUp(() {
    repository = SavingRepository();
    cubit = ProfileEditorCubit(repository, RecordingAvatars());
  });
  tearDown(() async {
    await cubit.close();
    repository.dispose();
  });

  testWidgets('optional unknown fields are empty; Auth email is read only',
      (tester) async {
    await tester.pumpWidget(
        l10nTestApp(EditProfilePage(profile: profile, cubit: cubit)));
    await tester.pumpAndSettle();
    final first = tester
        .widget<TextFormField>(find.byKey(const ValueKey('profile_firstName')));
    expect(first.controller?.text, isEmpty);
    final inputs = tester.widgetList<TextField>(find.byType(TextField));
    final email = inputs.singleWhere(
        (field) => field.controller?.text == 'synthetic@example.invalid');
    expect(email.readOnly, isTrue);
    expect(find.byKey(const ValueKey('profile_birth_date')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_gender')), findsOneWidget);
  });
  testWidgets('invalid phone never reaches persistence', (tester) async {
    await tester.pumpWidget(
        l10nTestApp(EditProfilePage(profile: profile, cubit: cubit)));
    await tester.enterText(find.byKey(const ValueKey('profile_phone')), '123');
    await tester.ensureVisible(find.byKey(const ValueKey('profile_save')));
    await tester.tap(find.byKey(const ValueKey('profile_save')));
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
    expect(find.text('Telefon raqamini xalqaro formatda kiriting.'),
        findsOneWidget);
  });
  testWidgets('server failure retains editable fields and retry',
      (tester) async {
    repository.fail = true;
    await tester.pumpWidget(
        l10nTestApp(EditProfilePage(profile: profile, cubit: cubit)));
    await tester.enterText(
        find.byKey(const ValueKey('profile_occupation')), 'Synthetic tester');
    await tester.ensureVisible(find.byKey(const ValueKey('profile_save')));
    await tester.tap(find.byKey(const ValueKey('profile_save')));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(cubit.state.error, isNotNull);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('profile_occupation')))
            .controller
            ?.text,
        'Synthetic tester');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('profile_save')))
            .onPressed,
        isNotNull);
  });
  testWidgets('DatePicker and supported gender are sent to persistence',
      (tester) async {
    await tester.pumpWidget(l10nTestApp(EditProfilePage(
        profile: profile.copyWith(dateOfBirth: DateTime(2000, 2, 29)),
        cubit: cubit)));
    await tester.tap(find.byKey(const ValueKey('profile_birth_date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('15').last);
    final ok =
        MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)))
            .okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile_gender')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erkak').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('profile_save')));
    await tester.tap(find.byKey(const ValueKey('profile_save')));
    await tester.pumpAndSettle();
    expect(repository.mockProfile?.dateOfBirth, DateTime(2000, 2, 15));
    expect(repository.mockProfile?.gender, ProfileGender.male);
  });
  testWidgets(
      'profile card displays real private values and has no sample defaults',
      (tester) async {
    await tester.pumpWidget(l10nTestApp(Scaffold(
        body: SingleChildScrollView(
      child: ProfileDetailsCard(
          profile: profile.copyWith(
              firstName: 'Synthetic',
              lastName: 'Citizen',
              phone: '+998901234567',
              address: 'Synthetic address',
              occupation: 'Synthetic occupation',
              bio: 'Synthetic biography',
              dateOfBirth: DateTime(2000, 2, 15),
              gender: ProfileGender.female)),
    ))));
    await tester.pumpAndSettle();
    for (final text in [
      'Synthetic',
      'Citizen',
      '+998901234567',
      'synthetic@example.invalid',
      'Synthetic address',
      'Synthetic occupation',
      'Synthetic biography',
      'Ayol'
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1280, 720),
    const Size(1440, 900)
  ]) {
    testWidgets('profile form has no layout exception at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          l10nTestApp(EditProfilePage(profile: profile, cubit: cubit)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile_save')));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('profile_save')), findsOneWidget);
    });
  }
}
