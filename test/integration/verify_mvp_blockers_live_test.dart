// LEXHUB — MVP BLOCKER LIVE VERIFICATION (P0-07 / P1-05 / P1-06)
//
// Bu test `supabase/migrations/20260828_mvp_blockers_p0_07_p1_05_p1_06.sql`
// SQL Editor'da QO'LLANGANDAN KEYIN ishga tushiriladi:
//
//   flutter test test/integration/verify_mvp_blockers_live_test.dart \
//     --dart-define-from-file=env/prod.json \
//     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
//
// NIMANI ISBOTLAYDI:
//   P0-07  `process_payment_webhook` client'dan (anon VA authenticated)
//          chaqirilganda FAIL-CLOSED bo'ladi (42501 -> HTTP 403).
//          MIGRATION'DAN OLDIN bu chaqiruv `P0001 Payment record not found`
//          qaytargan — ya'ni funksiya TANASIGA kirgan. Endi tanaga
//          YETIB BORMASLIGI kerak.
//   P1-05  `get_expert_available_slots` mavjud bo'lmagan / tasdiqlanmagan
//          advokat uchun 0 QATOR qaytaradi (ilgari 12 to'qima slot +
//          150000 UZS to'qima narx qaytargan).
//   P1-06  `questions` / `answers` DELETE: egasi o'chiradi, BEGONA
//          foydalanuvchi o'chira OLMAYDI (0 qator, kontent joyida),
//          anon esa fail-closed.
//
// DIQQAT: bu test REAL PRODUCTION'ga YOZADI (2 ta probe auth user +
// 2 ta savol). Shu sababli `LEXHUB_LIVE_WRITE_TESTS=true` gate'i bor.
// Test o'z ma'lumotini OXIRIDA o'zi o'chiradi (P1-06 o'chirish testining
// o'zi cleanup vazifasini bajaradi).
//
// HECH QANDAY CATCH-ALL YO'Q: kutilmagan xato = FAIL, PASS emas.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';

