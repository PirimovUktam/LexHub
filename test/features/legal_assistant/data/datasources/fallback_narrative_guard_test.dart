// P1 regression, 2026-09-22: local fallback skipped the narrative boundary.
// Exercises the real datasource and proxy parser with in-memory HTTP only.
// This does not verify legal currency, emergency instructions or deployment.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/deadlines_guard.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_coverage.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/core/network/api_client.dart';
import 'package:lexhub/core/network/gemini_legal_service.dart';
import 'package:lexhub/core/network/legal_ai_proxy_service.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/l10n/gen/app_localizations_uz.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show GoTrueClient, Session, SupabaseClient;

class _Transport implements HttpClientAdapter {
  _Transport(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Transport transport) {
  final dio = Dio(BaseOptions(baseUrl: 'https://legal-ai.test.invalid'));
  dio.httpClientAdapter = transport; // No adapter can open a real socket.
  addTearDown(() => dio.close(force: true));
  return dio;
}

ResponseBody _json(Object? body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });

class _Session extends Fake implements Session {
  @override
  String get accessToken => 'synthetic-session-not-valid-for-auth';
}

class _Auth extends Fake implements GoTrueClient {
  _Auth(this.signedIn);
  final bool signedIn;
  @override
  Session? get currentSession => signedIn ? _Session() : null;
}

class _Supabase extends Fake implements SupabaseClient {
  _Supabase(bool signedIn) : auth = _Auth(signedIn);
  @override
  final GoTrueClient auth;
}

class _Proxy extends LegalAiProxyService {
  _Proxy(_Transport transport, {this.configured = true, bool signedIn = true})
      : super(supabaseClient: _Supabase(signedIn), customDio: _dio(transport));
  final bool configured;
  @override
  bool get isConfigured => configured;
}

class _Gemini extends GeminiLegalService {
  _Gemini([this.result]);
  final LegalResponse? result;
  int calls = 0;

  @override
  Future<LegalResponse?> generateLegalAdvice({
    required LegalQuery query,
    required String sanitizedQuery,
    required List<LawArticleChunk> contextChunks,
  }) async {
    calls++;
    return result;
  }
}

ApiClient _legacy(_Transport transport) {
  final api = ApiClient(customDio: _dio(transport));
  api.dio.interceptors.clear(); // No auth singleton or request/body logging.
  return api;
}

LegalQuery _query(String text) => LegalQuery(
      id: 'fallback-regression',
      queryText: text,
      createdAt: DateTime.utc(2026, 9, 22),
    );

const _hostile = '777-modda: bugun to‘lang; g‘alaba kafolatlanadi.';
Map<String, dynamic> _remoteResponse() => {
      'id': 'remote-candidate',
      'query_id': 'model-invented-query',
      'user_query': 'model-invented-facts',
      'source': LegalResponse.sourceLlm,
      'relatable_summary': _hostile,
      'actionable_steps': [_hostile],
      'legal_basis': [
        {
          'law_name': 'Mehnat kodeksi',
          'article_number': '333-modda',
          'article_text': _hostile,
          'lex_url': 'https://example.invalid/untrusted',
        },
      ],
      'risk_assessment': {
        'level': 'critical',
        'summary': _hostile,
        'limitations': [_hostile],
        'deadline_days': 7,
      },
    };

