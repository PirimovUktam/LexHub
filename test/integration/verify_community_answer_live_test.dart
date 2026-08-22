import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lexhub/features/community_forum/data/datasources/answer_schema.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
/// COMMUNITY ANSWER FLOW — REAL SUPABASE RUNTIME VERIFICATION
///
/// Nima uchun bu fayl bor: `answer_schema_test.dart` pure Dart — u payload
/// SHAKLINI qo'riqlaydi, lekin javob live cloud'da SAQLANISHINI isbotlamaydi.
/// Device'da ko'rilgan xato (`PGRST204 'content' column ... not found`) faqat
/// real PostgREST bilan takrorlanadi/yopiladi.
///
/// Ishga tushirish:
///
///   flutter test test/integration/verify_community_answer_live_test.dart \
///     --dart-define-from-file=env/prod.json \
///     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
///
/// DIQQAT: bu test REAL PRODUCTION'ga YOZADI (1 auth user + 1 savol +
/// 1 javob). Shu sababli `LEXHUB_LIVE_WRITE_TESTS=true` bo'lmaguncha SKIP.
/// Hech qanday catch-all YO'Q: har qanday kutilmagan xato = FAIL.
void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('verify_community_answer_live')) return;

  const liveWrites =
      bool.fromEnvironment('LEXHUB_LIVE_WRITE_TESTS', defaultValue: false);

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  setUpAll(() async {
    if (!liveWrites) return;
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
    );
  });

  /// UUID'ni redaktsiya qilib chiqarish (log'ga to'liq ID yozilmaydi).
  String redact(String id) => id.length > 12
      ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}'
      : id;

  test(
    'LIVE: answers schema -> citizen javob yozadi -> matn o\'qiladi -> RBAC',
    () async {
      final client = Supabase.instance.client;
      final authDs = AuthRemoteDataSourceImpl(supabaseClient: client);
      final communityDs = CommunityForumDataSourceImpl(supabaseClient: client);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'answer_probe_$ts@lexhub.uz';
      const password = 'Password123!';
      const fullName = 'Answer Probe';

      // ── 0. LIVE SCHEMA: `content` YO'Q, `body` BOR ───────────────────────
      // Bu device xatosining ildizini har bir ishga tushirishda qayta
      // isbotlaydi (taxmin emas — PostgREST javobi).
      Object? contentProbeError;
      try {
        await client.from(kAnswersTable).select('content').limit(1);
      } catch (e) {
        contentProbeError = e;
      }
      stdout.writeln('EVIDENCE 0 — select(content): '
          '${contentProbeError ?? 'HTTP 200 (ustun BOR)'}');
      expect(contentProbeError, isNotNull,
          reason: 'agar `answers.content` PAYDO bo\'lgan bo\'lsa (migration '
              'qo\'llangan), fix strategiyasi qayta ko\'rilishi kerak');
      expect('$contentProbeError', contains('42703'),
          reason: 'kutilgan: column answers.content does not exist');

      // `body` esa REAL mavjud — yozuv yo'li shu ustunga boradi.
      final bodyProbe =
          await client.from(kAnswersTable).select(kAnswerTextColumn).limit(1);
      stdout.writeln('EVIDENCE 0 — select($kAnswerTextColumn): HTTP 200 '
          '(${(bodyProbe as List).length} qator)');

      // ── 1. REAL SIGNUP (citizen) ─────────────────────────────────────────
      final user = await authDs.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      stdout.writeln('EVIDENCE 1 — auth.users: id=${redact(user.id)}');

      final profile = await client
          .from('profiles')
          .select('id, role, is_verified')
          .eq('id', user.id)
          .maybeSingle();
      expect(profile, isNotNull,
          reason: 'profil yo\'q bo\'lsa `answers.user_id` FK 23503 beradi');
      stdout.writeln('EVIDENCE 1 — profiles.role=${profile!['role']} '
          'is_verified=${profile['is_verified']}');
      expect(profile['role'], 'citizen', reason: 'yangi user citizen bo\'ladi');
      expect(canAnswerAsExpert(
            role: profile['role'] as String?,
            isVerified: profile['is_verified'] as bool? ?? false,
          ), isFalse,
          reason: 'citizen ekspert javobi yozishga HAQLI EMAS');

      // ── 2. Javob berish uchun savol ──────────────────────────────────────
      final post = await communityDs.createQuestion(
        title: 'Answer probe savoli $ts',
        rawQuestion: 'Ishdan bo\'shatilganda qanday kompensatsiya olaman?',
        category: 'Mehnat huquqi',
        isAnonymous: false,
        authorName: fullName,
      );
      stdout.writeln('EVIDENCE 2 — savol: id=${redact(post.id)}');

      // ── 3. ODDIY JAVOB — device'da yiqilgan aynan shu yo'l ───────────────
      const answerText = 'Mehnat kodeksining 173-moddasiga qarang.';
      final answer = await communityDs.addAnswer(
        postId: post.id,
        content: answerText,
        authorName: fullName,
        isExpert: false,
        authorRole: 'Jamoat a\'zosi',
      );
      stdout.writeln('EVIDENCE 3 — javob yaratildi: id=${redact(answer.id)}');
      expect(answer.id, isNotEmpty);
      expect(answer.content, answerText,
          reason: 'INSERT qaytargan qatordan matn o\'qilishi shart '
              '(eski bug: `json[\'content\']` -> har doim \'\')');
      expect(answer.isExpert, isFalse);

      // ── 4. REAL SQL TASDIQ: qator DB'da, matn `body` ustunida ────────────
      final row = await client
          .from(kAnswersTable)
          .select('id, question_id, user_id, $kAnswerTextColumn, '
              'is_expert_answer, is_accepted, upvotes_count, created_at')
          .eq('id', answer.id)
          .maybeSingle();
      expect(row, isNotNull, reason: 'javob DB\'da YO\'Q — INSERT o\'tmagan');
      stdout.writeln('EVIDENCE 4 — answers qatori: '
          'id=${redact('${row!['id']}')} '
          'question_id=${redact('${row['question_id']}')} '
          'user_id=${redact('${row['user_id']}')} '
          '$kAnswerTextColumn="${row[kAnswerTextColumn]}" '
          'is_expert_answer=${row['is_expert_answer']} '
          'created_at=${row['created_at']}');
      expect(row['question_id'], post.id);
      expect(row['user_id'], user.id);
      expect(row[kAnswerTextColumn], answerText);
      expect(row['is_expert_answer'], isFalse);
      expect(row['created_at'], isNotNull);

      // ── 5. READ FLOW: javob savol tafsilotlarida KO'RINADI ───────────────
      // P0 EDI (2026-08-22 live run): bu yerda `post_labor_1` (mock) qaytdi.
      // Sabab: `qMap['answers']`ga qurilgan `QuestionAnswerModel` obyektlari
      // solinardi, `fromJson` esa ularni `Map` deb cast qilardi -> TypeError
      // -> tashqi `catch` -> `_fallbackPosts.first`. Endi fallback YO'Q.
      final fetched = await communityDs.getPostById(post.id);
      stdout.writeln('EVIDENCE 5 — getPostById: id=${redact(fetched.id)} '
          'javoblar=${fetched.answers.length} '
          'kategoriya="${fetched.category}"');
      expect(fetched.id, post.id,
          reason: 'fallback mock post qaytarilgan (real savol emas)');
      expect(fetched.id, isNot('post_labor_1'),
          reason: 'P0 REGRESSIYA: mock post qaytdi');
      expect(fetched.answers, isNotEmpty, reason: 'javob READ yo\'lida yo\'q');
      final readBack =
          fetched.answers.firstWhere((a) => a.id == answer.id);
      expect(readBack.content, answerText,
          reason: 'UI\'da javob matni BO\'SH ko\'rinadi (READ regressiyasi)');
      stdout.writeln('EVIDENCE 5 — read-back javob: id=${redact(readBack.id)} '
          'matn="${readBack.content}" ekspert=${readBack.isExpert}');

      // ── 5b. FEED: javobi BOR savol butun feed'ni mock'ka aylantirmaydi ───
      // Eski kodda AYNAN shu holat (javobi bor savol) `getPosts` ni ham
      // TypeError'ga olib borardi -> butun ro'yxat mock bo'lib qolardi.
      final feed = await communityDs.getPosts();
      final inFeed = feed.where((p) => p.id == post.id).toList();
      stdout.writeln('EVIDENCE 5b — getPosts: ${feed.length} savol, '
          'shu savol feed\'da=${inFeed.length}, '
          'mock post_labor_1 bormi='
          '${feed.any((p) => p.id == 'post_labor_1')}');
      expect(feed.any((p) => p.id == 'post_labor_1'), isFalse,
          reason: 'P0 REGRESSIYA: feed mock ma\'lumot qaytardi');
      expect(inFeed, hasLength(1),
          reason: 'real savol feed\'da ko\'rinmadi');
      expect(inFeed.single.answers.map((a) => a.content), contains(answerText),
          reason: 'feed\'da javob matni yo\'q');

      // ── 5c. MAVJUD BO'LMAGAN savol -> 404, MOCK EMAS ─────────────────────
      const ghostId = '00000000-0000-4000-8000-000000000000';
      Object? ghostError;
      try {
        final ghost = await communityDs.getPostById(ghostId);
        fail('mavjud bo\'lmagan savol uchun post qaytdi: ${ghost.id}');
      } catch (e) {
        ghostError = e;
      }
      stdout.writeln('EVIDENCE 5c — getPostById(mavjud emas): '
          '${ghostError is ServerException ? '${ghostError.statusCode} ${ghostError.message}' : ghostError}');
      expect(ghostError, isA<ServerException>());
      expect((ghostError as ServerException).statusCode, 404,
          reason: 'ilgari bu yerda `post_labor_1` qaytardi');

      // ── 6. RBAC: citizen ekspert javobi YUBORA OLMAYDI ───────────────────
      // Authorized negative test: o'z loyihasi, o'z sessiyasi.
      Object? rbacError;
      try {
        await communityDs.addAnswer(
          postId: post.id,
          content: 'Men litsenziyaga ega advokatman.',
          authorName: fullName,
          isExpert: true,
          authorRole: 'Litsenziyaga ega advokat',
        );
      } catch (e) {
        rbacError = e;
      }
      stdout.writeln('EVIDENCE 6 — RBAC xatosi: '
          '${rbacError is ServerException ? '${rbacError.statusCode} ${rbacError.message}' : rbacError}');
      expect(rbacError, isA<ServerException>(),
          reason: 'jimgina FALSE ga tushirish = yolg\'on success');
      expect((rbacError as ServerException).statusCode, 403);
      expect(rbacError.message, isNot(contains('Exception:')),
          reason: 'SnackBar\'da klass nomi ko\'rinmasligi kerak');

      // Ikkinchi javob YARATILMAGANIGA ishonch (faqat 1 qator qolishi kerak).
      final all = await client
          .from(kAnswersTable)
          .select('id, is_expert_answer')
          .eq('question_id', post.id);
      stdout.writeln('EVIDENCE 6 — savoldagi javoblar soni: '
          '${(all as List).length}');
      expect((all).length, 1,
          reason: 'RBAC xatosidan keyin qator yaratilmasligi kerak');
      expect(all.first['is_expert_answer'], isFalse);

      // ── 7. SECURITY: client o'ziga `lawyer` rolini bera olmaydi ──────────
      Object? escalationError;
      try {
        await client
            .from('profiles')
            .update({'role': 'lawyer', 'is_verified': true})
            .eq('id', user.id);
      } catch (e) {
        escalationError = e;
      }
      final afterEscalation = await client
          .from('profiles')
          .select('role, is_verified')
          .eq('id', user.id)
          .maybeSingle();
      stdout.writeln('EVIDENCE 7 — escalation xatosi: '
          '${escalationError == null ? 'YO\'Q' : escalationError.runtimeType} '
          '-> role=${afterEscalation?['role']} '
          'is_verified=${afterEscalation?['is_verified']}');
      expect(afterEscalation?['role'], 'citizen',
          reason: 'P0: foydalanuvchi o\'ziga `lawyer` bera oldi — '
              'ekspert javobi himoyasi ma\'nosini yo\'qotadi');
      expect(afterEscalation?['is_verified'], isFalse,
          reason: 'P0: foydalanuvchi o\'zini tasdiqlangan qildi');

      stdout.writeln('--- COMMUNITY ANSWER FLOW REAL SUPABASE\'DA TASDIQLANDI ---');
      stdout.writeln('Tozalash (SQL Editor, qo\'lda): '
          'delete from public.answers where question_id = \'${post.id}\'; '
          'delete from public.questions where id = \'${post.id}\'; '
          'delete from auth.users where email = \'$email\';');
    },
    skip: liveWrites
        ? false
        : 'SKIPPED (BLOCKED): real production yozuvi. Ishga tushirish: '
            '--dart-define-from-file=env/prod.json '
            '--dart-define=LEXHUB_LIVE_WRITE_TESTS=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
