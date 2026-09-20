// Guards private-profile RPC routing and ownership, measured 2026-09-20.
// Synthetic mocked HTTP proves client behavior, not deployed RLS or real login.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lexhub/features/auth/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '20000000-0000-4000-8000-000000000001';
const _other = '20000000-0000-4000-8000-000000000002';

void main() {
  late SupabaseClient client;
  late AuthRemoteDataSourceImpl datasource;
  late List<http.Request> requests;
  late Object? profileReply;
  const profile = <String, dynamic>{
    'id': _owner,
    'full_name': 'Synthetic User',
    'phone': 'SYNTHETIC-PRIVATE',
    'role': 'citizen',
    'is_verified': false,
    'created_at': '2026-09-20T00:00:00Z',
    'updated_at': '2026-09-20T00:00:00Z',
  };

  setUp(() async {
    requests = [];
    profileReply = profile;
    final tokenPart = base64Url
        .encode(utf8.encode(jsonEncode({
          'sub': _owner,
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        })))
        .replaceAll('=', '');
    client = SupabaseClient('http://127.0.0.1:54321', 'synthetic-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
            jsonEncode({
              'access_token': 'e30.$tokenPart.synthetic-signature',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'synthetic-refresh-token',
              'user': {
                'id': _owner,
                'aud': 'authenticated',
                'email': 'synthetic@example.invalid',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-09-20T00:00:00Z'
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request);
      }
      requests.add(request);
      if (request.url.path == '/auth/v1/logout') {
        return http.Response('', 204, request: request);
      }
      if (request.url.path == '/rest/v1/rpc/get_my_profile') {
        return http.Response(jsonEncode(profileReply), 200,
            headers: {'content-type': 'application/json'}, request: request);
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/rest/v1/profiles') {
        return http.Response('', 204, request: request);
      }
      throw StateError('Unexpected private-profile request path');
    }));
    datasource = AuthRemoteDataSourceImpl(supabaseClient: client);
    await client.auth.signInWithPassword(
        email: 'synthetic@example.invalid', password: 'synthetic-fixture');
  });
  tearDown(() => client.dispose());

  test('logout revokes the native server session globally', () async {
    await datasource.signOut();
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/auth/v1/logout');
    expect(requests.single.url.queryParameters['scope'], 'global');
    expect(client.auth.currentSession, isNull);
  });

  test('own profile uses parameter-free RPC and preserves private fields',
      () async {
    final result = await datasource.getUserProfile(_owner);
    expect(result.id, _owner);
    expect(result.phone, 'SYNTHETIC-PRIVATE');
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/get_my_profile');
    expect(jsonDecode(requests.single.body), <String, dynamic>{});
  });

  test('different account read is rejected before HTTP', () async {
    await expectLater(
        datasource.getUserProfile(_other),
        throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 403)));
    expect(requests, isEmpty);
  });

  test('missing profile keeps the explicit invariant failure', () async {
    profileReply = null;
    await expectLater(
        datasource.getUserProfile(_owner),
        throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 404)));
  });

  test('malformed and wrong-owner RPC payloads are rejected', () async {
    for (final payload in [
      <Object>[],
      {...profile, 'id': _other}
    ]) {
      profileReply = payload;
      await expectLater(
          datasource.getUserProfile(_owner),
          throwsA(isA<ServerException>()
              .having((e) => e.statusCode, 'status', 502)));
    }
  });

  test('profile update avoids private table RETURNING and rereads owner RPC',
      () async {
    final result =
        await datasource.updateUserProfile(UserProfileModel.fromJson(profile));
    expect(result.phone, 'SYNTHETIC-PRIVATE');
    expect(requests, hasLength(2));
    expect(requests.first.method, 'PATCH');
    expect(requests.first.url.queryParameters['id'], 'eq.$_owner');
    expect(requests.first.url.queryParameters.containsKey('select'), isFalse);
    expect(requests.first.headers['Prefer'],
        isNot(contains('return=representation')));
    expect(requests.last.url.path, '/rest/v1/rpc/get_my_profile');
  });

  test('different account update is rejected before HTTP', () async {
    await expectLater(
        datasource.updateUserProfile(
            UserProfileModel.fromJson({...profile, 'id': _other})),
        throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 403)));
    expect(requests, isEmpty);
  });
}
