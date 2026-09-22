// Guards advocate CRUD routing, ownership binding, failures and private storage.
// Measured 2026-09-22. Mock HTTP exercises the real Supabase client; it does not
// prove deployed RLS, content scanning or a real account's access rights.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/legal_experts/data/datasources/advocate_profile_remote_datasource.dart';
import 'package:lexhub/features/legal_experts/data/repositories/advocate_profile_repository_impl.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '20000000-0000-4000-8000-000000000001';
const _expert = '20000000-0000-4000-8000-000000000002';
const _object = '20000000-0000-4000-8000-000000000003';
const _service = '20000000-0000-4000-8000-000000000004';
const _path = '$_owner/$_object.pdf';

void main() {
  late SupabaseClient client;
  late AdvocateProfileRemoteDataSourceImpl datasource;
  late AdvocateProfileRepositoryImpl repository;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;
  var status = 200;
  Object? reply;

  http.Response response(Object? body, [int code = 200]) =>
      http.Response(jsonEncode(body), code,
          headers: {'content-type': 'application/json'});

  Map<String, dynamic> profile() => {
        'id': _expert,
        'user_id': _owner,
        'is_owner': true,
        'first_name': 'Synthetic',
        'last_name': 'Advocate',
      };
  Map<String, dynamic> service() => {
        'id': _service,
        'expert_id': _expert,
        'title': 'Consultation',
        'delivery_mode': 'online',
        'price_uzs': 123000,
        'duration_minutes': 30,
        'is_active': true,
      };
  Map<String, dynamic> document() => {
        'id': _object,
        'title': 'Synthetic certificate',
        'kind': 'certificate',
        'object_path': _path,
        'is_public': false,
      };
  Map<String, dynamic> requestRow() => {
        'id': _object,
        'expert_id': _expert,
        'requester_id': _owner,
        'service_id': _service,
        'service_title': 'Consultation',
        'price_uzs': 123000,
        'kind': 'consultation',
        'message': 'Synthetic request',
        'status': 'pending',
        'created_at': '2026-09-22T00:00:00Z',
      };

  setUp(() async {
    requests = [];
    status = 200;
    reply = profile();
    handler = (request) async => response(reply, status);
    client = SupabaseClient('http://127.0.0.1:54321', 'synthetic-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
        httpClient: MockClient((request) async {
      requests.add(request);
      final result = await handler(request);
      return http.Response.bytes(result.bodyBytes, result.statusCode,
          headers: result.headers, request: request);
    }));
    await client.auth.recoverSession(jsonEncode({
      'access_token': 'test-access-token',
      'token_type': 'bearer',
      'refresh_token': 'test-refresh-token',
      'user': {
        'id': _owner,
        'aud': 'authenticated',
        'role': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-09-22T00:00:00Z',
      },
    }));
    datasource = AdvocateProfileRemoteDataSourceImpl(supabaseClient: client);
    repository = AdvocateProfileRepositoryImpl(remoteDataSource: datasource);
  });
  tearDown(() => client.dispose());

  test('public read uses explicit expert RPC and preserves returned identity',
      () async {
    final result = await datasource.getProfile(_expert);
    expect(result.id, _expert);
    expect(requests.single.url.path, '/rest/v1/rpc/get_advocate_profile');
    expect(jsonDecode(requests.single.body), {'p_expert_id': _expert});
  });

  test('private read uses no caller-supplied owner ID', () async {
    expect((await datasource.getMyProfile())?.userId, _owner);
    expect(requests.single.url.path, '/rest/v1/rpc/get_my_advocate_profile');
    expect(jsonDecode(requests.single.body), {});
    reply = null;
    expect(await datasource.getMyProfile(), isNull);
  });

  test('missing, malformed and mismatched public profiles are failures',
      () async {
    for (final value in [
      null,
      [],
      {},
      {...profile(), 'id': _owner}
    ]) {
      reply = value;
      await expectLater(
          datasource.getProfile(_expert), throwsA(isA<ServerException>()));
    }
  });

  test('wrong owner aggregate cannot masquerade as saved own profile',
      () async {
    reply = {...profile(), 'user_id': _expert};
    await expectLater(
        datasource.getMyProfile(), throwsA(isA<ServerException>()));
    await expectLater(
        datasource.saveProfile(const AdvocateProfileInput(
            firstName: 'Synthetic', lastName: 'Advocate')),
        throwsA(isA<ServerException>()));
  });

  test('profile save sends write allowlist and awaits actual backend aggregate',
      () async {
    final result = await datasource.saveProfile(const AdvocateProfileInput(
        firstName: ' Synthetic ', lastName: ' Advocate ', isPublished: true));
    expect(result.id, _expert);
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(requests.single.url.path, '/rest/v1/rpc/save_advocate_profile');
    expect(body.keys, ['p_profile']);
    final values = body['p_profile'] as Map;
    expect(values['first_name'], 'Synthetic');
    expect(values['is_published'], true);
    expect(values.keys, isNot(contains('verified')));
    expect(values.keys, isNot(contains('user_id')));
    reply = null;
    await expectLater(
        datasource.saveProfile(const AdvocateProfileInput(
            firstName: 'Synthetic', lastName: 'Advocate')),
        throwsA(isA<ServerException>()));
  });

  test('service create uses returned row, never client-synthesized success',
      () async {
    reply = service();
    final result = await datasource.saveService(_expert,
        const AdvocateService(title: ' Consultation ', priceUzs: 123000));
    expect(result.id, _service);
    expect(result.durationMinutes, 30);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/advocate_services');
    expect(jsonDecode(requests.single.body)['expert_id'], _expert);
    expect(jsonDecode(requests.single.body)['title'], 'Consultation');
    expect(jsonDecode(requests.single.body).containsKey('id'), false);
  });

  test('service update is scoped by both expert and row identity', () async {
    reply = service();
    await datasource.saveService(
        _expert, const AdvocateService(id: _service, title: 'Consultation'));
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.queryParameters['id'], 'eq.$_service');
    expect(requests.single.url.queryParameters['expert_id'], 'eq.$_expert');
    expect(jsonDecode(requests.single.body).containsKey('expert_id'), false);
  });

  test(
      'invisible or denied delete is not successful and preserves typed errors',
      () async {
    status = 406;
    reply = {'code': 'PGRST116', 'message': 'No rows returned'};
    final missing = await repository.deleteService(_service);
    expect(missing.isLeft(), true);
    expect(missing.fold((failure) => failure.code, (_) => null),
        FailureCode.notFound);
    status = 403;
    reply = {'code': '42501', 'message': 'PRIVATE-SYNTHETIC-DETAIL'};
    final denied = await repository.deleteService(_service);
    expect(denied.fold((failure) => failure.code, (_) => null),
        FailureCode.forbidden);
    expect(
        denied.fold(
            (failure) => '${failure.message} ${failure.details}', (_) => ''),
        isNot(contains('PRIVATE-SYNTHETIC-DETAIL')));
  });

  test('timeout and rate limit remain actionable normalized failures',
      () async {
    handler = (_) async => throw TimeoutException('PRIVATE-SYNTHETIC-DETAIL');
    final timedOut = await repository.getProfile(_expert);
    expect(timedOut.fold((failure) => failure.code, (_) => null),
        FailureCode.timeout);
    expect(timedOut.fold((failure) => '${failure.details}', (_) => ''),
        isNot(contains('PRIVATE-SYNTHETIC-DETAIL')));
    handler =
        (_) async => response({'code': 'PT429', 'message': 'Rate limit'}, 429);
    final rateLimited = await repository.sendRequest(
        expertId: _expert, message: 'Synthetic request');
    expect(rateLimited.fold((failure) => failure.code, (_) => null),
        FailureCode.rateLimited);
  });

  test(
      'avatar rejects PDF, spoofed image content and oversized input before HTTP',
      () async {
    for (final input in [
      (Uint8List.fromList(utf8.encode('%PDF-synthetic')), 'application/pdf'),
      (
        Uint8List.fromList(utf8.encode('<script>synthetic</script>')),
        'image/png'
      ),
      (Uint8List(10 * 1024 * 1024 + 1), 'image/png'),
    ]) {
      await expectLater(datasource.uploadAvatar(input.$1, input.$2),
          throwsA(isA<ValidationException>()));
    }
    expect(requests, isEmpty);
  });

  test('avatar upload uses private bucket random owned path and no overwrite',
      () async {
    reply = {'Key': 'synthetic-upload'};
    final path = await datasource.uploadAvatar(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]), 'image/jpeg');
    expect(path, matches(RegExp('^$_owner/[0-9a-f-]{36}\\.jpg\$')));
    expect(requests.single.url.path,
        '/storage/v1/object/advocate-documents/$path');
    expect(requests.single.headers['x-upsert'], 'false');
    expect(requests.single.headers['content-type'],
        startsWith('multipart/form-data'));
    expect(latin1.decode(requests.single.bodyBytes),
        contains('content-type: image/jpeg'));
  });

  test(
      'signed URL uses private bucket 60 second expiry and rejects external paths',
      () async {
    reply = {
      'signedURL': '/object/sign/advocate-documents/$_path?token=synthetic'
    };
    final url = await datasource.getSignedUrl(_path);
    expect(Uri.parse(url).host, '127.0.0.1');
    expect(requests.single.url.path,
        '/storage/v1/object/sign/advocate-documents/$_path');
    expect(jsonDecode(requests.single.body), {'expiresIn': 60});
    requests.clear();
    for (final invalid in [
      '../private.pdf',
      'https://other.invalid/object',
      '$_owner/../../object.pdf'
    ]) {
      await expectLater(datasource.getSignedUrl(invalid),
          throwsA(isA<ValidationException>()));
    }
    expect(requests, isEmpty);
  });

  test('failed document metadata write removes the just-uploaded object',
      () async {
    handler = (request) async {
      if (request.method == 'POST' &&
          request.url.path.startsWith('/storage/')) {
        return response({'Key': 'synthetic-upload'});
      }
      if (request.method == 'DELETE') return response([]);
      return response({'code': '42501', 'message': 'Denied'}, 403);
    };
    await expectLater(
        datasource.uploadDocument(
            expertId: _expert,
            title: 'Synthetic certificate',
            kind: 'certificate',
            bytes: Uint8List.fromList(utf8.encode('%PDF-synthetic')),
            contentType: 'application/pdf'),
        throwsA(isA<ServerException>()));
    expect(requests, hasLength(3));
    expect(requests.last.method, 'DELETE');
    final uploadedPath =
        requests.first.url.path.split('/advocate-documents/').last;
    expect(jsonDecode(requests.last.body), {
      'prefixes': [uploadedPath]
    });
  });

  test('uncertain metadata response never deletes a potentially saved document',
      () async {
    handler = (request) async {
      if (request.method == 'DELETE') return response([]);
      if (request.url.path.startsWith('/storage/')) {
        return response({'Key': 'synthetic-upload'});
      }
      throw TimeoutException('Synthetic lost insert response');
    };
    await expectLater(
        datasource.uploadDocument(
            expertId: _expert,
            title: 'Synthetic certificate',
            kind: 'certificate',
            bytes: Uint8List.fromList(utf8.encode('%PDF-synthetic')),
            contentType: 'application/pdf'),
        throwsA(isA<TimeoutException>()));
    expect(requests, hasLength(2));
    expect(requests.map((request) => request.method), ['POST', 'POST']);
  });

  test('document deletion uses server-returned path instead of caller path',
      () async {
    handler = (request) async =>
        response(request.url.path.startsWith('/rest/') ? document() : []);
    await datasource.deleteDocument(const AdvocateDocument(
        id: _object,
        title: 'Synthetic certificate',
        kind: 'certificate',
        objectPath: 'other/file.pdf'));
    expect(requests, hasLength(2));
    expect(jsonDecode(requests.last.body), {
      'prefixes': [_path]
    });
  });

  test('document metadata edit cannot move object or ownership', () async {
    reply = {...document(), 'title': 'Updated', 'is_public': true};
    final result = await datasource.updateDocument(const AdvocateDocument(
        id: _object,
        title: ' Updated ',
        kind: 'certificate',
        objectPath: 'other/file.pdf',
        isPublic: true));
    expect(result.title, 'Updated');
    expect(result.objectPath, _path);
    expect(requests.single.method, 'PATCH');
    expect(jsonDecode(requests.single.body), {
      'title': 'Updated',
      'kind': 'certificate',
      'is_public': true,
    });
  });

  test('consultation request uses server-derived price owner and status',
      () async {
    reply = requestRow();
    final result = await datasource.sendRequest(
        expertId: _expert, serviceId: _service, message: ' Synthetic request ');
    expect(result.status, 'pending');
    expect(result.priceUzs, 123000);
    expect(requests.single.url.path, '/rest/v1/rpc/send_advocate_request');
    expect(jsonDecode(requests.single.body), {
      'p_expert_id': _expert,
      'p_message': 'Synthetic request',
      'p_service_id': _service,
      'p_kind': 'consultation',
    });
  });

  test('request inbox, state transition and messages use participant endpoints',
      () async {
    reply = [requestRow()];
    expect((await datasource.getRequests()).single.id, _object);
    expect(requests.single.url.path, '/rest/v1/advocate_consultation_requests');
    reply = {...requestRow(), 'status': 'accepted'};
    expect((await datasource.updateRequestStatus(_object, 'accepted')).status,
        'accepted');
    expect(jsonDecode(requests.last.body),
        {'p_request_id': _object, 'p_status': 'accepted'});
    final message = {
      'id': _service,
      'request_id': _object,
      'sender_id': _owner,
      'body': 'Synthetic reply',
      'created_at': '2026-09-22T00:00:00Z',
    };
    reply = message;
    expect((await datasource.sendMessage(_object, 'Synthetic reply')).body,
        'Synthetic reply');
    expect(jsonDecode(requests.last.body),
        {'p_request_id': _object, 'p_body': 'Synthetic reply'});
    reply = [message];
    expect((await datasource.getMessages(_object)).single.senderId, _owner);
    expect(requests.last.url.queryParameters['request_id'], 'eq.$_object');
  });

  test(
      'single request refresh returns current server status under participant RLS',
      () async {
    reply = {...requestRow(), 'status': 'accepted'};
    final result = await datasource.getRequest(_object);
    expect(result.id, _object);
    expect(result.status, 'accepted');
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/rest/v1/advocate_consultation_requests');
    expect(requests.single.url.queryParameters['id'], 'eq.$_object');
    expect(
        requests.single.headers['accept'], 'application/vnd.pgrst.object+json');
  });

  test('missing denied or mismatched request refresh cannot report success',
      () async {
    for (final scenario in [
      (406, {'code': 'PGRST116', 'message': 'No rows'}, FailureCode.notFound),
      (
        403,
        {'code': '42501', 'message': 'Private synthetic detail'},
        FailureCode.forbidden
      ),
      (200, {...requestRow(), 'id': _service}, FailureCode.server),
    ]) {
      status = scenario.$1;
      reply = scenario.$2;
      final result = await repository.getRequest(_object);
      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure.code, (_) => null), scenario.$3);
    }
  });

  test('review writes only completed consultation reference rating and comment',
      () async {
    reply = {
      'id': _object,
      'rating': 4,
      'comment': 'Synthetic feedback',
      'created_at': '2026-09-22T00:00:00Z'
    };
    expect(
        (await datasource.saveReview(
                consultationId: _object,
                rating: 4,
                comment: 'Synthetic feedback'))
            .rating,
        4);
    expect(requests.single.url.path, '/rest/v1/rpc/save_advocate_review');
    expect(jsonDecode(requests.single.body), {
      'p_consultation_id': _object,
      'p_rating': 4,
      'p_comment': 'Synthetic feedback',
    });
  });
}
