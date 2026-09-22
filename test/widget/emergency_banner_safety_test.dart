// P1 regression, 2026-09-22: the banner must preserve the critical signal but
// must not reintroduce a fixed Miranda script after safe protocol generation.
// Widget runtime only; not a live phone call, legal review or deployment proof.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/emergency_banner_widget.dart';
import 'package:lexhub/l10n/gen/app_localizations_uz.dart';

import '../support/l10n_test_app.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('critical banner keeps safe guidance at ${size.width}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final protocol = await LegalAssistantRemoteDataSourceImpl()
          .detectEmergency('Meni hibsga olishdi');
      expect(protocol, isNotNull);
      if (protocol == null) return;
      await tester.pumpWidget(l10nTestApp(
        Scaffold(
          body: SingleChildScrollView(
            child: EmergencyBannerWidget(protocol: protocol),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      final text = AppL10nUz();
      expect(find.text(text.aiEmergencyAlertTitle), findsOneWidget);
      expect(find.text(protocol.title), findsOneWidget);
      for (final guidance in [
        ...protocol.redFlags,
        ...protocol.immediateActions
      ]) {
        expect(find.text(guidance), findsOneWidget);
      }
      final call =
          find.widgetWithText(ElevatedButton, text.emergencyCallAction('1002'));
      expect(call, findsOneWidget);
      expect(tester.widget<ElevatedButton>(call).onPressed, isNotNull);
      expect(find.text(text.emergencyMirandaTitle), findsNothing,
          reason: 'A fixed legal script must not bypass the safe protocol.');
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join(' ');
      expect(visibleText, isNot(contains('tintuv')));
      expect(visibleText, contains('tasdiqlanmagan'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('nonempty legacy rights cannot enable a fixed legal script',
      (tester) async {
    const protocol = EmergencyProtocol(
      isEmergency: true,
      title: 'Synthetic legacy protocol',
      constitutionalRights: ['Synthetic unverified rights'],
    );
    await tester.pumpWidget(l10nTestApp(const Scaffold(
      body: SingleChildScrollView(
        child: EmergencyBannerWidget(protocol: protocol),
      ),
    )));
    await tester.pump(const Duration(milliseconds: 200));
    final text = AppL10nUz();
    expect(find.text(text.aiEmergencyAlertTitle), findsOneWidget);
    expect(find.text(text.emergencyCallAction('1002')), findsOneWidget);
    expect(find.text(text.emergencyMirandaTitle), findsNothing);
    expect(find.text(text.emergencyMirandaScriptText), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
