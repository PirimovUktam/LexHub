import 'package:dartz/dartz.dart' show Either, Right;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/features/legal_experts/data/models/advocate_profile_model.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/advocate_profile_actions.dart';
import '../../../support/l10n_test_app.dart';

class _HoursRepository implements AdvocateProfileRepository {
  AdvocateWorkingHours? saved;

  @override
  Future<Either<Failure, AdvocateWorkingHours>> saveWorkingHours(
      String expertId, AdvocateWorkingHours value) async {
    saved = value;
    return Right(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final closed in [false, true]) {
    testWidgets('reopen and save PostgREST ${closed ? 'closed' : 'open'} hours',
        (tester) async {
      final repository = _HoursRepository();
      // These are PostgreSQL time/null values, not the UI's HH:mm defaults.
      final hours = AdvocateProfileModel.workingHoursFromJson({
        'id': 'hours-synthetic',
        'weekday': closed ? 7 : 1,
        'opens_at': closed ? null : '09:00:00',
        'closes_at': closed ? null : '18:00:00',
        'is_closed': closed,
      });
      bool? success;
      await tester.pumpWidget(l10nTestApp(
        Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      success = await AdvocateProfileActions(
                              context,
                              repository,
                              const AdvocateProfile(
                                  id: 'expert-synthetic', isOwner: true))
                          .hours(hours);
                    },
                    child: const Text('Open synthetic hours')))),
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
      ));
      await tester.tap(find.text('Open synthetic hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('advocate_save')));
      await tester.pumpAndSettle();
      expect(repository.saved, isNotNull,
          reason:
              'Existing backend hours must be resavable without manual repairs.');
      expect(repository.saved?.id, 'hours-synthetic');
      expect(repository.saved?.weekday, closed ? 7 : 1);
      expect(repository.saved?.isClosed, closed);
      expect(success, isTrue);
      final json = AdvocateProfileModel.workingHoursToJson(repository.saved!);
      expect(json['opens_at'], closed ? isNull : '09:00');
      expect(json['closes_at'], closed ? isNull : '18:00');
      expect(tester.takeException(), isNull);
    });
  }
}
