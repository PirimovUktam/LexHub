// LEXHUB — HAMJAMIYAT YOZISH YO'LI: SESSIYALI (authenticated) LIVE ISBOT.
//
// NIMA UCHUN BU FAYL BOR: `20260830120000_tighten_loose_write_policies.sql`
// `questions` INSERT va `votes` FOR ALL policy'larini EGA doirasiga
// toraytirdi. Uning isboti IKKI qatlamda bor edi:
//   * katalog (`pg_policies`): `.runtime_evidence/mig_120000_apply.out.json`;
//   * SQL xulqi (`set_config('role','authenticated')` + soxta JWT claim):
//     `.runtime_evidence/rls_behavior_probe.out.json`.
// LEKIN ILOVA ZANJIRI (PostgREST + `supabase_flutter` + HAQIQIY sessiya)
// O'LCHANMAGAN edi va migratsiya sarlavhasida bu ochiq "PARTIALLY VERIFIED"
// deb yozilgan. Mavjud `real_supabase_community_e2e_test.dart` bu bo'shliqni
// TO'LDIRMAYDI: u `signIn*` CHAQIRMAYDI, faqat MEHMON rad etilishini
// tekshiradi. Shu fayl aynan shu bo'shliqni yopadi.
//
// USUL: ikkita HAQIQIY probe hisob (A va B) ochiladi, har biri O'Z
// `SupabaseClient` sessiyasini ushlaydi va yozish yo'llari ILOVA KODI orqali
// bajariladi (`CommunityForumDataSourceImpl`). Impersonatsiya urinishlari
// ataylab XOM PostgREST orqali yuboriladi — sabab: ilova metodi `user_id`ni
// tashqaridan qabul QILMAYDI, ya'ni server chegarasini boshqa yo'l bilan
// sinab bo'lmaydi. Ya'ni "ilova yo'li ishlaydi" va "server chegarasi
// ushlaydi" AYRIM-AYRIM o'lchanadi.
//
// BU TEST PRODUCTION'GA YOZADI: 2 auth user, 1 savol, 1 javob, ovozlar.
// Shu sababli `LEXHUB_LIVE_WRITE_TESTS` gate'i bor va oxirida hamma qator
// EGASI tomonidan o'chiriladi (qoldiq bo'lsa OSHKORA chop etiladi — jim
// tozalash YO'Q). `auth.users` qatorini o'chirish `service_role` talab
// qiladi, u `env/prod.json` ichida YO'Q — probe hisoblar QOLADI (BLOCKED,
// `cleanup_live_test_data_test.dart` bilan bir xil halol qayd).
//
// Ishga tushirish:
//   flutter test test/integration/community_write_session_rls_live_test.dart \
//     --dart-define-from-file=env/prod.json \
//     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
//
// CATCH-ALL YO'Q: kutilmagan natija FAIL beradi, PASS emas.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';

/// Bir probe hisob: o'z sessiyasini ushlab turadigan client + uning ID'si.
class _Probe {
  _Probe(this.client, this.uid, this.email);

  final SupabaseClient client;
  final String uid;
  final String email;
}

