// P1 regression, 2026-09-22: emergency signals invented unrelated events and
// added unsourced procedural instructions after LegalNarrativeGuard.
// Local synthetic inputs only; this does not verify legal accuracy or deployment.
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/emergency_detector.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/network/legal_ai_proxy_service.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

class _UnavailableProxy extends Fake implements LegalAiProxyService {
  int calls = 0;
  @override
  bool get isConfigured => true;
  @override
  String? get lastErrorCode => 'ai_not_configured';
  @override
  Future<LegalResponse?> generateLegalAdvice({
    required LegalQuery query,
    required String sanitizedQuery,
    required List<LawArticleChunk> contextChunks,
  }) async {
    calls++;
    return null;
  }
}

void _expectConditional(EmergencyProtocol protocol, int signalCount) {
  expect(protocol.isEmergency, isTrue);
  expect(protocol.emergencyHotline, '1002');
  expect(protocol.title, contains('tasdiqlanmagan'));
  expect(protocol.redFlags, hasLength(signalCount));
  expect(protocol.redFlags, everyElement(startsWith('Agar ')));
  expect(protocol.constitutionalRights, isEmpty,
      reason: 'A keyword signal is not source-grounded legal advice.');
  expect(protocol.immediateActions, isNotEmpty);
  expect(protocol.immediateActions.join(' '), contains('advokat'));
  final prose = [
    protocol.title,
    ...protocol.redFlags,
    ...protocol.immediateActions,
  ].join(' ');
  expect(prose, isNot(contains("tintuv o'tkazilmoqda")));
  expect(prose, isNot(contains('majburlanmoqdasiz')));
  expect(prose, isNot(contains('bepul')));
  expect(prose, isNot(contains("qo'l qo'ymang")));
  expect(RegExp(r'\d+\s*-?(?:modda|marta|marotaba)').hasMatch(prose), isFalse);
}