void main() {
  if (!liveSuiteEnabled('verify_mvp_blockers_live')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  late String url;
  late String anonKey;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    url = SupabaseConfig.url;
    anonKey = SupabaseConfig.anonKey;
    await Supabase.initialize(
      url: url,
      // ignore: deprecated_member_use
      anonKey: anonKey,
    );
  });

  /// UUID/ID'ni redaktsiya qilib chiqaradi — log'ga to'liq ID yozilmaydi.
  String redact(String id) => id.length > 12
      ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}'
      : id;

  /// TEST-ONLY auth konfiguratsiyasi (production kodga TEGMAYDI).
  ///
  /// ROOT CAUSE: `SupabaseClient(url, anonKey)` — bu `supabase` paketining
  /// XOM konstruktori. `supabase_client_options.dart` da
  /// `AuthClientOptions({authFlowType = AuthFlowType.pkce, pkceAsyncStorage})`
  /// bo'lgani uchun default oqim PKCE, `pkceAsyncStorage` esa null. Natijada
  /// `GoTrueClient(asyncStorage: null, flowType: pkce)` yaratiladi va
  /// `signUp` ichidagi `_generatePKCECodeChallenge()`
  /// `assert(_asyncStorage != null, 'You need to provide asyncStorage to
  /// perform pkce flow.')` da yiqiladi (gotrue 2.27.2, gotrue_client.dart:478).
  ///
  /// Ilova o'zi yiqilmaydi, chunki `Supabase.initialize` (supabase_flutter)
  /// Flutter tomonidagi storage'ni o'zi ulab beradi. Bu FAQAT testdagi
  /// mustaqil client'lar muammosi.
  ///
  /// TUZATISH: email+password signUp/signIn uchun PKCE KERAK EMAS (PKCE
  /// faqat email-redirect / OAuth code exchange uchun). `implicit` oqimda
  /// `_generatePKCECodeChallenge` darhol `null` qaytaradi
  /// (gotrue_client.dart:474) — assert'ga yetib bormaydi va hech qanday
  /// storage adapteri talab qilinmaydi.
  const testAuthOptions = AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
  );

  /// Sessiyasiz (anon) MUSTAQIL client — global sessiyaga tegmaydi.
  SupabaseClient freshAnonClient() =>
      SupabaseClient(url, anonKey, authOptions: testAuthOptions);

  // ══════════════════════════════════════════════════════════════════════
  // P0-07 — process_payment_webhook: CALLER AUTHORIZATION
  // ══════════════════════════════════════════════════════════════════════

  /// `process_payment_webhook`ni berilgan client bilan chaqiradi va
  /// PostgrestException'ni qaytaradi. Xato KELMASA — test yiqiladi, chunki
  /// bu client uchun chaqiruv MUVAFFAQIYATLI bo'lishi MUMKIN EMAS.
  Future<PostgrestException> expectWebhookRejected(
    SupabaseClient client,
    String who,
  ) async {
    try {
      final res = await client.rpc('process_payment_webhook', params: {
        'p_payment_id': '00000000-0000-0000-0000-000000000001',
        'p_provider': 'payme',
        'p_provider_transaction_id': 'p0_07_probe_${DateTime.now().millisecondsSinceEpoch}',
        'p_paid_amount_tiyin': 1,
        'p_status': 'paid',
      });
      fail('P0-07 BUZILGAN: $who uchun chaqiruv XATO BERMADI. '
          'Javob: $res — funksiya EXECUTE huquqi hali ochiq.');
    } on PostgrestException catch (e) {
      stdout.writeln('EVIDENCE P0-07 [$who] code=${e.code} '
          'message="${e.message}"');
      return e;
    }
  }

  /// 42501 = insufficient_privilege -> PostgREST HTTP 403 (fail-closed).
  /// `P0001` (RAISE EXCEPTION tanadan) = migration QO'LLANMAGAN.
  void expectFailClosed(PostgrestException e, String who) {
    expect(e.code, '42501',
        reason: 'P0-07: $who uchun kutilgan 42501 (insufficient_privilege / '
            'HTTP 403). Olingan code=${e.code}, message="${e.message}". '
            'Agar code=P0001 bo\'lsa — funksiya TANASI ishlagan, ya\'ni '
            '20260828_mvp_blockers_p0_07_p1_05_p1_06.sql QO\'LLANMAGAN.');
    expect(e.message.toLowerCase(), contains('permission denied'),
        reason: 'P0-07: $who uchun xato matni "permission denied" bo\'lishi '
            'kerak. Olingan: "${e.message}"');
  }

  test('P0-07 LIVE: anon client -> process_payment_webhook FAIL-CLOSED (403)',
      () async {
    final anon = freshAnonClient();
    final e = await expectWebhookRejected(anon, 'anon');
    expectFailClosed(e, 'anon');
    await anon.dispose();
  });

  /// Yangi probe foydalanuvchi yaratadi va SESSIYASI bor mustaqil client
  /// qaytaradi. Sessiya olinmasa test yiqiladi (jimgina PASS bo'lmaydi).
  Future<({SupabaseClient client, String userId, String email})>
      signUpProbe(String tag) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'mvp_${tag}_probe_$ts@lexhub.uz';
    const password = 'Password123!';
    final client = SupabaseClient(url, anonKey, authOptions: testAuthOptions);
    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': 'MVP Probe $tag'},
    );
    var session = res.session;
    if (session == null) {
      // Email confirmation yoqilgan bo'lishi mumkin — signIn bilan urinamiz.
      final signIn = await client.auth
          .signInWithPassword(email: email, password: password);
      session = signIn.session;
    }
    expect(session, isNotNull,
        reason: 'BLOCKED: probe foydalanuvchi uchun sessiya olinmadi '
            '(email confirmation yoqilgan?). Authenticated stsenariylarni '
            'tekshirib bo\'lmaydi.');
    final userId = session!.user.id;
    stdout.writeln('PROBE[$tag] user_id=${redact(userId)}');
    return (client: client, userId: userId, email: email);
  }

  test(
      'P0-07 LIVE: authenticated client -> process_payment_webhook FAIL-CLOSED (403)',
      () async {
    final probe = await signUpProbe('p007');
    final e = await expectWebhookRejected(probe.client, 'authenticated');
    expectFailClosed(e, 'authenticated');
    await probe.client.dispose();
  });

  // ══════════════════════════════════════════════════════════════════════
  // P1-05 — get_expert_available_slots: TO'QIMA SLOT/NARX YO'Q
  // ══════════════════════════════════════════════════════════════════════

  test('P1-05 LIVE: mavjud bo\'lmagan advokat -> 0 slot, 150000 narx YO\'Q',
      () async {
    final client = Supabase.instance.client;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateStr = '${tomorrow.year.toString().padLeft(4, '0')}-'
        '${tomorrow.month.toString().padLeft(2, '0')}-'
        '${tomorrow.day.toString().padLeft(2, '0')}';

    final res = await client.rpc('get_expert_available_slots', params: {
      'p_expert_id': '00000000-0000-0000-0000-000000000001',
      'p_date': dateStr,
    });
    final rows = (res as List<dynamic>);
    stdout.writeln('EVIDENCE P1-05 — mavjud emas advokat: ${rows.length} slot');

    expect(rows, isEmpty,
        reason: 'P1-05 BUZILGAN: mavjud bo\'lmagan advokat uchun '
            '${rows.length} slot qaytdi. Migration qo\'llanmagan bo\'lsa '
            '12 slot + 150000 to\'qima narx qaytadi.');
  });

  test('P1-05 LIVE: haqiqiy advokatning narxi expert_profiles bilan bir xil',
      () async {
    final client = Supabase.instance.client;
    final experts = await client
        .from('expert_profiles')
        .select('id, consultation_fee, verified_at')
        .not('verified_at', 'is', null)
        .limit(1);
    final list = experts as List<dynamic>;
    if (list.isEmpty) {
      // BO'SH = tekshiriladigan holat YO'Q. Bu PASS emas, oshkora SKIP.
      markTestSkipped('BLOCKED: bazada tasdiqlangan expert_profiles yo\'q — '
          'haqiqiy narx stsenariysini tekshirib bo\'lmaydi.');
      return;
    }
    final expert = Map<String, dynamic>.from(list.first as Map);
    final expectedFee = (expert['consultation_fee'] as num).toDouble();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateStr = '${tomorrow.year.toString().padLeft(4, '0')}-'
        '${tomorrow.month.toString().padLeft(2, '0')}-'
        '${tomorrow.day.toString().padLeft(2, '0')}';

    final res = await client.rpc('get_expert_available_slots', params: {
      'p_expert_id': expert['id'],
      'p_date': dateStr,
    });
    final rows = (res as List<dynamic>);
    stdout.writeln('EVIDENCE P1-05 — expert=${redact(expert['id'] as String)} '
        'fee=$expectedFee slots=${rows.length}');

    if (expectedFee == 0) {
      // Narx 0 bo'lsa migration `RETURN` qiladi (0 slot) — TO'QIMA narx yo'q.
      expect(rows, isEmpty,
          reason: 'P1-05: consultation_fee = 0 bo\'lgan advokat uchun slot '
              'ko\'rsatilmasligi kerak (soxta narx bilan bandlik qilinmaydi).');
      return;
    }
    for (final r in rows) {
      final row = Map<String, dynamic>.from(r as Map);
      final fee = (row['price_amount_uzs'] as num).toDouble();
      expect(fee, expectedFee,
          reason: 'P1-05 BUZILGAN: slot narxi ($fee) expert_profiles.'
              'consultation_fee ($expectedFee) bilan mos emas — narx '
              'TO\'QILGAN.');
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  // P1-06 — owner DELETE policy
  // ══════════════════════════════════════════════════════════════════════

  test('P1-06 LIVE: egasi o\'chiradi / begona o\'chira olmaydi / anon fail-closed',
      () async {
    final client = Supabase.instance.client;

    // Haqiqiy kategoriya ID — `category_id` NOT NULL va uuid.
    final cats = await client.from(kCategoriesTable).select('id').limit(1);
    final catList = cats as List<dynamic>;
    expect(catList, isNotEmpty,
        reason: 'BLOCKED: public.$kCategoriesTable bo\'sh — savol yaratib '
            'bo\'lmaydi.');
    final categoryId = (catList.first as Map)['id'] as String;

    final userA = await signUpProbe('p106a');
    final userB = await signUpProbe('p106b');

    // ── A va B har biri O'Z savolini yaratadi ──────────────────────────
    Future<String> createQuestion(
        SupabaseClient c, String uid, String tag) async {
      final row = await c
          .from('questions')
          .insert(buildQuestionInsertPayload(
            userId: uid,
            title: 'P1-06 delete probe $tag '
                '${DateTime.now().millisecondsSinceEpoch}',
            description: 'P1-06 owner DELETE policy live tekshiruvi ($tag).',
            aiSummary: '',
            isAnonymous: false,
            categoryId: categoryId,
          ))
          .select('id')
          .single();
      final id = row['id'] as String;
      stdout.writeln('P1-06 savol[$tag] id=${redact(id)}');
      return id;
    }

    final qA = await createQuestion(userA.client, userA.userId, 'A');
    final qB = await createQuestion(userB.client, userB.userId, 'B');

    // ── 1. BEGONA (B) A'ning savolini o'chira OLMAYDI ──────────────────
    final crossDelete =
        await userB.client.from('questions').delete().eq('id', qA).select('id');
    stdout.writeln('EVIDENCE P1-06 [begona DELETE] '
        'o\'chirilgan qator = ${(crossDelete as List).length}');
    expect((crossDelete as List).length, 0,
        reason: 'P1-06 BUZILGAN: B foydalanuvchi A\'ning savolini o\'chirdi.');

    // A'ning savoli JOYIDA turgani ISBOTI (0 qator = jim rad, deletion emas).
    final stillThere =
        await userA.client.from('questions').select('id').eq('id', qA);
    expect((stillThere as List).length, 1,
        reason: 'P1-06 BUZILGAN: begona DELETE\'dan keyin A\'ning savoli '
            'yo\'qoldi.');

    // ── 2. ANON DELETE fail-closed ────────────────────────────────────
    final anon = freshAnonClient();
    var anonBlocked = false;
    try {
      final r = await anon.from('questions').delete().eq('id', qA).select('id');
      expect((r as List).length, 0,
          reason: 'P1-06 BUZILGAN: anon foydalanuvchi savolni o\'chirdi.');
      anonBlocked = true;
      stdout.writeln('EVIDENCE P1-06 [anon DELETE] 0 qator (jim rad)');
    } on PostgrestException catch (e) {
      anonBlocked = true;
      stdout.writeln('EVIDENCE P1-06 [anon DELETE] code=${e.code} '
          'message="${e.message}"');
    }
    expect(anonBlocked, isTrue);
    await anon.dispose();

    // ── 3. EGASI o'chiradi -> MUVAFFAQIYAT ────────────────────────────
    final ownDelete =
        await userA.client.from('questions').delete().eq('id', qA).select('id');
    stdout.writeln('EVIDENCE P1-06 [egasi DELETE] '
        'o\'chirilgan qator = ${(ownDelete as List).length}');
    expect((ownDelete as List).length, 1,
        reason: 'P1-06 BAJARILMADI: egasi o\'z savolini o\'chira olmadi — '
            'DELETE policy qo\'llanmagan (migration SQL Editor\'da '
            'ishlatilmagan?).');

    final gone = await userA.client.from('questions').select('id').eq('id', qA);
    expect((gone as List).length, 0);

    // ── CLEANUP: B'ning savolini ham o'chiramiz (o'z egasi bilan) ──────
    await userB.client.from('questions').delete().eq('id', qB);

    await userA.client.dispose();
    await userB.client.dispose();
  });

}
