// LEXHUB — LEGAL AI PROXY LIVE VERIFICATION (Task G)
//
// Bu test `supabase/functions/legal-ai` HAQIQATAN DEPLOY QILINGANDAN keyin
// ishga tushiriladi:
//
//   flutter test test/integration/verify_legal_ai_proxy_live_test.dart \
//     --dart-define-from-file=env/prod.json \
//     --dart-define=LEGAL_AI_PROXY_URL=https://<ref>.functions.supabase.co/legal-ai \
//     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
//
// NIMANI ISBOTLAYDI (real runtime, real production Edge Function):
//   1. GET -> 405 `method_not_allowed`.
//   2. Bearer YO'Q -> 401 `missing_authorization`.
//      (1 va 2 uchun O'LCHANGAN: platformaning `verify_jwt` gateway'i
//      so'rovni to'smaydi, javob BIZNING handler'dan keladi.)
//   3. publishable/anon kalit Bearer sifatida -> 401
//      `invalid_or_anonymous_token`. BU ENG MUHIM NEGATIVE STSENARIY:
//      platformaning `verify_jwt` tekshiruvi anon kalitni HAQIQIY deb
//      hisoblaydi, ya'ni u YETARLI EMAS. Faqat `GET /auth/v1/user`
//      haqiqiy foydalanuvchi sessiyasini ajratadi.
//   4. Sessiyasi bor foydalanuvchi -> HTTP 200, `source == 'llm'`, va
//      QAYTGAN HAR BIR modda raqami BIZ YUBORGAN chunk'lar ichida bo'ladi
//      (gallyutsinatsiya server tomonda tushib qoladi).
//   5. Javobda foydalanuvchining ASL PII'si (telefon/ism) YO'Q.
//
// NIMANI ISBOTLAMAYDI (ataylab):
//   * Rate limit (10/soat). Live'da uni sinash foydalanuvchining o'z
//     kvotasini bir soatga bloklaydi; u lokal runtime'da allaqachon
//     isbotlangan (429 `rate_limited`).
//
// DIQQAT: bu test PRODUCTION'ga 1 ta probe auth user yaratadi va 1 ta
// REAL Gemini chaqiruvi sarflaydi. Shu sababli `LEXHUB_LIVE_WRITE_TESTS`
// gate'i bor.
//
// HECH QANDAY CATCH-ALL YO'Q: kutilmagan status = FAIL, PASS emas.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/core/network/legal_ai_proxy_service.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';