void main() {
  final source = LegalAssistantRemoteDataSourceImpl();

  test('detention must not assert an unmentioned search', () async {
    const query = "Meni ushlab turishibdi va advokatsiz so'roq qilishyapti";
    final signal = EmergencyDetector.classify(query);
    expect(signal.triggers, {
      EmergencyTrigger.arrest,
      EmergencyTrigger.coercedInterrogation,
    });
    final protocol = await source.detectEmergency(query);
    expect(protocol, isNotNull);
    final prose = protocol?.toJson().toString() ?? '';
    expect(prose, isNot(contains('tintuv')),
        reason: 'No search signal exists; output must not invent one.');
  });

  final inputs = {
    EmergencyTrigger.arrest: 'Meni hibsga olishdi',
    EmergencyTrigger.search: 'Uyimda tintuv qilishyapti',
    EmergencyTrigger.coercedInterrogation: "Meni advokatsiz so'roq qilishyapti",
    EmergencyTrigger.violence: 'Menga tahdid qilishyapti',
  };
  final signalTerms = {
    EmergencyTrigger.arrest: 'ushlab turish',
    EmergencyTrigger.search: 'tintuv',
    EmergencyTrigger.coercedInterrogation: 'so‘roq',
    EmergencyTrigger.violence: 'zo‘ravonlik',
  };
  for (final entry in inputs.entries) {
    test('${entry.key.name}: one signal yields one conditional, not facts',
        () async {
      expect(EmergencyDetector.classify(entry.value).triggers, {entry.key});
      final protocol = await source.detectEmergency(entry.value);
      expect(protocol, isA<EmergencyProtocol>());
      if (protocol == null) return; // The assertion above fails first.
      _expectConditional(protocol, 1);
      // Other trigger-specific scenarios must not be added to this response.
      final flags = protocol.redFlags.join(' ');
      expect(flags, contains(signalTerms[entry.key]));
      if (entry.key != EmergencyTrigger.search) {
        expect(flags, isNot(contains('tintuv')));
      }
      if (entry.key != EmergencyTrigger.arrest) {
        expect(flags, isNot(contains('ushlab turish')));
      }
      if (entry.key != EmergencyTrigger.coercedInterrogation) {
        expect(flags, isNot(contains('so‘roq')));
      }
      if (entry.key != EmergencyTrigger.violence) {
        expect(flags, isNot(contains('zo‘ravonlik')));
      }
    });
  }

  test(
      'multiple signals retain only their matching guidance through serialization',
      () async {
    const query =
        "Meni hibsda advokatsiz so'roq qilishyapti, tintuv va tahdid bor";
    expect(EmergencyDetector.classify(query).triggers,
        EmergencyTrigger.values.toSet());
    final protocol = await source.detectEmergency(query);
    expect(protocol, isNotNull);
    if (protocol == null) return;
    final restored = EmergencyProtocol.fromJson(protocol.toJson());
    expect(restored, protocol);
    _expectConditional(restored, 4);
    for (final term in signalTerms.values) {
      expect(
          restored.redFlags.where((flag) => flag.contains(term)), hasLength(1));
    }
  });

  test(
      'hypothetical and negated keywords remain signals, never confirmed events',
      () async {
    for (final query in [
      'Agar hibs bo‘lsa nima qilaman?',
      'Tintuv bo‘lmagan'
    ]) {
      final protocol = await source.detectEmergency(query);
      expect(protocol, isA<EmergencyProtocol>());
      if (protocol == null) continue;
      _expectConditional(protocol, 1);
    }
  });

  for (final scenario in [
    (
      query: "Meni ushlab turishibdi va majburiy so'roq qilishyapti",
      signals: 2,
      hasSources: true
    ),
    (query: 'Meni hibsga olishdi', signals: 1, hasSources: false),
  ]) {
    test(
        'full fallback pipeline, sources=${scenario.hasSources}, keeps critical signal',
        () async {
      final proxy = _UnavailableProxy();
      final datasource = LegalAssistantRemoteDataSourceImpl(
        legalAiProxyService: proxy,
      );
      final result = await datasource.getLegalAdvice(LegalQuery(
        id: 'synthetic-emergency',
        queryText: scenario.query,
        createdAt: DateTime.utc(2026, 9, 22),
      ));
      expect(proxy.calls, 1);
      expect(result.source, LegalResponse.sourceDeterministic);
      expect(result.relatableSummary, isNotEmpty);
      expect(result.actionableSteps, isNotEmpty);
      expect(result.legalBasis.isNotEmpty, scenario.hasSources);
      expect(result.riskAssessment.level, RiskLevel.critical);
      expect(result.riskAssessment.requiresLawyer, isTrue);
      expect(result.riskAssessment.deadlineDays, isNull);
      final protocol = result.emergencyProtocol;
      expect(protocol, isA<EmergencyProtocol>());
      if (protocol == null) return;
      _expectConditional(protocol, scenario.signals);
      expect(protocol.toJson().toString(), isNot(contains('tintuv')));
    });
  }

  test('neutral query still has no emergency protocol', () async {
    expect(await source.detectEmergency('Soliq kameral tekshiruvi'), isNull);
  });

  test('violence-only risk summary must not add detention or investigation',
      () async {
    final result = await source.getLegalAdvice(LegalQuery(
      id: 'synthetic-threat',
      queryText: 'Ish haqi kechiktirilmoqda. Menga tahdid qilishyapti',
      createdAt: DateTime.utc(2026, 9, 22),
    ));
    expect(EmergencyDetector.classify(result.userQuery).triggers,
        {EmergencyTrigger.violence});
    expect(result.legalBasis, isNotEmpty);
    expect(result.emergencyProtocol?.isEmergency, isTrue);
    expect(result.riskAssessment.level, RiskLevel.critical);
    expect(result.riskAssessment.summary.toLowerCase(),
        isNot(contains('erkinlik cheklanishi')));
    expect(
        result.riskAssessment.summary.toLowerCase(), isNot(contains('tergov')));
    expect(result.riskAssessment.summary, contains('tasdiqlanmagan'));
  });
}
