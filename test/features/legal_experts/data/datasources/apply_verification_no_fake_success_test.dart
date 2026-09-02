// LEXHUB — `applyForVerification` SOXTA MUVAFFAQIYAT QAYTARMAYDI.
//
// NUQSON (o'lchangan 2026-08-30, `legal_experts_remote_datasource.dart:215`):
//     if (result is Map<String, dynamic>) { return result; }
//     return {'success': true, 'message': 'Ariza muvaffaqiyatli topshirildi.'};
// Ya'ni RPC KUTILMAGAN shakl qaytarsa (null, matn, massiv) klient O'ZI
// "muvaffaqiyatli topshirildi" deb TO'QIB chiqaradi. Foydalanuvchi ariza
// topshirilgan deb o'ylaydi, `expert_id` va `status` esa YO'Q.
//
// SERVER SHARTNOMASI: `public.apply_for_expert_verification(...)` `RETURNS
// JSONB` va HAR DOIM `success/expert_id/status/message` kalitlari bo'lgan
// OBYEKT qaytaradi
// (`20260829130000_expert_moderation_guard_fix_and_apply_cooldown.sql:271`).
// Ya'ni Map BO'LMAGAN javob — shartnoma BUZILGANI (eski funksiya versiyasi,
// `void` qaytaruvchi shox yoki proksi javobi). Bu holatda haqiqat NOMA'LUM:
// qator kiritilgan bo'lishi ham mumkin, yo'q ham. Shu sababli klient
// "muvaffaqiyat" ham, "xato" ham DEMASLIGI kerak — ANIQLANMADI deyishi kerak.
//
// TRANSPORT SOXTA, KOD REAL: haqiqiy `SupabaseClient` + haqiqiy `postgrest`
// ishlatiladi, faqat HTTP qatlami almashtiriladi. Bu live isbot EMAS —
// jonli isbot: `test/integration/real_supabase_expert_verification_flow_test.dart`
// (gated).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const kUserId = '3c36148d-449c-48e0-9f07-6672e97fdfc8';
  const kExpertId = '7f4b1c2a-1111-4d3e-9a8b-2c5d6e7f8a90';

  late List<http.Request> sent;

  /// RPC javobini boshqaradigan datasource quradi.
  ///
  /// [rpcBody] — `POST /rest/v1/rpc/apply_for_expert_verification` uchun XOM
  /// javob tanasi (JSON matn sifatida). Aynan shu joyda shakl buziladi.
  Future<LegalExpertsRemoteDataSourceImpl> buildDataSource(
    String rpcBody, {
    int status = 200,
  }) async {
    sent = <http.Request>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'sb_publishable_test_key',
      // Avtomatik yangilash timer'i test oxirida tarmoqqa chiqmasligi uchun.
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: _FakePostgrest((request) {
        sent.add(request);
        return http.Response(
          rpcBody,
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    // SESSIYA: `applyForVerification` `currentUser == null` bo'lsa RPC'ga
    // yetib bormaydi. `recoverSession` JWT bo'lmagan token bilan tarmoqqa
    // CHIQMAYDI (`Session.expiresAt` null -> `isExpired` false).
    await client.auth.recoverSession(jsonEncode({
      'access_token': 'test-access-token',
      'token_type': 'bearer',
      'refresh_token': 'test-refresh-token',
      'user': {
        'id': kUserId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-08-01T00:00:00.000Z',
      },
    }));

    return LegalExpertsRemoteDataSourceImpl(supabaseClient: client);
  }

  Future<Map<String, dynamic>> apply(
    LegalExpertsRemoteDataSourceImpl ds,
  ) =>
      ds.applyForVerification(
        specialization: 'Mehnat huquqi',
        experienceYears: 5,
        licenseNumber: 'ADV-123',
      );

  test('SHARTNOMA BAJARILGANDA: server javobi AYNAN qaytadi', () async {
    // NON-VACUITY: happy path ishlashi isbotlanmasa, quyidagi testlar
    // "hamma narsani rad etadi" degan buzuq implementatsiyada ham yashil
    // bo'lardi.
    final ds = await buildDataSource(jsonEncode({
      'success': true,
      'expert_id': kExpertId,
      'status': 'pending_verification',
      'message': 'Ariza muvaffaqiyatli topshirildi.',
    }));

    final result = await apply(ds);

    expect(sent, isNotEmpty, reason: 'RPC HTTP so\'rovi yuborilmagan');
    expect(sent.single.url.path, contains('apply_for_expert_verification'));
    expect(result['success'], isTrue);
    expect(result['expert_id'], kExpertId,
        reason: '`expert_id` YO\'QOLSA UI ariza holatini kuzatib bo\'lmaydi');
    expect(result['status'], 'pending_verification');
  });

  group('SHARTNOMA BUZILGANDA: soxta muvaffaqiyat TO\'QILMAYDI', () {
    // Har bir holat — RPC dan kelishi MUMKIN bo'lgan Map BO'LMAGAN javob.
    final buzuqJavoblar = <String, String>{
      'null (funksiya hech narsa qaytarmadi)': 'null',
      'matn (eski `RETURNS TEXT` versiyasi)': '"Ariza qabul qilindi"',
      'massiv (`SETOF` shox)': '[{"success":true}]',
      'raqam': '42',
      'boolean': 'true',
    };

    for (final entry in buzuqJavoblar.entries) {
      test(entry.key, () async {
        final ds = await buildDataSource(entry.value);

        await expectLater(
          apply(ds),
          throwsA(isA<ServerException>()),
          reason: 'KUTILMAGAN javob "muvaffaqiyat" deb TO\'QILDI: '
              '${entry.value}',
        );
      });
    }

    test('xato matni MUVAFFAQIYAT DA\'VO QILMAYDI', () async {
      final ds = await buildDataSource('null');

      try {
        await apply(ds);
        fail('ServerException kutilgan edi');
      } on ServerException catch (e) {
        // Matn foydalanuvchiga ko'rinadi. "topshirildi"/"muvaffaqiyat"
        // so'zlari QAT'IY taqiqlangan: ariza holati NOMA'LUM.
        final matn = e.message.toLowerCase();
        expect(matn, isNot(contains('muvaffaqiyat')), reason: e.message);
        expect(matn, isNot(contains('topshirildi')), reason: e.message);
        expect(e.message, isNotEmpty);
        // `details` da XOM javob YO'Q (PII/legal content logga tushmasin) —
        // faqat TUR nomi.
        expect(e.details.toString(), isNot(contains('Ariza qabul qilindi')));
      }
    });
  });
}

/// PostgREST'ni imitatsiya qiladi.
///
/// NIMA UCHUN `MockClient` EMAS: postgrest 2.9.1 `_parseResponse`
/// `response.request!.method` ni o'qiydi, `http/testing.dart` esa javobga
/// `request` ni ULAMAYDI — natijada har bir so'rov `Null check operator used
/// on a null value` bilan yiqilardi va test harness defekti production
/// xatosi kabi ko'rinardi (izoh manbasi:
/// `test/features/community_forum/data/datasources/community_forum_read_path_test.dart`).
class _FakePostgrest extends http.BaseClient {
  _FakePostgrest(this.handler);

  final http.Response Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final replay = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..body = body;
    final response = handler(replay);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