void main() {
  if (!liveSuiteEnabled('community_write_session_rls_live')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  const password = 'Password123!';
  // Implicit oqim — PKCE storage talab qilmaydi (sabab
  // `verify_mvp_blockers_live_test.dart` da batafsil yozilgan).
  const testAuthOptions = AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
  );

  late String url;
  late String anonKey;
  late _Probe a;
  late _Probe b;
  late String categoryId;
  late String categoryName;

  var questionId = '';
  var answerId = '';

  String redact(String id) => id.length > 12
      ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}'
      : id;

  /// Yangi probe hisob ochadi va SESSIYA olinganini ISBOTLAYDI.
  ///
  /// Sessiya olinmasa test BLOCKED sababi bilan yiqiladi — "sessiyasiz
  /// o'tkazib yuborish" YO'Q, aks holda fayl RLS ni o'lchamagan holda
  /// yashil ko'rinardi.
  Future<_Probe> openProbe(String tag) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final email = 'commwrite_probe_${tag}_$ts@lexhub.uz';
    final client = SupabaseClient(url, anonKey, authOptions: testAuthOptions);
    // DIQQAT: `addTearDown(client.dispose)` ATAYLAB ISHLATILMAYDI. O'LCHANGAN
    // NUQSON (2026-08-30, birinchi jonli yugurtirish): `setUpAll` ichida
    // qo'yilgan `addTearDown` LIFO tartibda `tearDownAll`dan OLDIN ishlaydi,
    // ya'ni client TOZALASHDAN OLDIN yopilgan va har bir DELETE
    // `ClientException: Client is already closed` bergan — natijada probe
    // qatorlari PRODUCTION'DA QOLGAN. Client'lar tozalash TUGAGACH yopiladi.

    final signUp = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': 'CommWrite Probe ${tag.toUpperCase()}'},
    );
    var session = signUp.session;
    if (session == null) {
      final signIn = await client.auth
          .signInWithPassword(email: email, password: password);
      session = signIn.session;
    }
    if (session == null) {
      fail('BLOCKED: $email uchun sessiya olinmadi (email confirmation '
          'yoqilgan bo\'lishi mumkin). Sessiyasiz bu fayl RLS ni O\'LCHAMAYDI.');
    }
    return _Probe(client, session.user.id, email);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    url = SupabaseConfig.url;
    anonKey = SupabaseConfig.anonKey;

    a = await openProbe('a');
    b = await openProbe('b');
    stdout.writeln('PROBE A uid=${redact(a.uid)} email=${a.email}');
    stdout.writeln('PROBE B uid=${redact(b.uid)} email=${b.email}');

    // `profiles` qatori `handle_new_user()` trigger'i bilan yaratiladi.
    // Bo'lmasa yozish yo'llari FK 23503 beradi va bu test RLS ni EMAS,
    // trigger nosozligini o'lchagan bo'lardi.
    for (final p in <_Probe>[a, b]) {
      final row =
          await p.client.db('profiles').select('id').eq('id', p.uid).maybeSingle();
      expect(row, isNotNull,
          reason: 'BLOCKED: `profiles` qatori YO\'Q (${redact(p.uid)}) — '
              'handle_new_user() ishlamadi.');
    }

    // Kategoriya REAL katalogdan olinadi (hardcode EMAS): ilova yo'li
    // display NOMni `category_id`ga o'girishi ham shu bilan o'lchanadi.
    final cats = await a.client.db('categories').select().limit(1);
    final catRows = cats as List<dynamic>;
    expect(catRows, isNotEmpty,
        reason: 'BLOCKED: public.categories BO\'SH — createQuestion '
            'kategoriya ID sini aniqlay olmaydi.');
    final cat = catRows.first as Map<String, dynamic>;
    final rawId = cat['id']?.toString().trim() ?? '';
    if (rawId.isEmpty) fail('BLOCKED: categories.id bo\'sh');
    categoryId = rawId;
    // Ilova bilan AYNI ustun tartibi (`QuestionCategoryCatalog.nameColumns`).
    String? display;
    for (final column in const ['name_uz', 'name_ru', 'name_en', 'name',
        'title', 'label']) {
      final value = cat[column];
      if (value is String && value.trim().isNotEmpty) {
        display = value.trim();
        break;
      }
    }
    // Nom ustuni bo'lmasa UUID o'zi ham o'tadi (`resolveId`: uuid
    // o'zgarmasdan qaytadi) — bu holat OSHKORA qayd etiladi.
    categoryName = display ?? categoryId;
    stdout.writeln('KATEGORIYA display="$categoryName" id=${redact(categoryId)}'
        '${display == null ? ' (NOM USTUNI YO\'Q — UUID ishlatildi)' : ''}');
  });

  test('1. SAVOL — ILOVA YO\'LI o\'z nomidan O\'TADI (sessiya + PostgREST)',
      () async {
    // BU TESTNING MA'NOSI: toraytirilgan `questions` INSERT policy'si real
    // ilova yo'lini SINDIRMAGANINI o'lchaydi. `createQuestion` `user_id`ni
    // sessiyadan oladi, ya'ni `auth.uid() = user_id` sharti bajarilishi kerak.
    final ds = CommunityForumDataSourceImpl(supabaseClient: a.client);

    final post = await ds.createQuestion(
      title: '[PROBE] sessiyali yozish testi',
      rawQuestion: 'PROBE savoli: sessiyali yozish yo\'lini o\'lchash uchun '
          'yaratildi va test oxirida o\'chiriladi.',
      category: categoryName,
      isAnonymous: false,
      authorName: 'CommWrite Probe A',
    );

    expect(post.id, isNotEmpty, reason: 'INSERT qator ID qaytarmadi');
    questionId = post.id;

    final row = await a.client
        .db('questions')
        .select('id, user_id')
        .eq('id', questionId)
        .single();
    expect(row['user_id'], a.uid,
        reason: 'Qator EGASI sessiya egasi EMAS — `auth.uid() = user_id` '
            'sharti buzilgan holatda qator yozilgan bo\'lardi.');
    stdout.writeln('EVIDENCE 1 — questions INSERT O\'TDI '
        'id=${redact(questionId)} user_id=${redact(a.uid)}');
  });

  test('2. SAVOL — BOSHQANING user_id bilan urinish RAD ETILADI (42501)',
      () async {
    // ATAYLAB XOM PostgREST: `createQuestion` `user_id`ni tashqaridan qabul
    // qilmaydi, ya'ni impersonatsiyani ilova metodi orqali sinab BO'LMAYDI.
    // O'lchanadigan narsa — SERVER chegarasi, klient qulfi emas.
    try {
      await a.client.db('questions').insert({
        'user_id': b.uid,
        'category_id': categoryId,
        'title': '[PROBE] impersonatsiya urinishi',
        'body': 'Bu qator YOZILMASLIGI kerak.',
      });
      fail('IMPERSONATSIYA O\'TDI: A sessiyasi B nomidan savol yozdi — RLS '
          'to\'smadi (P0). Qator qolgan bo\'lishi mumkin, qo\'lda tekshiring.');
    } on PostgrestException catch (e) {
      expect(e.code, '42501',
          reason: 'Kutilgan 42501 (insufficient_privilege). Olingan: '
              '${e.code} — ${e.message}');
      stdout.writeln('EVIDENCE 2 — impersonatsiya RAD ETILDI: ${e.code}');
    }
  });

  test('3. JAVOB — ILOVA YO\'LI o\'z nomidan O\'TADI (ovoz uchun fixture)',
      () async {
    if (questionId.isEmpty) {
      fail('BLOCKED: 1-test savol yaratmadi — bu test o\'lchay olmaydi.');
    }
    final ds = CommunityForumDataSourceImpl(supabaseClient: a.client);

    final answer = await ds.addAnswer(
      postId: questionId,
      content: 'PROBE javobi: ovoz yo\'lini o\'lchash uchun kerak.',
      authorName: 'CommWrite Probe A',
      isExpert: false,
    );

    expect(answer.id, isNotEmpty);
    answerId = answer.id;
    stdout.writeln('EVIDENCE 3 — answers INSERT O\'TDI id=${redact(answerId)}');
  });

  test('4. OVOZ — SXEMA SHARTNOMASI bo\'yicha o\'z nomidan O\'TADI', () async {
    // `public.votes` O'LCHANGAN SXEMASI (2026-08-30,
    // `.runtime_evidence/votes_schema_facts.out.json`):
    //   user_id   NOT NULL, FK -> profiles(id)
    //   answer_id NOT NULL, FK -> answers(id), UNIQUE (user_id, answer_id)
    //   vote_type NOT NULL DEFAULT 'helpful'
    //   target_type / target_id / vote_value — NULLABLE (keyin qo'shilgan)
    // Ya'ni jadvalning HAQIQIY shartnomasi `answer_id`ga tayanadi.
    if (answerId.isEmpty) {
      fail('BLOCKED: 3-test javob yaratmadi — ovoz yo\'li o\'lchanmaydi.');
    }

    final inserted = await a.client
        .db('votes')
        .insert({'user_id': a.uid, 'answer_id': answerId})
        .select('id, user_id, answer_id')
        .single();

    expect(inserted['user_id'], a.uid);
    expect(inserted['answer_id'], answerId);
    stdout.writeln('EVIDENCE 4 — votes INSERT (EGA) O\'TDI');
  });

  test('5. OVOZ — BOSHQANING user_id bilan urinish RAD ETILADI (42501)',
      () async {
    if (answerId.isEmpty) {
      fail('BLOCKED: 3-test javob yaratmadi.');
    }
    try {
      await a.client
          .db('votes')
          .insert({'user_id': b.uid, 'answer_id': answerId});
      fail('OVOZ IMPERSONATSIYASI O\'TDI: A sessiyasi B nomidan ovoz yozdi '
          '(P0). Ovoz sanog\'i buzilgan bo\'lishi mumkin.');
    } on PostgrestException catch (e) {
      expect(e.code, '42501',
          reason: 'Kutilgan 42501. Olingan: ${e.code} — ${e.message}');
      stdout.writeln('EVIDENCE 5 — ovoz impersonatsiyasi RAD ETILDI: ${e.code}');
    }
  });

  test('6. OVOZ MAXFIYLIGI — B ning ovozi A ga KO\'RINMAYDI va O\'CHMAYDI',
      () async {
    if (answerId.isEmpty) {
      fail('BLOCKED: 3-test javob yaratmadi.');
    }
    // B O'Z nomidan ovoz beradi — bu O'TISHI shart, aks holda keyingi
    // o'lchov (ko'rinmaslik) MA'NOSIZ bo'ladi: yo'q qatorni ko'rmaslik
    // hech narsani isbotlamaydi (non-vacuity).
    final bVote = await b.client
        .db('votes')
        .insert({'user_id': b.uid, 'answer_id': answerId})
        .select('id')
        .single();
    final bVoteId = bVote['id']?.toString() ?? '';
    expect(bVoteId, isNotEmpty, reason: 'B o\'z ovozini yoza olmadi');

    // A B ning ovozini O'QIY OLMAYDI.
    final seen = await a.client
        .db('votes')
        .select('id')
        .eq('user_id', b.uid) as List<dynamic>;
    expect(seen, isEmpty,
        reason: 'A BOSHQANING ovozini KO\'RDI — ovoz maxfiyligi buzilgan '
            '(${seen.length} qator).');

    // A B ning ovozini O'CHIRA OLMAYDI. RLS DELETE'ni FILTRLAYDI, xato
    // BERMAYDI — shu sababli isbot "0 qator ta'sir qildi" + qator HAMON
    // B da MAVJUD.
    final deleted = await a.client
        .db('votes')
        .delete()
        .eq('user_id', b.uid)
        .select('id') as List<dynamic>;
    expect(deleted, isEmpty,
        reason: 'A BOSHQANING ovozini O\'CHIRDI (${deleted.length} qator).');

    final stillThere = await b.client
        .db('votes')
        .select('id')
        .eq('id', bVoteId) as List<dynamic>;
    expect(stillThere, hasLength(1),
        reason: 'B ning ovozi YO\'QOLDI — DELETE aslida bajarilgan.');
    stdout.writeln('EVIDENCE 6 — begona ovoz: SELECT 0 qator, DELETE 0 qator');
  });

  test('7. OVOZ YO\'LI — `voteAnswer` HAQIQATAN yozadi va SONNI harakatlantiradi',
      () async {
    // ILGARI BU TEST NUQSONNI QAYD ETARDI (`23502`): DataSource `votes` ga
    // FAQAT `user_id`/`target_type`/`target_id`/`vote_value` yuborardi,
    // `answer_id` esa NOT NULL va DEFAULT'siz. Ovoz RLS ga YETIB BORMASDAN
    // yiqilardi va `votes` jadvalida 0 qator bor edi
    // (`.runtime_evidence/votes_schema_facts.out.json`, 2026-08-30).
    //
    // PAYLOAD TUZATILDI (`answer_id` yuboriladi), shuning uchun ratchet
    // YUMSHATILMADI — o'lchov ALMASHTIRILDI: endi ovoz yo'li HAQIQATAN
    // ishlashini isbotlaydi. Regressiya qaytsa (payload'dan `answer_id`
    // tushib qolsa) bu test QIZIL bo'ladi.
    if (answerId.isEmpty) {
      fail('BLOCKED: 3-test javob yaratmadi — ovoz yo\'li o\'lchanmaydi.');
    }
    final ds = CommunityForumDataSourceImpl(supabaseClient: a.client);

    Future<List<dynamic>> aVoteRows() async =>
        await a.client
            .db('votes')
            .select('id, user_id, answer_id, target_type, target_id, '
                'vote_type, vote_value')
            .eq('user_id', a.uid)
            .eq('answer_id', answerId) as List<dynamic>;

    // NON-VACUITY: 4-test AYNI (user_id, answer_id) uchun BITTA qator yozgan.
    // Ya'ni quyidagi birinchi chaqiriq "topib o'chirish" tarmog'ini
    // o'lchaydi, "hech narsa yo'q" holatini emas.
    expect(await aVoteRows(), hasLength(1),
        reason: '4-test ovozi yo\'q — toggle o\'lchovi ma\'nosiz bo\'ladi.');

    // 1-CHAQIRIQ = TOGGLE OFF. Mavjud qator `answer_id` KALITI bilan
    // topiladi. Agar kalit yana `target_id` ga qaytarilsa, qator TOPILMAYDI
    // va INSERT urinishi `UNIQUE (user_id, answer_id)` ni buzib `23505`
    // beradi — ya'ni bu qadam regressiyani ushlaydi.
    final off = await ds.voteAnswer(answerId);
    expect(off.isUpvotedByMe, isFalse,
        reason: 'toggle-off dan keyin "men ovoz berdim" belgisi O\'CHISHI '
            'kerak edi.');
    expect(await aVoteRows(), isEmpty,
        reason: 'toggle-off qatorni O\'CHIRMADI — DELETE kaliti noto\'g\'ri.');

    // KO'RINADIGAN SON — trigger javobi. Delta AYNAN bitta INSERT ga
    // tegishli bo'lishi uchun toggle-on dan TO'G'RIDAN oldin o'qiladi.
    // (Absolyut qiymat KUTILMAYDI: 6-testda B ham AYNI javobga ovoz bergan
    // va jonli trigger shakli O'LCHANMAGAN — shuning uchun faqat DELTA.)
    //
    // O'LCHANDI 2026-09-02 (production, 8/8 sinov O'TDI):
    //   EVIDENCE 7  — answer_id yozildi, target_type=answer, target_id BOR,
    //                 vote_type=helpful, vote_value=1;
    //   EVIDENCE 7b — answers.upvotes_count: 0 -> 1 (voteAnswer qaytardi: 1).
    // Ya'ni `upvotes_count` ustuni MAVJUD va jonli hisoblovchi trigger
    // AYNI payload bilan ISHLAYDI. Trigger DEFINITION'i hamon o'qilmagan
    // (`service_role` yo'q), shu sababli assertion DELTA bo'lib QOLADI.
    final rowBefore = Map<String, dynamic>.from(
        await a.client.db('answers').select('*').eq('id', answerId).single());
    if (!rowBefore.containsKey('upvotes_count')) {
      fail('YANGI O\'LCHANGAN FAKT: `answers` jadvalida `upvotes_count` '
          'ustuni YO\'Q. Ya\'ni UI ("N foydali") HAR DOIM 0 ko\'rsatadi '
          '(`question_answer_model.dart:66` `?? 0`). Bu sxema/UI '
          'nomuvofiqligi — mijoz tomonidan tuzatilmaydi.');
    }
    final counterBefore = rowBefore['upvotes_count'] as int? ?? 0;

    // 2-CHAQIRIQ = TOGGLE ON: AYNAN SHU YERDA ilgari `23502` chiqardi.
    final on = await ds.voteAnswer(answerId);
    expect(on.isUpvotedByMe, isTrue);

    final rows = await aVoteRows();
    expect(rows, hasLength(1),
        reason: 'ovoz YOZILMADI yoki ikki marta yozildi: ${rows.length}');
    final row = rows.first as Map<String, dynamic>;
    expect(row['user_id'], a.uid);
    expect(row['answer_id'], answerId);
    stdout.writeln('EVIDENCE 7 — jonli ovoz qatori: '
        'answer_id=${redact(row['answer_id']?.toString() ?? '')} '
        'target_type=${row['target_type']} '
        'target_id_bor=${row['target_id'] != null} '
        'vote_type=${row['vote_type']} vote_value=${row['vote_value']}');

    final counterAfter = Map<String, dynamic>.from(await a.client
            .db('answers')
            .select('*')
            .eq('id', answerId)
            .single())['upvotes_count'] as int? ??
        0;
    stdout.writeln('EVIDENCE 7b — answers.upvotes_count: '
        '$counterBefore -> $counterAfter '
        '(voteAnswer qaytardi: ${on.upvotesCount})');
    expect(counterAfter, counterBefore + 1,
        reason: 'Ovoz QATORI yozildi, lekin KO\'RINADIGAN son harakatlanmadi. '
            'Ya\'ni jonli `handle_vote_counter()` `answer_id` ni ham, '
            'yuborilgan `target_type`/`target_id` ni ham hisobga olmaydi — '
            'foydalanuvchi ovoz berdi, son esa eski qoldi (jim '
            'yarim-nosozlik). Tuzatish SERVER tomonida (trigger), mijozda '
            'emas.');
    expect(on.upvotesCount, counterAfter,
        reason: 'DataSource qaytargan son BAZADAGI son bilan mos emas — UI '
            'serverdan ajralib ketadi.');
  });

  test('8. SAVOLGA OVOZ — `votePost` SABABINI aytib RAD ETADI (jim emas)',
      () async {
    // JONLI SXEMA: `votes.answer_id` NOT NULL, DEFAULT'siz va
    // `FOREIGN KEY (answer_id) REFERENCES answers(id)` — ya'ni SAVOL id si
    // bu jadvalga JISMONAN sig'maydi. Ilgari UI sonni O'ZI oshirib qo'yardi
    // va xato BLoC'da JIM YUTILARDI, ya'ni foydalanuvchi YOZILMAGAN ovozni
    // ko'rardi. Endi: (a) UI'da bosiladigan tugma YO'Q
    // (`community_post_card.dart`), (b) DataSource tarmoqqa CHIQMASDAN
    // 501 va SABAB qaytaradi.
    if (questionId.isEmpty) {
      fail('BLOCKED: 1-test savol yaratmadi.');
    }
    final ds = CommunityForumDataSourceImpl(supabaseClient: a.client);

    try {
      await ds.votePost(questionId);
      fail('`votePost` MUVAFFAQIYAT qaytardi. Sxema savol ovozini '
          'qo\'llab-quvvatlagan bo\'lsa, bu testni YANGILANG va UI\'ga '
          'tugmani qaytaring — aks holda bu YOLG\'ON SUCCESS.');
    } on ServerException catch (e) {
      expect(e.statusCode, 501,
          reason: 'Kutilgan 501 (qo\'llab-quvvatlanmaydi). Olingan: '
              '${e.statusCode} — server xatosi bo\'lib ko\'rinadi.');
      expect(e.message, isNotEmpty);
      stdout.writeln('EVIDENCE 8 — votePost RAD ETDI: '
          'statusCode=${e.statusCode} message=${e.message}');
    }

    // JIM QATOR YOZILMAGANI: 7-testdagi BITTA ovoz o'zgarmagan bo'lishi kerak.
    final aVotes = await a.client
        .db('votes')
        .select('id, answer_id')
        .eq('user_id', a.uid) as List<dynamic>;
    expect(aVotes, hasLength(1),
        reason: 'Savol ovozi yo\'li QATOR QOLDIRDI yoki 7-test ovozi '
            'yo\'qoldi — o\'lchangan: ${aVotes.length}');
    expect((aVotes.first as Map<String, dynamic>)['answer_id'], answerId);
  });


  tearDownAll(() async {
    // TOZALASH EGA SESSIYASI ORQALI — RLS chetlab o'tilmaydi. Ya'ni bu
    // qadam "ega o'z ma'lumotini o'chira oladi" qoidasini HAM o'lchaydi.
    // Xato YUTILMAYDI: har bir nosozlik chop etiladi.
    final qoldiq = <String>[];

    Future<int> tozala(
      _Probe p,
      String jadval,
      String ustun,
      String qiymat,
    ) async {
      try {
        final res = await p.client
            .db(jadval)
            .delete()
            .eq(ustun, qiymat)
            .select('id') as List<dynamic>;
        return res.length;
      } catch (e) {
        qoldiq.add('$jadval ($ustun=${redact(qiymat)}): $e');
        return 0;
      }
    }

    final bVotes = await tozala(b, 'votes', 'user_id', b.uid);
    final aVotes = await tozala(a, 'votes', 'user_id', a.uid);
    final aAnswers = await tozala(a, 'answers', 'user_id', a.uid);
    final aQuestions = await tozala(a, 'questions', 'user_id', a.uid);
    stdout.writeln('TOZALASH: votes(B)=$bVotes votes(A)=$aVotes '
        'answers(A)=$aAnswers questions(A)=$aQuestions');

    // QOLDIQ O'LCHOVI: DELETE 0 qaytarishi (a) qator yo'q, (b) DELETE
    // policy yo'q — degan IKKI ma'noga ega. Farqni SELECT ajratadi.
    // XATO YUTILMAYDI, lekin TO'XTATMAYDI ham: birinchi SELECT yiqilsa
    // qolgan qoldiq o'lchovlari va `qoldiq` ro'yxati CHOP ETILMAY qolardi
    // (birinchi jonli yugurtirishda AYNAN shu bo'lgan).
    for (final entry in <List<String>>[
      ['questions', a.uid],
      ['answers', a.uid],
      ['votes', a.uid],
    ]) {
      try {
        final rows = await a.client
            .db(entry[0])
            .select('id')
            .eq('user_id', entry[1]) as List<dynamic>;
        if (rows.isNotEmpty) {
          qoldiq.add('${entry[0]}: ${rows.length} qator O\'CHMADI '
              '(DELETE policy yo\'q bo\'lishi mumkin)');
        }
      } catch (e) {
        qoldiq.add('${entry[0]}: QOLDIQ O\'LCHANMADI: $e');
      }
    }

    if (qoldiq.isEmpty) {
      stdout.writeln('TOZALASH TO\'LIQ: probe qatorlari qolmadi.');
    } else {
      stdout.writeln('QOLDIQ (qo\'lda ko\'rib chiqilishi kerak):');
      for (final line in qoldiq) {
        stdout.writeln('  * $line');
      }
    }

    // `auth.users` qatorlari QOLADI (`service_role` yo'q — BLOCKED).
    stdout.writeln('QOLGAN PROBE HISOBLAR (cleanup_live_test_data_test.dart '
        'ro\'yxatiga qo\'shish uchun):\n  ${a.email}\n  ${b.email}');

    // CLIENT'LAR ENG OXIRIDA yopiladi — tozalash ular orqali bajarilgan.
    a.client.dispose();
    b.client.dispose();

    // QOLDIQ = QIZIL. Jim o'tkazib yuborish YO'Q: production'da probe
    // qatori qolishi (a) tozalash yo'li buzilgani, (b) `questions`/`answers`/
    // `votes` da EGA uchun DELETE policy yo'qligini bildiradi — ikkisi ham
    // QAYD ETILISHI shart, chunki 8 ta sinov yashil bo'lsa ham chiqindi
    // real bazada qoladi.
    if (qoldiq.isNotEmpty) {
      fail('TOZALASH TO\'LIQ EMAS — production\'da probe qoldig\'i bor:\n'
          '${qoldiq.join('\n')}');
    }
  });
}
