// LEXHUB — ANONIM SAVOL MAXFIYLIGI: LIVE (PRODUCTION) TEKSHIRUVI.
//
// Ishga tushirish (FAQAT ataylab — production'ga tegadi, lekin FAQAT O'QIYDI):
//
//   flutter test test/integration/questions_anonymity_live_test.dart \
//     --dart-define-from-file=env/prod.json \
//     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true --reporter expanded
//
// NIMANI O'LCHAYDI (real production, ANON kalit, SESSIYASIZ — ya'ni
// tizimga kirmagan mehmon huquqi bilan):
//
//   1. `GET /rest/v1/questions?is_anonymous=eq.true&select=user_id` —
//      anonim savol EGASI ko'rinmasligi kerak. Bu ASOSIY assertion.
//   2. `GET /rest/v1/public_questions_view` — view HAMON ishlashi va
//      anonim qatorda `user_id == null`, `author_name == 'Anonim fuqaro'`
//      berishi kerak (REGRESSIYA qo'riqchisi: 1-band tuzatilgani
//      ilovaning o'z feed'ini SINDIRMASLIGI shart).
//   3. `GET /rest/v1/profiles?select=phone` — 42501 (ustun huquqi
//      qulflangan). Bu 1-band bilan BIRGA fosh qilish ZANJIRINI yopadi:
//      `user_id` ko'rinmasa ham, ism/telefonni ochiq o'qish bo'lmasin.
//
// 2026-08-30 DA O'LCHANGAN HOLAT (migration DEPLOY QILINMASDAN OLDIN):
//   1-band YIQILADI — anon `{"is_anonymous":true,"user_id":"9c409345-…"}`
//   qaytardi va shu `user_id` bilan `profiles?select=full_name` HAQIQIY
//   ismni berdi. Ya'ni bu test hozir KUTILGANDEK QIZIL bo'ladi va
//   `20260830080000_questions_anonymity_rls_enforcement.sql` SQL Editor'da
//   ishga tushirilgandan keyin YASHIL bo'lishi kerak.
//
// BU TEST DEPLOYMENT ISBOTI EMAS — DEPLOYMENT NATIJASINI o'lchaydi.
// Qizil bo'lsa: teshik hamon ochiq. Yashil bo'lsa: yopilgan.
//
// HECH QANDAY CATCH-ALL YO'Q: kutilmagan status = FAIL.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/live_gate.dart';

void main() {
  if (!liveSuiteEnabled('questions_anonymity_live')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  late String baseUrl;
  late String anonKey;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    baseUrl = SupabaseConfig.url;
    anonKey = SupabaseConfig.anonKey;
    // Kalit QIYMATI chop etilmaydi — faqat host.
    stdout.writeln('LIVE host=${Uri.parse(baseUrl).host}');
  });

  /// PostgREST GET — SESSIYASIZ (Bearer = anon kalit, ya'ni `auth.uid()`
  /// NULL). `SupabaseClient` ATAYLAB ishlatilmaydi: u sessiya/keshga
  /// bog'lanadi, bu yerda esa AYNAN mehmon huquqi o'lchanadi.
  Future<(int, String)> get(String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse('$baseUrl/rest/v1/$path'));
      req.headers.set('apikey', anonKey);
      req.headers.set('Authorization', 'Bearer $anonKey');
      final res = await req.close().timeout(const Duration(seconds: 30));
      final body = await res.transform(utf8.decoder).join();
      return (res.statusCode, body);
    } finally {
      client.close(force: true);
    }
  }

  test('ANON anonim savolning `user_id`ini KO\'RMAYDI (xom jadval)', () async {
    final (status, body) =
        await get('questions?select=id,is_anonymous,user_id&is_anonymous=eq.true&limit=5');

    // 200 + bo'sh massiv KUTILGAN natija (RLS filtri).
    // 401/42501 ham QABUL QILINADI: kelgusida ustun/jadval huquqi ham
    // qulflansa, maxfiylik BUNDAN YAXSHIROQ himoyalangan bo'ladi.
    if (status == 401 || status == 403) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['code'], '42501',
          reason: 'Kutilmagan rad etish sababi: $body');
      return;
    }

    expect(status, 200, reason: 'Kutilmagan status: $status $body');
    final rows = jsonDecode(body) as List<dynamic>;
    expect(rows, isEmpty,
        reason: 'MAXFIYLIK TESHIGI: tizimga KIRMAGAN so\'rov anonim '
            'savol(lar)ni qaytardi. Fosh qilish zanjiri: bu `user_id` -> '
            '`profiles?select=full_name` -> HAQIQIY ISM. Tuzatish: '
            'supabase/migrations/20260830080000_questions_anonymity_rls_'
            'enforcement.sql ni SQL Editor\'da ishga tushirish kerak. '
            'Qaytgan qator(lar): $rows');
  });

  test('VIEW hamon ishlaydi va anonimlikni MASKALAYDI (regressiya yo\'q)',
      () async {
    final (status, body) = await get(
        'public_questions_view?select=id,is_anonymous,user_id,author_name&limit=20');

    expect(status, 200, reason: 'View o\'qilmadi: $status $body');
    final rows = (jsonDecode(body) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    // Bo'sh baza HAQIQIY holat bo'lishi mumkin — jim o'tmaslik uchun
    // OSHKORA aytiladi, lekin assertion soxta yashil bermaydi.
    if (rows.isEmpty) {
      stdout.writeln('DIQQAT: view bo\'sh — anonimlik maskasi O\'LCHANMADI '
          '(PARTIALLY VERIFIED).');
      return;
    }

    final anonRows = rows.where((r) => r['is_anonymous'] == true).toList();
    if (anonRows.isEmpty) {
      stdout.writeln('DIQQAT: bazada anonim savol yo\'q — maska '
          'O\'LCHANMADI (PARTIALLY VERIFIED).');
      return;
    }

    for (final r in anonRows) {
      expect(r['user_id'], isNull,
          reason: 'View anonim savolda `user_id` bermasligi kerak: $r');
      expect(r['author_name'], 'Anonim fuqaro',
          reason: 'View anonim muallif nomini maskalashi kerak: $r');
    }
  });

  test('ANON `profiles.phone` ni O\'QIY OLMAYDI (ustun huquqi)', () async {
    final (status, body) = await get('profiles?select=phone&limit=1');

    expect(status, anyOf(401, 403),
        reason: 'PII ochiq qoldi: $status $body');
    final json = jsonDecode(body) as Map<String, dynamic>;
    expect(json['code'], '42501', reason: 'Kutilmagan sabab: $body');
  });

  test('ANON ochiq ustunlarni O\'QIY OLADI (haddan tashqari qulflanmagan)',
      () async {
    // Teskari tomon: tuzatish ilovaning o'z ishini buzmasligi kerak.
    final (status, body) = await get('profiles?select=id,full_name,role&limit=1');
    expect(status, 200, reason: 'Ochiq ustunlar ham yopilib qoldi: $status $body');
    expect(jsonDecode(body), isA<List<dynamic>>());
  });
}