// Assert the public narrative contract, without calling the guard as an oracle.
// Numbers/legal wording inside canonical excerpts are intentionally preserved.
void _expectBounded(LegalResponse result, LegalQuery query,
    {String source = LegalResponse.sourceDeterministic}) {
  final text = AppL10nUz();
  expect(result.source, source);
  expect(result.queryId, query.id);
  expect(result.userQuery, query.queryText);
  expect(result.relatableSummary, isNotEmpty);
  expect(result.actionableSteps, isNotEmpty);
  expect(result.legalBasis.length, lessThanOrEqualTo(3));
  final excerpts = <String>[];
  final sourceSteps = <String>[];
  for (var i = 0; i < result.legalBasis.length; i++) {
    final article = result.legalBasis[i];
    final canonical = UzbekLegalKnowledgeBase.verifiedLawChunks
        .where((chunk) =>
            chunk.documentName == article.lawName &&
            '${chunk.articleNumber}-modda' == article.articleNumber)
        .toList();
    expect(canonical, hasLength(1));
    expect(article, canonical[0].toLawArticle());
    final label = '[${i + 1}] ${article.lawName}, ${article.articleNumber}';
    excerpts.add(
        '$label\n${article.articleText.length <= 900 ? '«${article.articleText}»' : text.legalEvidenceReadSource}');
    sourceSteps.add('$label: ${text.legalEvidenceReadSource}');
  }
  expect(
      result.relatableSummary,
      result.legalBasis.isEmpty
          ? text.legalEvidenceSummaryMissing
          : '${text.legalEvidenceSummaryIntro}\n\n${excerpts.join('\n\n')}');
  expect(result.actionableSteps, [
    text.legalEvidenceCollectRecords,
    text.legalEvidenceRecordDates,
    ...sourceSteps,
    text.legalEvidenceConsultLawyer,
  ]);
  expect(result.riskAssessment.deadlineDays, isNull);
  expect(result.riskAssessment.level, isNot(RiskLevel.low));
  expect(result.riskAssessment.requiresLawyer, isTrue);
  if (result.legalBasis.isNotEmpty) {
    expect(
        result.riskAssessment.limitations,
        containsAll([
          text.legalEvidenceApplicabilityLimit,
          text.legalEvidenceDeadlineUnknown,
        ]));
  } else {
    expect(result.riskAssessment.summary, contains('BAHOLANMADI'));
    expect(result.riskAssessment.limitations.join(' '), contains('MUDDAT KO'));
  }
}

