import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LIVE RUNTIME VERIFICATION — Community kategoriya UUID mapping.
///
/// Bu fayl mock EMAS: real Supabase Cloud'ga real HTTP so'rov yuboradi.
/// Kredensiallar `--dart-define-from-file` orqali kelmasa, test SKIP bo'ladi
/// (yolg'on "pass" bermaslik uchun har bir skip stdout'ga yoziladi).
///
/// ```
/// flutter test test/integration/community_category_uuid_live_verification_test.dart \
///   --dart-define-from-file=env/prod.json
/// ```
///
/// PRODUCTION'GA YOZISH XAVFI YO'Q:
/// INSERT tekshiruvida `category_id` sifatida ATAYLAB katalogda mavjud
/// BO'LMAGAN, lekin sintaktik to'g'ri uuid ishlatiladi. Shu sababli RLS
/// o'tib ketgan taqdirda ham FK (`questions_category_id_fkey`) buziladi va
/// qator YARATILMAYDI. Maqsad — 22P02 (uuid parse) xatosi YO'Qligini
/// isbotlash, qator qo'shish emas.
class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  /// Katalogda YO'Q, lekin to'g'ri shakldagi uuid (FK ataylab buziladi).
  const nonExistentCategoryUuid = '00000000-0000-4000-8000-0000000000ff';

  /// Foydalanuvchi tasdiqlagan live katalog (task matnidagi qiymatlar).
  const expectedLiveIds = <String, String>{
    'Mehnat huquqi': '9e25aeac-a6e0-4e0f-8262-02b06a714f42',
    'Oila huquqi': 'dc2f9dd9-e39a-4e1d-bca1-43918dccacc5',
    'Fuqarolik huquqi': 'de5ac785-59af-4eff-b1e1-25f8b4b47d56',
    'Jinoyat huquqi': '37fa5efe-8e12-44a4-8b80-d711bf844caf',
    "Ma'muriy huquqi": '90c62df7-93a7-4454-a767-94144ba05dea',
  };

  bool skipped(String testName) {
    if (SupabaseConfig.isConfigured) return false;
    stdout.writeln(
      'SKIPPED ($testName): real Supabase kredensiallari yo\'q — '
      "--dart-define-from-file=env/prod.json bilan ishga tushiring. "
      'BU TEST NATIJASI EVIDENCE EMAS.',
    );
    return true;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (_) {
      // Allaqachon initialize qilingan.
    }
    await Supabase.instance.client.auth.signOut();
  });

  group('LIVE 1 — public.categories katalogi', () {
    test('live jadval o\'qiladi va 5 ta real UUID beradi', () async {
      if (skipped('LIVE 1')) return;

      final rows = await Supabase.instance.client.from(kCategoriesTable).select();
      stdout.writeln('EVIDENCE: GET /rest/v1/$kCategoriesTable -> '
          '${rows.length} qator');
      expect(rows, isNotEmpty,
          reason: 'public.$kCategoriesTable bo\'sh bo\'lsa mapping imkonsiz');

      final catalog = QuestionCategoryCatalog.fromRows(rows);
      expect(catalog.isEmpty, isFalse);

      for (final name in kCommunityCategoryNames) {
        final id = catalog.requireId(name);
        stdout.writeln('EVIDENCE: "$name" -> $id');
        expect(QuestionCategoryCatalog.isUuid(id), isTrue, reason: name);
        expect(id, expectedLiveIds[name], reason: name);
      }
    });

    test('`question_categories` (eski jadval) katalog uchun yaroqsiz', () async {
      if (skipped('LIVE 1b')) return;

      List<dynamic>? rows;
      try {
        rows = await Supabase.instance.client
            .from('question_categories')
            .select();
      } on PostgrestException catch (e) {
        stdout.writeln('EVIDENCE: question_categories -> '
            'PostgrestException ${e.code}: ${e.message}');
      }

      if (rows != null) {
        stdout.writeln('EVIDENCE: GET /rest/v1/question_categories -> '
            '${rows.length} qator');
        final legacy = QuestionCategoryCatalog.fromRows(rows);
        // Root cause: bu jadvaldan "Mehnat huquqi" uchun ID topilmaydi.
        expect(legacy.resolveId('Mehnat huquqi'), isNull,
            reason: 'question_categories`dan ID topilsa root cause boshqa');
      }
    });
  });

  group('LIVE 2 — READ yo\'li (filtr)', () {
    test('display nom bilan xom filtr HALI HAM 22P02 beradi (negativ nazorat)',
        () async {
      if (skipped('LIVE 2a')) return;

      try {
        await Supabase.instance.client
            .from('questions')
            .select('id')
            .eq('category_id', 'Mehnat huquqi');
        fail('Nomni uuid ustuniga yuborish xato bermadi — '
            'root cause taxmini noto\'g\'ri');
      } on PostgrestException catch (e) {
        stdout.writeln('EVIDENCE: eq(category_id, "Mehnat huquqi") -> '
            '${e.code}: ${e.message}');
        expect(e.code, '22P02');
        expect(e.message, contains('invalid input syntax for type uuid'));
      }
    });

    test('rezolyutsiya qilingan UUID bilan filtr HTTP 200 beradi', () async {
      if (skipped('LIVE 2b')) return;

      final client = Supabase.instance.client;
      final catalog = QuestionCategoryCatalog.fromRows(
        await client.from(kCategoriesTable).select(),
      );
      final id = catalog.requireId('Mehnat huquqi');

      final rows = await client.from('questions').select('id').eq('category_id', id);
      stdout.writeln('EVIDENCE: eq(category_id, $id) -> OK, '
          '${rows.length} qator');
      expect(rows, isNotNull);
    });

    test('datasource.getPosts("Mehnat huquqi") 22P02 bermaydi', () async {
      if (skipped('LIVE 2c')) return;

      final ds = CommunityForumDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      );
      final posts = await ds.getPosts(category: 'Mehnat huquqi');
      stdout.writeln('EVIDENCE: getPosts("Mehnat huquqi") -> '
          '${posts.length} post (exception yo\'q)');
      expect(posts, isNotNull);
    });

    test('katalogda yo\'q nom -> 422 domain error (22P02 emas, mock ham emas)',
        () async {
      if (skipped('LIVE 2d')) return;

      final ds = CommunityForumDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      );
      try {
        final posts = await ds.getPosts(category: 'Kosmik huquq');
        fail('Noma\'lum kategoriya jimjitlikda o\'tib ketdi: '
            '${posts.length} post qaytdi');
      } on ServerException catch (e) {
        stdout.writeln('EVIDENCE: getPosts("Kosmik huquq") -> '
            'ServerException ${e.statusCode}: ${e.message}');
        expect(e.statusCode, 422);
        expect(e.details, isA<CategoryResolutionException>());
      }
    });
  });

  group('LIVE 3 — WRITE yo\'li (qator YARATMASDAN)', () {
    test('to\'g\'ri shakldagi uuid uuid-parse xatosini bermaydi', () async {
      if (skipped('LIVE 3a')) return;

      final payload = buildQuestionInsertPayload(
        userId: '00000000-0000-4000-8000-00000000000a',
        title: '[LIVE TYPE PROBE] o\'chirilmasin — qator yaratilmaydi',
        description: 'uuid parse tekshiruvi',
        aiSummary: 'probe',
        isAnonymous: true,
        categoryId: nonExistentCategoryUuid,
      );
      expect(payload['category_id'], nonExistentCategoryUuid);

      try {
        await Supabase.instance.client.from('questions').insert(payload);
        fail('Anon foydalanuvchi INSERT qila oldi — RLS va FK ikkisi ham '
            'o\'tib ketdi (bu alohida P0 xavfsizlik muammosi)');
      } on PostgrestException catch (e) {
        stdout.writeln('EVIDENCE: INSERT (uuid) -> ${e.code}: ${e.message}');
        // Kutilgan: 42501 (RLS) yoki 23503 (FK). MUHIMI: 22P02 EMAS.
        expect(e.code, isNot('22P02'),
            reason: 'uuid ustuniga yaroqsiz qiymat yuborilgan');
        expect(e.message, isNot(contains('invalid input syntax for type uuid')));
      }
    });

    test('display nom INSERT payloadiga umuman kirmaydi (HTTP yuborilmaydi)',
        () {
      // Bu tekshiruv kredensialsiz ham haqiqiy: guard local ishlaydi.
      expect(
        () => buildQuestionInsertPayload(
          userId: '00000000-0000-4000-8000-00000000000a',
          title: 'guard',
          description: 'guard',
          aiSummary: 'guard',
          isAnonymous: true,
          categoryId: 'Mehnat huquqi',
        ),
        throwsA(isA<CategoryResolutionException>()),
      );
      stdout.writeln('EVIDENCE: buildQuestionInsertPayload("Mehnat huquqi") -> '
          'CategoryResolutionException (DB\'ga yetib bormaydi)');
    });

    test('autentifikatsiyasiz createQuestion 401 bilan to\'xtaydi', () async {
      if (skipped('LIVE 3c')) return;

      final ds = CommunityForumDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      );
      try {
        await ds.createQuestion(
          title: '[LIVE PROBE] anon',
          rawQuestion: 'anon',
          category: 'Mehnat huquqi',
          isAnonymous: true,
          authorName: 'Anonim fuqaro',
        );
        fail('Anon createQuestion o\'tib ketdi');
      } on ServerException catch (e) {
        stdout.writeln('EVIDENCE: anon createQuestion -> '
            '${e.statusCode}: ${e.message}');
        expect(e.statusCode, 401);
      }
    });
  });
}