void main() {
  if (!liveSuiteEnabled('verify_legal_ai_proxy_live')) return;

  // PROXY URL BERILMAGAN: jimgina yashil bo'lmaydi — OSHKORA skip sababi
  // bilan (`live_gate.dart` bilan bir xil yondashuv).
  if (!SupabaseConfig.hasLegalAiProxy) {
    test('verify_legal_ai_proxy_live — LEGAL_AI_PROXY_URL YO\'Q', () {},
        skip: 'BLOCKED: --dart-define=LEGAL_AI_PROXY_URL=... berilmagan. '
            'Funksiya deploy qilinmagan bo\'lsa avval: '
            'supabase functions deploy legal-ai');
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  late String url;
  late String anonKey;
  late String proxyUrl;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    url = SupabaseConfig.url;
    anonKey = SupabaseConfig.anonKey;
    proxyUrl = SupabaseConfig.legalAiProxyUrl;
    await Supabase.initialize(
      url: url,
      // ignore: deprecated_member_use
      anonKey: anonKey,
    );
    stdout.writeln('PROXY host=${Uri.parse(proxyUrl).host}');
  });

  String redact(String id) => id.length > 12
      ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}'
      : id;

  // Test client'lar uchun implicit oqim — PKCE storage talab qilmaydi.
  // Sabab `verify_mvp_blockers_live_test.dart`da batafsil yozilgan.
  const testAuthOptions = AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
  );

  Dio rawDio() => Dio(BaseOptions(
        validateStatus: (_) => true,
        receiveTimeout: const Duration(seconds: 40),
        sendTimeout: const Duration(seconds: 20),
      ));

  /// Server javobidan `error.code`ni oladi. Kod yo'q bo'lsa `null` —
  /// test o'zi FAIL beradi, biz uni "bor" deb ko'rsatmaymiz.
  String? errorCodeOf(dynamic data) {
    if (data is Map && data['error'] is Map) {
      final code = (data['error'] as Map)['code'];
      return code is String ? code : null;
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════
  // 1-3. NEGATIVE STSENARIYLAR — hech qanday sessiya sarflanmaydi
  // ══════════════════════════════════════════════════════════════════════

  test('LIVE: GET -> 405 (faqat POST qabul qiladi)', () async {
    final res = await rawDio().get<dynamic>(
      proxyUrl,
      options: Options(headers: {'apikey': anonKey}),
    );
    // O'LCHANGAN (2026-08-25, deploy'dan keyingi live probe): platformaning
    // `verify_jwt` gateway'i so'rovni TO'SMAYDI — javob bizning handler'dan
    // keladi. Shuning uchun kutilgan qiymat ANIQ: 405 `method_not_allowed`.
    // Agar kelajakda `config.toml`da `verify_jwt = true` yoqilsa, gateway
    // 401 qaytaradi va bu assertion YIQILADI — bu TO'G'RI signal: negative
    // yo'l shakli o'zgargani qayta tekshirilishi kerak.
    expect(res.statusCode, 405,
        reason: 'GET uchun 405 kutilgan, kelgani: ${res.statusCode} '
            '(${res.data})');
    stdout.writeln('EVIDENCE 1 — GET  -> ${res.statusCode} '
        'code=${errorCodeOf(res.data)}');
  });

  test('LIVE: Authorization YO\'Q -> 401 missing_authorization', () async {
    final res = await rawDio().post<dynamic>(
      proxyUrl,
      data: {'query_text': 'test'},
      options: Options(headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
      }),
    );
    expect(res.statusCode, 401,
        reason: 'Bearer\'siz so\'rov uchun 401 kutilgan, kelgani: '
            '${res.statusCode} (${res.data})');
    // O'LCHANGAN (2026-08-25): javob HANDLER'dan keldi, gateway'dan emas —
    // shuning uchun kod ANIQ `missing_authorization`. Gateway yoqilsa
    // (`verify_jwt = true`) bu yiqiladi: negative yo'lni qayta o'lchash kerak.
    expect(errorCodeOf(res.data), 'missing_authorization',
        reason: 'Kutilmagan xato kodi: ${res.data}');
    stdout.writeln('EVIDENCE 2 — Bearer yo\'q -> ${res.statusCode} '
        'code=${errorCodeOf(res.data)}');
  });

  test(
      'LIVE: publishable/anon kalit Bearer sifatida -> 401 '
      'invalid_or_anonymous_token', () async {
    // BU ASOSIY XAVFSIZLIK DA\'VOSI: anon kalit platformaning `verify_jwt`
    // tekshiruvidan O'TADI, lekin funksiya uni RAD ETISHI shart — aks holda
    // APK'dan kalitni olgan har qanday shaxs AI kvotasini bepul sarflaydi.
    final res = await rawDio().post<dynamic>(
      proxyUrl,
      data: {'query_text': 'Ish beruvchi maoshni bermayapti'},
      options: Options(headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
      }),
    );
    expect(res.statusCode, 401,
        reason: 'Anon kalit BILAN 401 kutilgan (fail-closed), kelgani: '
            '${res.statusCode} (${res.data}). Agar 200 kelsa — kvota '
            'HIMOYASIZ.');
    expect(errorCodeOf(res.data), 'invalid_or_anonymous_token');
    stdout.writeln('EVIDENCE 3 — anon Bearer -> ${res.statusCode} '
        'code=${errorCodeOf(res.data)}');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 4-5. HAQIQIY FOYDALANUVCHI -> 200, GROUNDED, PII'siz
  // ══════════════════════════════════════════════════════════════════════

  test('LIVE: sessiyasi bor foydalanuvchi -> 200, grounded, PII yo\'q',
      () async {
    // 1) Probe foydalanuvchi. Nomi `%_probe_%@lexhub.uz` shablonida —
    //    `cleanup_live_test_data_test.dart` uni topa oladi.
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'legalai_probe_$ts@lexhub.uz';
    const password = 'Password123!';
    final client = SupabaseClient(url, anonKey, authOptions: testAuthOptions);
    addTearDown(() async => client.dispose());

    final signUp = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': 'LegalAI Probe'},
    );
    var session = signUp.session;
    if (session == null) {
      final signIn = await client.auth
          .signInWithPassword(email: email, password: password);
      session = signIn.session;
    }
    expect(session, isNotNull,
        reason: 'BLOCKED: probe uchun sessiya olinmadi (email confirmation '
            'yoqilgan?). Authenticated stsenariyni tekshirib bo\'lmaydi.');
    stdout.writeln('PROBE user_id=${redact(session!.user.id)} email=$email');

    // 2) ASL matnda PII bor — datasource'dagi Step 3 aynan shuni tozalaydi.
    const phoneDigits = '901234567';
    const surname = 'Karimov';
    const rawQuery =
        'Mening ismim Aziz $surname, telefonim +998$phoneDigits. Ish beruvchi '
        'meni asossiz ishdan bo\'shatdi va 2 oylik ish haqimni bermayapti.';
    final sanitized = PiiAnonymizer.anonymize(rawQuery);
    expect(sanitized, isNot(contains(phoneDigits)),
        reason: 'PiiAnonymizer telefon raqamini olib tashlamadi — serverga '
            'PII ketadi');
    stdout.writeln('SANITIZED = $sanitized');

    // 3) RAG konteksti. Bo'sh bo'lsa grounding tekshiruvi MA\'NOSIZ bo'ladi,
    //    shuning uchun bo'shligi = FAIL.
    final chunks =
        LegalKnowledgeRetriever.retrieveRelevantChunks(sanitized, maxResults: 3);
    expect(chunks, isNotEmpty,
        reason: 'Mahalliy knowledge base bu so\'rov uchun 0 chunk qaytardi');
    final sentNumbers = chunks.map((LawArticleChunk c) => c.articleNumber).toSet();
    stdout.writeln('YUBORILGAN chunk\'lar: '
        '${chunks.map((c) => '${c.documentName} ${c.articleNumber}').join(' | ')}');

    // 4) Production kodning O'ZI bilan chaqiramiz (raw HTTP emas) — parse,
    //    `user_query` in\'ektsiyasi va `source` mantig'i ham tekshiriladi.
    final service = LegalAiProxyService(supabaseClient: client);
    expect(service.isConfigured, isTrue);
    final response = await service.generateLegalAdvice(
      query: LegalQuery(
        id: 'live_probe_$ts',
        queryText: rawQuery,
        category: 'Mehnat huquqi',
        createdAt: DateTime.now(),
      ),
      sanitizedQuery: sanitized,
      contextChunks: chunks,
    );

    if (response == null) {
      final code = service.lastErrorCode;
      final hint = code == 'ai_not_configured'
          ? ' -> Funksiya deploy qilingan, lekin kalit yo\'q: '
              'supabase secrets set GEMINI_API_KEY=...'
          : code == 'ai_key_rejected'
              ? ' -> Kalit noto\'g\'ri (Google API_KEY_INVALID)'
              : code == 'ai_model_unavailable'
                  ? ' -> LEGAL_AI_MODEL nomi mavjud emas'
                  : '';
      fail('NOT VERIFIED: proxy 200 qaytarmadi. lastErrorCode=$code$hint');
    }

    // 5) HALOLLIK: bu javob MODEL javobi deb belgilanishi kerak.
    expect(response.source, LegalResponse.sourceLlm);
    expect(response.isAiGenerated, isTrue);
    expect(response.relatableSummary.trim(), isNotEmpty);
    expect(response.actionableSteps, isNotEmpty,
        reason: 'Model amaliy qadamlarsiz javob qaytardi');

    // 6) `user_query` — server qaytarmaydi, client ASL matnni qo'yadi.
    //    Aks holda UI'da savol o'rniga AI xulosasi ko'rinardi.
    expect(response.userQuery, rawQuery);

    // 7) ANTI-GALLYUTSINATSIYA: qaytgan HAR BIR modda raqami BIZ YUBORGAN
    //    chunk'lar ichida bo'lishi shart. Server tomondagi `groundLegalBasis`
    //    aynan shuni kafolatlaydi; bu yerda uni ISHDA tekshiramiz.
    for (final article in response.legalBasis) {
      final digits = RegExp(r'\d+').firstMatch(article.articleNumber)?.group(0);
      expect(digits, isNotNull,
          reason: 'Modda raqamsiz qaytdi: "${article.articleNumber}"');
      expect(sentNumbers, contains(int.parse(digits!)),
          reason: 'GALLYUTSINATSIYA: ${article.lawName} '
              '${article.articleNumber} — bu modda kontekstda YO\'Q edi '
              '(yuborilgan: $sentNumbers)');
    }
    stdout.writeln('EVIDENCE 4 — 200, source=${response.source}, '
        'legal_basis=${response.legalBasis.length}, '
        'moddalar=${response.legalBasis.map((a) => a.articleNumber).join(',')}');

    // 8) Server favqulodda protokol TO'QIMAYDI (uni faqat qurilmadagi
    //    deterministik detektor beradi).
    expect(response.emergencyProtocol, isNull,
        reason: 'Server emergency_protocol qaytardi — u faqat client tomonda '
            'aniqlanishi kerak');

    // 9) PII ECHO GUARD: javobning hech qayerida asl PII bo'lmasligi kerak.
    final haystack = [
      response.relatableSummary,
      ...response.actionableSteps,
      ...response.legalBasis.map((a) => '${a.lawName} ${a.articleText}'),
      response.riskAssessment.summary,
    ].join('\n');
    expect(haystack, isNot(contains(phoneDigits)),
        reason: 'Javobda telefon raqami qaytib keldi');
    expect(haystack, isNot(contains(surname)),
        reason: 'Javobda familiya qaytib keldi');
    stdout.writeln('EVIDENCE 5 — javobda PII yo\'q '
        '(${haystack.length} belgi tekshirildi)');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
