import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/community_forum/data/datasources/answer_schema.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/data/models/community_post_model.dart';
import 'package:lexhub/features/community_forum/data/models/question_answer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/source_scan.dart';

/// COMMUNITY READ PATH — MOCK FALLBACK (`post_labor_1`) GUARD
///
/// MUHIM CHEKLOV (CLAIM != EVIDENCE): bu fayl REAL `getPostById` / `getPosts`
/// kodini ishga tushiradi, lekin transport SOXTA (`_FakePostgrest`). U live
/// Supabase'da ishlashini ISBOTLAMAYDI — buni faqat
/// `test/integration/verify_community_answer_live_test.dart` (gated) qiladi.
/// Bu testlar quyidagi REAL evidence ustiga qurilgan:
///
/// LIVE RUN (2026-08-22, prod, gated live test):
///   INSERT muvaffaqiyatli: answers.id = 892ac76e-1e3b-40b1-95a3-afc56ba72564
///   answers.body = "Mehnat kodeksining 173-moddasiga qarang."
///   questions.id = 36e0782e-97de-4f7e-8aae-48646c5ea27e
///   LEKIN read-back: EXPECTED 36e0782e-... / ACTUAL post_labor_1  <-- P0 BUG
///
/// LOCAL REPRO (2026-08-22, `flutter test`, haqiqiy stack trace):
///   `type 'QuestionAnswerModel' is not a subtype of type 'Map<String, dynamic>'`
///   `community_post_model.dart 34:57  new CommunityPostModel.fromJson.<fn>`
void main() {
  // ── Live'dan AYNAN ko'chirilgan qatorlar ────────────────────────────────
  const kQuestionId = '36e0782e-97de-4f7e-8aae-48646c5ea27e';
  const kAnswerId = '892ac76e-1e3b-40b1-95a3-afc56ba72564';
  const kUserId = '2e09d109-a802-4876-9de2-0ebbc72f4838';
  const kAnswerText = 'Mehnat kodeksining 173-moddasiga qarang.';

  /// `public_questions_view` live javobi (select=*, 2026-08-22).
  Map<String, dynamic> liveQuestionRow() => <String, dynamic>{
        'id': kQuestionId,
        'category_id': '9e25aeac-a6e0-4e0f-8262-02b06a714f42',
        'title': 'Answer probe savoli 1787385405015',
        'description': "Ishdan bo'shatilganda qanday kompensatsiya olaman?",
        'anonymized_question':
            "Ishdan bo'shatilganda qanday kompensatsiya olaman?",
        'is_anonymous': false,
        'status': 'open',
        'views_count': 1,
        'upvotes_count': 0,
        'answers_count': 1,
        'is_ai_analyzed': false,
        'ai_summary': "Ushbu savol Mehnat huquqi doirasida ko'rib chiqiladi.",
        'ai_clarifications': null,
        'created_at': '2026-08-22T07:56:50.389229+00:00',
        'updated_at': '2026-08-22T07:56:51.580216+00:00',
        'user_id': kUserId,
        'author_name': 'Answer Probe',
        'author_avatar_url': null,
        'author_is_verified': false,
      };

  /// `answers` live javobi. DIQQAT: `content` KALITI YO'Q — live schema
  /// AYNAN shunday (`select=content` -> 42703).
  Map<String, dynamic> liveAnswerRow() => <String, dynamic>{
        'id': kAnswerId,
        'question_id': kQuestionId,
        'user_id': kUserId,
        'body': kAnswerText,
        'is_expert_answer': false,
        'is_accepted': false,
        'upvotes_count': 0,
        'legal_references': <dynamic>[],
        'created_at': '2026-08-22T07:56:51.580216+00:00',
        'updated_at': '2026-08-22T07:56:51.580216+00:00',
        'profiles': {
          'full_name': 'Answer Probe',
          'role': 'citizen',
          'is_verified': false,
          'avatar_url': null,
        },
      };

  /// So'rovlar jurnali — testlar HTTP darajasida nima yuborilganini
  /// tekshiradi (guard vakuum bo'lmasligi uchun).
  late List<http.BaseRequest> sent;

  /// PostgREST'ni imitatsiya qiladigan datasource quradi.
  ///
  /// [handlers] — jadval nomi -> (so'rov) => javob. Jadval topilmasa test
  /// ATAYLAB yiqiladi: kutilmagan endpoint jimgina 200 olmasligi kerak.
  ///
  /// NIMA UCHUN `MockClient` EMAS: postgrest 2.9.1 `_parseResponse`
  /// (`postgrest_builder.dart:462`) `response.request!.method` ni o'qiydi.
  /// `http/testing.dart` javobga `request` ni ULAMAYDI — natijada HAR BIR
  /// so'rov `Null check operator used on a null value` bilan yiqiladi va
  /// bu TEST HARNESS defekti production xatosi kabi ko'rinadi. Shuning uchun
  /// javob `http.StreamedResponse(..., request: request)` orqali qaytariladi.
  CommunityForumDataSourceImpl buildDataSource(
    Map<String, http.Response Function(http.Request request)> handlers,
  ) {
    sent = <http.BaseRequest>[];
    final client = _FakePostgrest((request) {
      sent.add(request);
      final segments = request.url.pathSegments;
      final table = segments.isEmpty ? '' : segments.last;
      final handler = handlers[table];
      if (handler == null) {
        return http.Response(
          jsonEncode({
            'code': 'TEST',
            'message': 'kutilmagan endpoint: ${request.url}',
          }),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      return handler(request);
    });

    return CommunityForumDataSourceImpl(
      supabaseClient: SupabaseClient(
        'https://test.supabase.co',
        'sb_publishable_test_key',
        httpClient: client,
      ),
    );
  }

  http.Response ok(Object json) => http.Response(
        jsonEncode(json),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// PostgREST xato javobi (live bilan bir xil shakl).
  http.Response pgError({
    required int status,
    required String code,
    required String message,
  }) =>
      http.Response(
        jsonEncode({
          'code': code,
          'details': null,
          'hint': null,
          'message': message,
        }),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// Katalog (`categories`) va view/answers uchun standart handlerlar.
  Map<String, http.Response Function(http.Request)> happyHandlers() => {
        'categories': (_) => ok([
              {
                'id': '9e25aeac-a6e0-4e0f-8262-02b06a714f42',
                'name': 'Mehnat huquqi',
                'slug': 'mehnat-huquqi',
              },
            ]),
        'public_questions_view': (_) => ok([liveQuestionRow()]),
        kAnswersTable: (_) => ok([liveAnswerRow()]),
        'votes': (_) => ok(<dynamic>[]),
      };

  group('getPostById — REAL savol qaytadi, mock EMAS', () {
    test('real question ID -> AYNAN o\'sha savol qaytadi', () async {
      final ds = buildDataSource(happyHandlers());

      final post = await ds.getPostById(kQuestionId);

      // NON-VACUITY: soxta transport haqiqatan chaqirilgan.
      expect(sent, isNotEmpty, reason: 'HTTP so\'rov yuborilmagan');
      expect(post.id, kQuestionId,
          reason: 'P0: live testda bu yerda `post_labor_1` qaytgan');
      expect(post.id, isNot('post_labor_1'));
      expect(post.title, 'Answer probe savoli 1787385405015');
      expect(post.anonymizedQuestion,
          "Ishdan bo'shatilganda qanday kompensatsiya olaman?");
      // Kategoriya UUID emas, katalogdan olingan NOM.
      expect(post.category, 'Mehnat huquqi');
    });

    test('real javob `body` ustunidan o\'qiladi', () async {
      final ds = buildDataSource(happyHandlers());

      final post = await ds.getPostById(kQuestionId);

      expect(post.answers, hasLength(1), reason: 'javob READ yo\'lida yo\'q');
      final answer = post.answers.single;
      expect(answer.id, kAnswerId);
      expect(answer.content, kAnswerText,
          reason: 'live qatorida `content` kaliti YO\'Q — matn `body`da');
      expect(answer.isExpert, isFalse);
      expect(answer.authorName, 'Answer Probe');
    });

    test('`answers` so\'rovi `content` ustunini NOMLAMAYDI', () async {
      final ds = buildDataSource(happyHandlers());
      await ds.getPostById(kQuestionId);

      final answerRequests = sent
          .where((r) => r.url.pathSegments.last == kAnswersTable)
          .toList();
      expect(answerRequests, isNotEmpty, reason: 'javoblar so\'ralmagan');
      for (final r in answerRequests) {
        final select = r.url.queryParameters['select'] ?? '';
        expect(select, isNot(contains('content')),
            reason: 'live\'da `answers.content` YO\'Q (42703)');
        expect(r.url.query, contains('question_id=eq.$kQuestionId'));
      }
    });

    test('javob YO\'Q savol ham normal qaytadi (bo\'sh ro\'yxat)', () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        kAnswersTable: (_) => ok(<dynamic>[]),
      });

      final post = await ds.getPostById(kQuestionId);
      expect(post.id, kQuestionId);
      expect(post.answers, isEmpty);
    });
  });

  group('getPostById — REAL xato mock bilan YASHIRILMAYDI', () {
    test('savol topilmasa 404 ServerException (mock post EMAS)', () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        'public_questions_view': (_) => ok(<dynamic>[]),
        'questions': (_) => ok(<dynamic>[]),
      });

      await expectLater(
        ds.getPostById(kQuestionId),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('javoblar so\'rovi xato bersa ServerException (jimgina bo\'sh EMAS)',
        () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        kAnswersTable: (_) => pgError(
            status: 400,
            code: '42703',
            message: 'column answers.content does not exist'),
      });

      try {
        final post = await ds.getPostById(kQuestionId);
        fail('ServerException kutilgan edi, lekin post qaytdi: ${post.id}');
      } on ServerException catch (e) {
        expect(e.message, contains('does not exist'));
        expect(e.statusCode, 42703,
            reason: 'PostgREST kodi saqlanishi kerak');
      }
    });

    test('savol so\'rovi 500 bersa mock post QAYTMAYDI', () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        'public_questions_view': (_) => pgError(
            status: 500, code: 'XX000', message: 'internal server error'),
        'questions': (_) => pgError(
            status: 500, code: 'XX000', message: 'internal server error'),
      });

      try {
        final post = await ds.getPostById(kQuestionId);
        fail('mock post qaytdi: ${post.id}');
      } on ServerException catch (e) {
        expect(e.message, isNot(contains('Majburiy mehnat')),
            reason: 'mock post matni foydalanuvchiga chiqmasligi kerak');
      }
    });

    test('RLS xatosi (42501) ham ServerException bo\'lib chiqadi', () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        'public_questions_view': (_) => pgError(
            status: 401,
            code: '42501',
            message: 'permission denied for table questions'),
        'questions': (_) => pgError(
            status: 401,
            code: '42501',
            message: 'permission denied for table questions'),
      });

      await expectLater(
        ds.getPostById(kQuestionId),
        throwsA(isA<ServerException>()
            .having((e) => e.message, 'message', contains('permission denied'))),
      );
    });
  });

  group('getPosts — feed ham mock post bermaydi', () {
    test('javobi BOR savol feed\'da real ko\'rinadi', () async {
      // P0 EDI: javob bor bo'lgan HAR QANDAY savol feed'ni TypeError'ga
      // olib borardi -> butun feed `_fallbackPosts` (mock) ga aylanardi.
      final ds = buildDataSource(happyHandlers());

      final posts = await ds.getPosts();

      expect(posts, hasLength(1));
      expect(posts.single.id, kQuestionId);
      expect(posts.single.answers.single.content, kAnswerText);
    });

    test('bo\'sh baza -> BO\'SH ro\'yxat (mock post EMAS)', () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        'public_questions_view': (_) => ok(<dynamic>[]),
        'questions': (_) => ok(<dynamic>[]),
      });

      final posts = await ds.getPosts();
      expect(posts, isEmpty,
          reason: 'ilgari bu yerda `post_labor_1` qaytardi');
    });

    test('DB xatosi -> ServerException (mock post EMAS)', () async {
      final ds = buildDataSource({
        ...happyHandlers(),
        'public_questions_view': (_) => pgError(
            status: 500, code: 'XX000', message: 'internal server error'),
        'questions': (_) => pgError(
            status: 500, code: 'XX000', message: 'internal server error'),
      });

      await expectLater(ds.getPosts(), throwsA(isA<ServerException>()));
    });
  });

  group('MAPPING REGRESSIYASI — ikki marta map qilish', () {
    test('DETEKTOR: model obyektlari solingan `answers` ham ishlaydi', () {
      // Bu AYNAN eski datasource bergan shakl. Fix'dan oldin bu yerda
      // TypeError chiqardi (yuqoridagi haqiqiy stack trace).
      final qMap = liveQuestionRow();
      qMap['answers'] = <QuestionAnswerModel>[
        QuestionAnswerModel.fromJson(liveAnswerRow()),
      ];

      final post = CommunityPostModel.fromJson(qMap);
      expect(post.id, kQuestionId);
      expect(post.answers.single.content, kAnswerText);
    });

    test('xom JSON solingan `answers` ham ishlaydi (hozirgi yo\'l)', () {
      final qMap = liveQuestionRow();
      qMap['answers'] = <Map<String, dynamic>>[liveAnswerRow()];

      final post = CommunityPostModel.fromJson(qMap);
      expect(post.answers.single.id, kAnswerId);
    });

    test('noma\'lum tur JIMGINA TASHLAB KETILMAYDI', () {
      final qMap = liveQuestionRow();
      qMap['answers'] = <dynamic>['bu javob emas'];

      expect(() => CommunityPostModel.fromJson(qMap),
          throwsA(isA<AnswerMappingException>()),
          reason: 'javobni jimgina yo\'qotish = "savol javobsiz" yolg\'oni');
    });

    test('`answers` yo\'q bo\'lsa bo\'sh ro\'yxat', () {
      final post = CommunityPostModel.fromJson(liveQuestionRow());
      expect(post.answers, isEmpty);
    });
  });

  group('SOURCE GUARD — mock fallback qaytib kelmaydi', () {
    late final String datasourceSource;
    late final String datasourceCode;

    setUpAll(() {
      datasourceSource = File('lib/features/community_forum/data/datasources/'
              'community_forum_remote_datasource.dart')
          .readAsStringSync();
      // Guard KOD ni qo'riqlaydi, hujjatni emas: evidence izohlarida
      // `post_labor_1` va `_fallbackPosts` ATAYLAB qoldirilgan.
      datasourceCode = stripLineComments(datasourceSource);
    });

    test('guard haqiqatan manba faylni o\'qiydi', () {
      expect(datasourceSource.length, greaterThan(5000),
          reason: 'fayl o\'qilmasa guardlar hech narsani qo\'riqlamaydi');
      expect(datasourceSource, contains('getPostById'));
      // NON-VACUITY: izoh tozalash haqiqatan ishlayotganini isbotlaydi —
      // ID hujjatda BOR, kodda YO'Q.
      expect(datasourceSource, contains('post_labor_1'),
          reason: 'evidence izohi o\'chib ketgan');
      expect(datasourceCode, isNot(contains('post_labor_1')));
    });

    test('`post_labor_1` lib/ KODIDA umuman yo\'q', () {
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final code = stripLineComments(file.readAsStringSync());
        if (code.contains('post_labor_1') || code.contains('ans_101')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'live testda AYNAN `post_labor_1` real savol o\'rniga '
              'qaytgan — mock ma\'lumot production yo\'lida bo\'lmasligi kerak');
    });

    test('`_fallbackPosts` identifikatori kodda yo\'q', () {
      expect(datasourceCode.contains('_fallbackPosts'), isFalse);
    });

    test('o\'qish yo\'lida `catch (_) {}` (bo\'sh yutuvchi) yo\'q', () {
      expect(RegExp(r'catch\s*\(_\)\s*\{\s*\}').hasMatch(datasourceCode),
          isFalse,
          reason: 'javoblar so\'rovi xatosi yutilsa savol "javobsiz" '
              'ko\'rinadi (yolg\'on holat)');
    });

    test('`getPostById` topilmagan savol uchun 404 beradi', () {
      // DIQQAT: `indexOf` abstract class dagi E'LONNI topadi
      // (`abstract class CommunityForumDataSource`), implementatsiyani EMAS.
      // Shuning uchun `@override` bilan boshlanadigan oxirgi bo'lak olinadi.
      final start = datasourceSource
          .lastIndexOf('Future<CommunityPostModel> getPostById(');
      expect(start, greaterThan(0));
      expect(datasourceSource.lastIndexOf('@override', start),
          greaterThan(datasourceSource
              .indexOf('Future<CommunityPostModel> getPostById(')),
          reason: 'implementatsiya emas, abstract e\'lon olindi');
      final end = datasourceSource.indexOf('createQuestion(', start);
      final body = datasourceSource.substring(start, end > start ? end : null);
      expect(RegExp(r'statusCode:\s*404').hasMatch(body), isTrue);
      expect(
          body.contains('parseAnswerList') || body.contains("qMap['answers']"),
          isTrue);
    });

    test('model matnni `readAnswerText` orqali o\'qiydi, `content` emas', () {
      expect(kAnswerTextColumn, 'body');
      final modelSource = File('lib/features/community_forum/data/models/'
              'question_answer_model.dart')
          .readAsStringSync();
      expect(modelSource.contains('readAnswerText('), isTrue);
    });

    test('o\'qish yo\'li `answers.content` ustunini NOMLAMAYDI', () {
      final sources = <String, String>{};
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        sources[file.path] = file.readAsStringSync();
      }
      expect(findAnswerContentOffenders(sources), isEmpty,
          reason: 'live: `answers.content` -> 42703 column does not exist');
    });
  });
}

/// Soxta PostgREST transporti.
///
/// `MockClient` (`package:http/testing.dart`) O'RNIGA yozilgan: u javobga
/// `request` ni ulamaydi, postgrest esa `_parseResponse` da
/// `response.request!.method` deb o'qiydi (postgrest_builder.dart:462) —
/// natijada har bir so'rov `Null check operator used on a null value`
/// bilan yiqilib, test harness defekti production bug'i kabi ko'rinadi.
class _FakePostgrest extends http.BaseClient {
  _FakePostgrest(this.handler);

  final http.Response Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    // postgrest `http.Request` yuboradi; body'ni qayta o'qish uchun nusxa.
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