void main() {
  test(
      'all external services fail: local fallback must obey narrative contract',
      () async {
    final proxyTransport = _Transport((_) => _json({
          'error': {'code': 'rate_limited'},
        }, 429));
    final proxy = _Proxy(proxyTransport);
    final gemini = _Gemini();
    final legacyTransport = _Transport((_) => _json({}, 503));
    final datasource = LegalAssistantRemoteDataSourceImpl(
      legalAiProxyService: proxy,
      geminiService: gemini,
      apiClient: _legacy(legacyTransport),
    );
    final query = _query('Ish haqi kechiktirilmoqda');
    final result = await datasource.getLegalAdvice(query);

    expect(proxyTransport.calls, 1);
    expect(proxy.lastErrorCode, 'rate_limited');
    expect(gemini.calls, 1);
    expect(legacyTransport.calls, 1);
    expect(result.id, startsWith('resp_'));
    expect(result.source, LegalResponse.sourceDeterministic);
    expect(result.legalBasis, isNotEmpty);
    expect(result.relatableSummary, isNotEmpty);
    expect(result.actionableSteps, isNotEmpty);
    _expectBounded(result, query);
  });

  for (final mode in [
    (name: 'no configuration', configured: false, signedIn: true),
    (name: 'no session', configured: true, signedIn: false),
  ]) {
    test('${mode.name}: fallback is bounded without an HTTP call', () async {
      final transport = _Transport((_) => throw StateError('Unexpected HTTP'));
      final proxy = _Proxy(transport,
          configured: mode.configured, signedIn: mode.signedIn);
      final query = _query('Ish haqi kechiktirilmoqda');
      final result = await LegalAssistantRemoteDataSourceImpl(
        legalAiProxyService: proxy,
      ).getLegalAdvice(query);
      expect(transport.calls, 0);
      expect(proxy.lastErrorCode, mode.configured ? 'unauthenticated' : null);
      expect(result.id, startsWith('resp_'));
      expect(result.legalBasis, isNotEmpty);
      _expectBounded(result, query);
    });
  }

  for (final failure in [
    (name: '401', status: 401, body: <String, Object?>{}, code: 'http_401'),
    (
      name: '429',
      status: 429,
      body: {
        'error': {'code': 'rate_limited'}
      },
      code: 'rate_limited'
    ),
    (
      name: '503',
      status: 503,
      body: {
        'error': {'code': 'evidence_unavailable'}
      },
      code: 'evidence_unavailable'
    ),
    (
      name: '502 provider quota',
      status: 502,
      body: {
        'error': {'code': 'ai_quota'}
      },
      code: 'ai_quota'
    ),
    (
      name: 'empty summary',
      status: 200,
      body: {'relatable_summary': ' '},
      code: 'empty_response'
    ),
    (
      name: 'missing summary',
      status: 200,
      body: <String, Object?>{},
      code: 'empty_response'
    ),
    (
      name: 'malformed list',
      status: 200,
      body: <Object?>[],
      code: 'malformed_response'
    ),
    (
      name: 'invalid JSON string',
      status: 200,
      body: '{not-json',
      code: 'client_exception'
    ),
    (
      name: 'wrong summary type',
      status: 200,
      body: {'relatable_summary': 7},
      code: 'client_exception'
    ),
  ]) {
    test('proxy ${failure.name}: real parsing falls back through guard',
        () async {
      final transport = _Transport((_) => _json(failure.body, failure.status));
      final proxy = _Proxy(transport);
      final query = _query('Ish haqi kechiktirilmoqda');
      final result = await LegalAssistantRemoteDataSourceImpl(
        legalAiProxyService: proxy,
      ).getLegalAdvice(query);
      expect(transport.calls, 1);
      expect(proxy.lastErrorCode, failure.code);
      expect(result.id, startsWith('resp_'));
      expect(result.legalBasis, isNotEmpty);
      _expectBounded(result, query);
    });
  }

  for (final timeout in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionTimeout,
  ]) {
    test('proxy $timeout: timeout reaches bounded fallback', () async {
      final transport = _Transport((options) => throw DioException(
            requestOptions: options,
            type: timeout,
          ));
      final proxy = _Proxy(transport);
      final query = _query('Ish haqi kechiktirilmoqda');
      final result = await LegalAssistantRemoteDataSourceImpl(
        legalAiProxyService: proxy,
      ).getLegalAdvice(query);
      expect(transport.calls, 1);
      expect(proxy.lastErrorCode, 'client_timeout');
      expect(result.id, startsWith('resp_'));
      expect(result.legalBasis, isNotEmpty);
      _expectBounded(result, query);
    });
  }

  for (final scenario in {
    LegalDomain.mehnat: 'Ish haqi kechiktirilmoqda',
    LegalDomain.mamuriy: 'Radar jarima qarori ustidan shikoyat',
    LegalDomain.oila: 'Aliment undirish uchun sudga murojaat qilmoqchiman',
    LegalDomain.istemolchi: 'Nuqsonli tovarni almashtirish va pulni qaytarish',
    LegalDomain.fuqarolik: 'Qarz tilxat bo‘yicha qaytarilmayapti',
    LegalDomain.konstitutsiya:
        'Konstitutsiya: shaxsiy daxlsizlik va erkinlik huquqi',
  }.entries) {
    test('${scenario.key.name}: local domain prose is source bounded',
        () async {
      final query = _query(scenario.value);
      final chunks =
          LegalKnowledgeRetriever.retrieveRelevantChunks(query.queryText);
      expect(LegalCoverage.dominantDomain(chunks), scenario.key);
      final result =
          await LegalAssistantRemoteDataSourceImpl().getLegalAdvice(query);
      expect(result.id, startsWith('resp_'));
      expect(result.legalBasis, isNotEmpty);
      _expectBounded(result, query);
    });
  }

  test('no source: preserves coverage warning and authority routing', () async {
    final query = _query('Kriptovalyuta soliqlarini hisoblash');
    final organ =
        LegalCoverage.classify(query.queryText).uncoveredTopic?.organName;
    expect(organ, isNotNull);
    final result =
        await LegalAssistantRemoteDataSourceImpl().getLegalAdvice(query);
    expect(result.legalBasis, isEmpty);
    expect(result.riskAssessment.level, RiskLevel.high);
    expect(result.riskAssessment.summary, contains(organ));
    _expectBounded(result, query);
  });

  test('mixed deadline keyword cannot inject a different procedure', () async {
    final query = _query('Qarz tilxat qarzdorlik');
    final deadline = DeadlinesGuard.evaluateDeadline(query.queryText);
    expect(deadline?.lawReference, 'Oila kodeksi 136-modda');
    final result =
        await LegalAssistantRemoteDataSourceImpl().getLegalAdvice(query);
    expect(result.legalBasis, isNotEmpty);
    expect(result.legalBasis.every((a) => a.lawName.contains('Fuqarolik')),
        isTrue);
    expect(result.actionableSteps.join(' '),
        isNot(contains(deadline?.description)));
    _expectBounded(result, query);
  });

  test(
      'emergency fallback preserves local signal after narrative normalization',
      () async {
    final datasource = LegalAssistantRemoteDataSourceImpl();
    final query = _query(
        "Meni ichki ishlar bo'limida ushlab turishibdi va majburiy so'roq qilishyapti");
    final local = await datasource.detectEmergency(query.queryText);
    expect(local?.isEmergency, isTrue);
    final result = await datasource.getLegalAdvice(query);
    expect(result.emergencyProtocol?.isEmergency, isTrue);
    expect(result.emergencyProtocol?.immediateActions, local?.immediateActions);
    expect(result.emergencyProtocol?.constitutionalRights,
        local?.constitutionalRights);
    expect(result.riskAssessment.level, RiskLevel.critical);
    expect(result.legalBasis, isNotEmpty);
    _expectBounded(result, query);
    // Equality preserves existing guidance; it does not certify legal correctness.
  });

  test(
      'emergency without matching source keeps critical warning and empty basis',
      () async {
    final query = _query('Meni ichki ishlar bo‘limida hibsga olishdi');
    final result =
        await LegalAssistantRemoteDataSourceImpl().getLegalAdvice(query);
    expect(result.emergencyProtocol?.isEmergency, isTrue);
    expect(result.riskAssessment.level, RiskLevel.critical);
    expect(result.legalBasis, isEmpty);
    _expectBounded(result, query);
  });

  test(
      'valid proxy no-source response is guarded without local basis resurrection',
      () async {
    final transport = _Transport((_) => _json({
          ..._remoteResponse(),
          'legal_basis': <Object?>[],
          'source': LegalResponse.sourceDeterministic,
        }));
    final proxy = _Proxy(transport);
    final query = _query('Ish haqi kechiktirilmoqda');
    final result = await LegalAssistantRemoteDataSourceImpl(
      legalAiProxyService: proxy,
    ).getLegalAdvice(query);
    expect(transport.calls, 1);
    expect(proxy.lastErrorCode, isNull);
    expect(result.id, 'remote-candidate');
    expect(result.legalBasis, isEmpty);
    _expectBounded(result, query);
  });

  for (final path in ['proxy', 'gemini', 'legacy']) {
    test('$path success: hostile prose is stripped while real source survives',
        () async {
      final transport = _Transport((_) => _json(_remoteResponse()));
      final gemini = _Gemini(LegalResponse.fromJson(_remoteResponse()));
      final query = _query('Ish haqi kechiktirilmoqda');
      final result = await LegalAssistantRemoteDataSourceImpl(
        legalAiProxyService: path == 'proxy' ? _Proxy(transport) : null,
        geminiService: path == 'gemini' ? gemini : null,
        apiClient: path == 'legacy' ? _legacy(transport) : null,
      ).getLegalAdvice(query);
      expect(transport.calls, path == 'gemini' ? 0 : 1);
      expect(gemini.calls, path == 'gemini' ? 1 : 0);
      expect(result.id, 'remote-candidate');
      expect(result.legalBasis, hasLength(1));
      expect(result.toJson().toString(), isNot(contains(_hostile)));
      expect(result.riskAssessment.level, RiskLevel.critical);
      expect(result.emergencyProtocol, isNull);
      _expectBounded(result, query, source: LegalResponse.sourceLlm);
    });
  }
}
