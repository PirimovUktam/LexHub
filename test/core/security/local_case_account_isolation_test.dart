// 2026-09-19: real Hive storage regression for cross-account history leakage.
// This is a local disk test, not a production auth or device encryption proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/storage/local_case_scope.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_local_datasource.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/data/repositories/legal_assistant_repository_impl.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

LegalResponse response(String text) => LegalResponse(
      id: 'same-id',
      queryId: 'query',
      relatableSummary: text,
      riskAssessment: const RiskAssessment(level: RiskLevel.low, summary: ''),
      createdAt: DateTime.utc(2026, 9, 19),
    );

class DelayedAdvice implements LegalAssistantRemoteDataSource {
  final result = Completer<LegalResponse>();
  @override
  Future<LegalResponse> getLegalAdvice(LegalQuery query) => result.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late Box<String> box;
  late LocalCaseScope scope;
  late LegalAssistantLocalDataSourceImpl store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lexhub-case-isolation-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>('cases');
    scope = LocalCaseScope(userId: 'account-a');
    store = LegalAssistantLocalDataSourceImpl(box: box, scope: scope);
  });

  tearDown(() async {
    scope.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  test('A and B can reuse an ID without reading, overwriting or deleting A',
      () async {
    await store.saveCase(response('private A'));
    scope.updateUser('account-b');
    expect(await store.getSavedCases(), isEmpty);
    await store.saveCase(response('private B'));
    expect((await store.getSavedCases()).single.relatableSummary, 'private B');
    await store.deleteSavedCase('same-id');
    expect(await store.getSavedCases(), isEmpty);
    scope.updateUser('account-a');
    expect((await store.getSavedCases()).single.relatableSummary, 'private A');
  });

  test('logout uses a fresh guest scope and never exposes an account',
      () async {
    await store.saveCase(response('private A'));
    scope.updateUser(null);
    final firstGuest = scope.value;
    expect(await store.getSavedCases(), isEmpty);
    await store.saveCase(response('first guest'));
    scope.updateUser('account-b');
    expect(await store.getSavedCases(), isEmpty);
    scope.updateUser(null);
    expect(scope.value, isNot(firstGuest));
    expect(await store.getSavedCases(), isEmpty);
  });

  test('unowned legacy records remain intact and invisible', () async {
    final legacy = jsonEncode(response('unknown owner').toJson());
    await box.put('legacy-id', legacy);
    expect(await store.getSavedCases(), isEmpty);
    scope.updateUser('account-b');
    expect(await store.getSavedCases(), isEmpty);
    scope.updateUser(null);
    expect(await store.getSavedCases(), isEmpty);
    expect(box.get('legacy-id'), legacy);
  });

  test('reopening the box restores only the same authenticated owner',
      () async {
    await store.saveCase(response('private A'));
    await box.close();
    box = await Hive.openBox<String>('cases');
    store = LegalAssistantLocalDataSourceImpl(box: box, scope: scope);
    expect((await store.getSavedCases()).single.relatableSummary, 'private A');
    scope.updateUser('account-b');
    expect(await store.getSavedCases(), isEmpty);
  });

  test('an answer arriving after an account switch cannot be saved as B',
      () async {
    final remote = DelayedAdvice();
    final repository = LegalAssistantRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: store,
      scope: scope,
    );
    final pending = repository.getLegalAdvice(LegalQuery(
      id: 'q',
      queryText: 'private A input',
      createdAt: DateTime.utc(2026),
    ));
    scope.updateUser('account-b');
    remote.result.complete(response('private A result'));
    final result = await pending;
    final answer = result.getOrElse(() => throw StateError('expected advice'));
    expect(answer.storageScope, 'account:account-a');
    await expectLater(store.saveCase(answer), throwsA(isA<CacheException>()));
    expect(await store.getSavedCases(), isEmpty);
    expect(box.length, 0);
  });

  test('token refresh preserves scope; real auth changes notify once', () {
    var changes = 0;
    scope.addListener(() => changes++);
    scope.updateUser('account-a');
    expect(changes, 0);
    scope.updateUser('account-b');
    expect(changes, 1);
  });
}
