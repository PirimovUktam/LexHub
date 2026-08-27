import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';

/// P0 regression guard — Community kategoriya mapping.
///
/// REAL DEVICE evidence (2026-08-22, production APK):
///   PostgreSQL 22P02: invalid input syntax for type uuid: "Mehnat huquqi"
///
/// LIVE CLOUD evidence (2026-08-22, prod anon key, PostgREST):
///   GET /rest/v1/categories?select=*            -> HTTP 200, 5 qator
///   GET /rest/v1/question_categories?select=*   -> HTTP 200, [] (BO'SH)
///   GET /rest/v1/questions?category_id=eq.Mehnat%20huquqi
///                                               -> HTTP 400 / 22P02
///   GET /rest/v1/questions?category_id=eq.9e25aeac-...  -> HTTP 200
///
/// INVARIANT: UI faqat kategoriya NOMINI ko'rsatadi, lekin
/// `questions.category_id` ustuniga faqat `public.categories`dan olingan
/// real UUID yuboriladi.
void main() {
  // Real device'da xatoga sabab bo'lgan aynan shu qiymat.
  const badValue = 'Mehnat huquqi';

  // LIVE `public.categories` qatorlari (haqiqiy UUID'lar).
  const laborUuid = '9e25aeac-a6e0-4e0f-8262-02b06a714f42';
  const familyUuid = 'dc2f9dd9-e39a-4e1d-bca1-43918dccacc5';
  const civilUuid = 'de5ac785-59af-4eff-b1e1-25f8b4b47d56';
  const criminalUuid = '37fa5efe-8e12-44a4-8b80-d711bf844caf';
  const adminUuid = '90c62df7-93a7-4454-a767-94144ba05dea';

  /// Live cloud javobining aynan nusxasi (`icon`/`description` ham bor).
  /// Diqqat: "Maʼmuriy huquqi" ichida U+02BC MODIFIER LETTER APOSTROPHE.
  QuestionCategoryCatalog liveCatalog() =>
      QuestionCategoryCatalog.fromRows(<dynamic>[
        <String, dynamic>{
          'id': laborUuid,
          'name': 'Mehnat huquqi',
          'slug': 'labor-law',
          'description': 'Ishga oid huquqiy masalalar',
          'icon': null,
        },
        <String, dynamic>{
          'id': familyUuid,
          'name': 'Oila huquqi',
          'slug': 'family-law',
          'description': 'Nikoh, ajrim, voyaga yetmaganlar',
          'icon': null,
        },
        <String, dynamic>{
          'id': civilUuid,
          'name': 'Fuqarolik huquqi',
          'slug': 'civil-law',
          'icon': null,
        },
        <String, dynamic>{
          'id': criminalUuid,
          'name': 'Jinoyat huquqi',
          'slug': 'criminal-law',
          'icon': null,
        },
        <String, dynamic>{
          'id': adminUuid,
          'name': 'Maʼmuriy huquqi',
          'slug': 'administrative-law',
          'icon': null,
        },
      ]);

  group('1-7. Task talab qilgan mapping holatlari', () {
    test('1. "Mehnat huquqi" -> haqiqiy UUID', () {
      expect(liveCatalog().resolveId(badValue), laborUuid);
      expect(liveCatalog().requireId(badValue), laborUuid);
    });

    test('2. "Oila huquqi" -> haqiqiy UUID', () {
      expect(liveCatalog().resolveId('Oila huquqi'), familyUuid);
      expect(liveCatalog().requireId('Oila huquqi'), familyUuid);
    });

    test('3. "  Mehnat huquqi  " -> to\'g\'ri UUID', () {
      expect(liveCatalog().resolveId('  Mehnat huquqi  '), laborUuid);
      expect(liveCatalog().resolveId('  MEHNAT   HUQUQI '), laborUuid);
    });

    test('4. apostrof variantlari normalize qilinadi', () {
      final catalog = liveCatalog();
      // Live qiymat U+02BC (ʼ). UI/klaviatura boshqa variant bersa ham
      // bir xil UUID chiqishi shart.
      expect(catalog.resolveId('Maʼmuriy huquqi'), adminUuid); // U+02BC
      expect(catalog.resolveId("Ma'muriy huquqi"), adminUuid); // ASCII '
      expect(catalog.resolveId('Ma’muriy huquqi'), adminUuid); // U+2019
      expect(catalog.resolveId('Maʻmuriy huquqi'), adminUuid); // U+02BB
      expect(catalog.resolveId('  maʼmuriy   HUQUQI '), adminUuid);
    });

    test('5. UUID input o\'zgarmasdan qaytadi', () {
      const empty = QuestionCategoryCatalog.empty();
      expect(empty.resolveId(laborUuid), laborUuid);
      expect(empty.resolveId('  $laborUuid  '), laborUuid);
      expect(empty.resolveId(laborUuid.toUpperCase()), laborUuid.toUpperCase());
      expect(liveCatalog().requireId(criminalUuid), criminalUuid);
    });

    test('6. noma\'lum kategoriya -> null / aniq error', () {
      final catalog = liveCatalog();
      // Eski UI ro'yxatida bor, katalogda YO'Q nomlar.
      const notInCatalog = <String>[
        "Yo'l harakati",
        "Ma'muriy jarimalar",
        "Iste'molchi huquqi",
        'Uy-joy va kadastr',
        'Bank va kredit',
        'Soliq masalalari',
        'Fuqarolik',
        'Kadastr va Uy-joy',
        'Soliq',
        'Kosmik huquq',
      ];
      for (final name in notInCatalog) {
        expect(catalog.resolveId(name), isNull, reason: name);
        expect(
          () => catalog.requireId(name),
          throwsA(isA<CategoryResolutionException>()),
          reason: name,
        );
      }
    });

    test('7. "Mehnat huquqi" hech qachon payloadga category_id bo\'lib '
        'tushmaydi', () {
      // (a) rezolyutsiya qilinganda -> UUID tushadi
      final good = _payloadWith(liveCatalog().requireId(badValue));
      expect(good['category_id'], laborUuid);
      expect(good['category_id'].toString().contains(' '), isFalse);

      // (b) resolver chetlab o'tilsa -> jimjitlikda tashlanmaydi, ERROR
      expect(
        () => _payloadWith(badValue),
        throwsA(isA<CategoryResolutionException>()),
      );
    });
  });

  group('UI ro\'yxati <-> live katalog drift qo\'riqchisi', () {
    test('kCommunityCategoryNames dagi HAR BIR nom real UUID ga aylanadi', () {
      final catalog = liveCatalog();
      expect(kCommunityCategoryNames, isNotEmpty);
      for (final name in kCommunityCategoryNames) {
        final id = catalog.resolveId(name);
        expect(id, isNotNull, reason: 'UI nomi katalogda yo\'q: $name');
        expect(QuestionCategoryCatalog.isUuid(id!), isTrue, reason: name);
      }
    });

    test('kCommunityCategoryNames live katalogning 5 ta nomini qoplaydi', () {
      final catalog = liveCatalog();
      final resolved =
          kCommunityCategoryNames.map(catalog.resolveId).toSet();
      expect(resolved, <String>{
        laborUuid,
        familyUuid,
        civilUuid,
        criminalUuid,
        adminUuid,
      });
    });

    test('filtr ro\'yxati "Barchasi" + real nomlar', () {
      expect(kCommunityFilterCategories.first, kAllCategoriesLabel);
      expect(kCommunityFilterCategories.sublist(1), kCommunityCategoryNames);
      final catalog = liveCatalog();
      for (final label in kCommunityFilterCategories.sublist(1)) {
        expect(catalog.resolveId(label), isNotNull, reason: label);
      }
    });

    test('katalog jadvali `categories` (question_categories EMAS)', () {
      expect(kCategoriesTable, 'categories');
    });
  });

  group('isAllCategories — filtr yo\'q holati', () {
    test('null / bo\'sh / "Barchasi" -> true', () {
      expect(QuestionCategoryCatalog.isAllCategories(null), isTrue);
      expect(QuestionCategoryCatalog.isAllCategories(''), isTrue);
      expect(QuestionCategoryCatalog.isAllCategories('   '), isTrue);
      expect(QuestionCategoryCatalog.isAllCategories(kAllCategoriesLabel),
          isTrue);
    });

    test('real nom -> false', () {
      expect(QuestionCategoryCatalog.isAllCategories(badValue), isFalse);
      expect(QuestionCategoryCatalog.isAllCategories(laborUuid), isFalse);
    });

    test('resolveId "Barchasi"/bo\'sh uchun null qaytaradi', () {
      final catalog = liveCatalog();
      expect(catalog.resolveId(null), isNull);
      expect(catalog.resolveId(''), isNull);
      expect(catalog.resolveId(kAllCategoriesLabel), isNull);
    });

    test('requireId "Barchasi"/null uchun ERROR (ID yo\'q, taxmin yo\'q)', () {
      final catalog = liveCatalog();
      expect(() => catalog.requireId(null),
          throwsA(isA<CategoryResolutionException>()));
      expect(() => catalog.requireId(kAllCategoriesLabel),
          throwsA(isA<CategoryResolutionException>()));
    });
  });

  group('fromRows — bo\'sh katalog va schema drift', () {
    test('question_categories BO\'SH bo\'lgan holat (live evidence): '
        'nom ID sifatida qaytmaydi', () {
      // `GET /rest/v1/question_categories` -> [] bo'lgani uchun eski
      // implementatsiya aynan shu holatda ishlagan.
      final emptyTable = QuestionCategoryCatalog.fromRows(<dynamic>[]);
      expect(emptyTable.isEmpty, isTrue);
      expect(emptyTable.resolveId(badValue), isNull);
      expect(() => emptyTable.requireId(badValue),
          throwsA(isA<CategoryResolutionException>()));
    });

    test('name_uz / name_ru ustunlari ham qo\'llanadi (repo schema drift)', () {
      final catalog = QuestionCategoryCatalog.fromRows(<dynamic>[
        <String, dynamic>{
          'id': laborUuid,
          'name_uz': 'Mehnat huquqi',
          'name_ru': 'Трудовое право',
          'slug': 'labor',
        },
      ]);
      expect(catalog.resolveId(badValue), laborUuid);
      expect(catalog.resolveId('Трудовое право'), laborUuid);
      expect(catalog.resolveId('labor'), laborUuid);
      expect(catalog.displayNameFor(laborUuid), 'Mehnat huquqi');
    });

    test('slug ham nom sifatida resolve qiladi (live: labor-law)', () {
      final catalog = liveCatalog();
      expect(catalog.resolveId('labor-law'), laborUuid);
      expect(catalog.resolveId('ADMINISTRATIVE-LAW'), adminUuid);
    });

    test('buzilgan qatorlar (Map emas / id yo\'q / bo\'sh id) tashlanadi', () {
      final catalog = QuestionCategoryCatalog.fromRows(<dynamic>[
        'not-a-map',
        <String, dynamic>{'name': 'ID yo\'q'},
        <String, dynamic>{'id': '', 'name': 'Bo\'sh ID'},
        <String, dynamic>{'id': laborUuid, 'name': 'Mehnat huquqi'},
      ]);
      expect(catalog.knownIds, <String>[laborUuid]);
      expect(catalog.resolveId(badValue), laborUuid);
    });

    test('displayNameFor: uuid -> nom, noma\'lum -> null', () {
      final catalog = liveCatalog();
      expect(catalog.displayNameFor(laborUuid), 'Mehnat huquqi');
      expect(catalog.displayNameFor(adminUuid), 'Maʼmuriy huquqi');
      expect(catalog.displayNameFor('11111111-2222-4333-8444-555555555555'),
          isNull);
      expect(catalog.displayNameFor(null), isNull);
      expect(catalog.displayNameFor('  '), isNull);
    });

    test('katalogdagi slug-ID sxemasi o\'zgarmasdan o\'tadi', () {
      final slugCatalog = QuestionCategoryCatalog.fromRows(<dynamic>[
        <String, dynamic>{'id': 'labor', 'name': 'Mehnat huquqi'},
      ]);
      expect(slugCatalog.resolveId('labor'), 'labor');
      expect(slugCatalog.requireId(badValue), 'labor');
      expect(_payloadWith('labor')['category_id'], 'labor');
    });
  });

  group('buildQuestionInsertPayload — invariantning yakuniy qo\'riqchisi', () {
    test('real UUID yoziladi va trim qilinadi', () {
      expect(_payloadWith(laborUuid)['category_id'], laborUuid);
      expect(_payloadWith('  $familyUuid  ')['category_id'], familyUuid);
      expect(_payloadWith(laborUuid.toUpperCase())['category_id'],
          laborUuid.toUpperCase());
    });

    test('category_id kaliti HAR DOIM mavjud (jimjitlikda tashlanmaydi)', () {
      final payload = _payloadWith(laborUuid);
      expect(payload.containsKey('category_id'), isTrue);
      expect(payload['status'], 'open');
      expect(payload['user_id'], isNotEmpty);
      expect(payload['is_anonymous'], isTrue);
    });

    test('bo\'sh qiymat -> ERROR', () {
      expect(() => _payloadWith(''),
          throwsA(isA<CategoryResolutionException>()));
      expect(() => _payloadWith('   '),
          throwsA(isA<CategoryResolutionException>()));
    });

    test('display nom (bo\'shliqli) -> ERROR, 22P02 ga yetib bormaydi', () {
      const displayNames = <String>[
        'Mehnat huquqi',
        'Oila huquqi',
        'Fuqarolik huquqi',
        'Jinoyat huquqi',
        "Ma'muriy huquqi",
        'Maʼmuriy huquqi',
        "Yo'l harakati",
        'Bank va kredit',
      ];
      for (final name in displayNames) {
        expect(() => _payloadWith(name),
            throwsA(isA<CategoryResolutionException>()), reason: name);
      }
    });

    test('bo\'shliqsiz display nom ham (Fuqarolik/Soliq) -> ERROR', () {
      // Bir so'zli nom "ID ga o'xshab" o'tib ketmasligi kerak.
      for (final name in <String>['Fuqarolik', 'Soliq', 'Barchasi', 'Umumiy']) {
        expect(() => _payloadWith(name),
            throwsA(isA<CategoryResolutionException>()), reason: name);
      }
    });

    test('UI ro\'yxatidagi har bir nom uchun payload UUID bilan quriladi', () {
      final catalog = liveCatalog();
      for (final name in kCommunityCategoryNames) {
        final payload = _payloadWith(catalog.requireId(name));
        final value = payload['category_id'] as String;
        expect(QuestionCategoryCatalog.isUuid(value), isTrue, reason: name);
        expect(value.contains(' '), isFalse, reason: name);
      }
    });
  });

  group('questions.body NOT NULL — real device 23502 qo\'riqchisi', () {
    // REAL DEVICE evidence (2026-08-22, release APK):
    //   null value in column "body" of relation "questions"
    //   violates not-null constraint
    test('valid title + valid body -> payloadda body mavjud', () {
      final payload = _payloadWith(laborUuid,
          title: 'Dam olish kunida ishlash', body: 'Yakshanba kuni majburan '
              'ishga chiqishni talab qilmoqda.');
      expect(payload.containsKey('body'), isTrue);
      expect(payload['body'], 'Yakshanba kuni majburan ishga chiqishni '
          'talab qilmoqda.');
      expect(payload['title'], 'Dam olish kunida ishlash');
      expect(payload['category_id'], laborUuid);
    });

    test('body = "test" -> insert payloadda body mavjud', () {
      final payload = _payloadWith(laborUuid, body: 'test');
      expect(payload['body'], 'test');
    });

    test('body = "" -> client-side rejection (PostgREST\'ga bormaydi)', () {
      expect(
        () => _payloadWith(laborUuid, body: ''),
        throwsA(isA<QuestionContentException>()),
      );
    });

    test('body faqat bo\'shliq/newline -> client-side rejection', () {
      for (final raw in <String>['   ', '\n', '\t\t', '  \n  \t ']) {
        expect(
          () => _payloadWith(laborUuid, body: raw),
          throwsA(isA<QuestionContentException>()),
          reason: 'raw=${raw.codeUnits}',
        );
      }
    });

    test('body trim qilinadi va kamida 1 belgi qoladi', () {
      final payload = _payloadWith(laborUuid, body: '  a  ');
      expect(payload['body'], 'a');
      expect((payload['body'] as String).trim().isNotEmpty, isTrue);
    });

    test('xato `body` maydonini aniq ko\'rsatadi (silent fallback yo\'q)', () {
      try {
        _payloadWith(laborUuid, body: '   ');
        fail('bo\'sh body o\'tib ketdi');
      } on QuestionContentException catch (e) {
        expect(e.field, 'body');
        expect(e.message, contains('body'));
        expect(e.message, isNotEmpty);
      }
    });

    test('body HAR BIR matn ustuniga yoziladi (live schema drift)', () {
      final payload = _payloadWith(laborUuid, body: 'Savol matni');
      expect(kQuestionTextColumns, contains('body'));
      for (final column in kQuestionTextColumns) {
        expect(payload[column], 'Savol matni', reason: column);
      }
      // View `description`/`anonymized_question` ni o'qiydi.
      expect(payload['description'], 'Savol matni');
      expect(payload['anonymized_question'], 'Savol matni');
      expect(payload['content'], 'Savol matni');
    });

    test('title bo\'sh -> ERROR (title ham NOT NULL)', () {
      expect(
        () => _payloadWith(laborUuid, title: ''),
        throwsA(isA<QuestionContentException>()),
      );
      expect(
        () => _payloadWith(laborUuid, title: '    '),
        throwsA(isA<QuestionContentException>()),
      );
    });

    test('juda uzun title 255 belgiga qisqartiriladi (22001 oldini oladi)', () {
      final payload = _payloadWith(laborUuid, title: 'A' * 400);
      expect((payload['title'] as String).length, kQuestionTitleMaxLength);
      // Savol matni QISQARTIRILMAYDI — faqat sarlavha.
      expect(payload['body'], isNotEmpty);
    });

    test('body invarianti kategoriya invariantini buzmaydi', () {
      // Ikki qo'riqchi birga ishlaydi: kategoriya avval tekshiriladi.
      expect(
        () => _payloadWith('Mehnat huquqi', body: 'to\'g\'ri matn'),
        throwsA(isA<CategoryResolutionException>()),
      );
      expect(
        () => _payloadWith('Mehnat huquqi', body: ''),
        throwsA(isA<CategoryResolutionException>()),
      );
      // Kategoriya to'g'ri, matn bo'sh -> content xatosi.
      expect(
        () => _payloadWith(laborUuid, body: ''),
        throwsA(isA<QuestionContentException>()),
      );
    });

    test('har bir UI kategoriyasi uchun body + uuid birga to\'g\'ri', () {
      final catalog = liveCatalog();
      for (final name in kCommunityCategoryNames) {
        final payload = _payloadWith(catalog.requireId(name), body: 'matn');
        expect(QuestionCategoryCatalog.isUuid(payload['category_id'] as String),
            isTrue, reason: name);
        expect(payload['body'], 'matn', reason: name);
      }
    });
  });

  group('source-level guard', () {
    const dsPath =
        'lib/features/community_forum/data/datasources/'
        'community_forum_remote_datasource.dart';
    const dialogPath =
        'lib/features/community_forum/presentation/widgets/'
        'ask_community_dialog.dart';
    const pagePath =
        'lib/features/community_forum/presentation/pages/'
        'community_forum_page.dart';

    String read(String p) => File(p).readAsStringSync();

    /// Kod (izohlarsiz) — `question_categories` faqat izohda tushuntirish
    /// sifatida qolishi mumkin, jadval nomi sifatida esa YO'Q.
    String codeOnly(String source) => source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('datasource `category_id`ga xom `category`ni yubormaydi', () {
      final source = read(dsPath);
      expect(source.contains("'category_id': category"), isFalse,
          reason: 'Display name FK ustuniga qaytib kelgan (22P02 regressiyasi)');
      expect(source.contains("eq('category_id', category)"), isFalse,
          reason: "O'qish filtri nomni uuid ustuniga yuborayapti");
      expect(source.contains('buildQuestionInsertPayload'), isTrue);
      expect(source.contains('_requireCategoryId'), isTrue);
    });

    test('community implementatsiyasida `question_categories` QOLMAGAN', () {
      final dir = Directory('lib/features/community_forum');
      final offenders = <String>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (codeOnly(f.readAsStringSync()).contains('question_categories')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Live cloud`da question_categories BO\'SH; to\'g\'ri jadval '
              'public.categories');
    });

    test('katalog `categories` jadvalidan o\'qiladi', () {
      final source = read(dsPath);
      // `db(...)` — retry'siz DB kirishi (`lib/core/network/supabase_db.dart`).
      expect(source.contains('db(kCategoriesTable)'), isTrue);
    });

    test('kategoriya xatosi mock post bilan yashirilmaydi', () {
      final source = read(dsPath);
      // getPosts endi ServerException'ni rethrow qiladi.
      expect(source.contains('on ServerException {'), isTrue);
      expect(source.contains('rethrow;'), isTrue);
      // `catch (_) { return _fallbackPosts; }` shakli yo'q.
      expect(source.contains('return _fallbackPosts;\n    }'), isFalse);
    });

    test('home_page`dagi ikkinchi call site xatoni yutmaydi', () {
      // Bu joy BLoC'dan o'tmaydi: 422/503 SnackBar bilan ko'rsatilishi shart,
      // aks holda strict error policy jimjitlikda yo'qoladi.
      final home =
          read('lib/features/home/presentation/pages/home_page.dart');
      final idx = home.indexOf('onPostSubmitted: (newPost) async {');
      expect(idx, isNot(-1), reason: 'call site topilmadi');
      final block = home.substring(idx, idx + 1500);
      expect(block.contains('createQuestion('), isTrue);
      expect(block.contains('try {'), isTrue);
      expect(block.contains('catch (e)'), isTrue);
      expect(block.contains('showSnackBar'), isTrue);
      expect(block.contains('e is ServerException'), isTrue);
    });

    /// `createQuestion` IMPLEMENTATSIYASI (abstract deklaratsiya emas —
    /// shuning uchun `lastIndexOf`) va uning tanasi.
    String createQuestionBody(String source) {
      final start =
          source.lastIndexOf('Future<CommunityPostModel> createQuestion(');
      expect(start, isNot(-1), reason: 'createQuestion implementatsiyasi yo\'q');
      final end = source.indexOf(
          'Future<CommunityPostModel> votePost(String postId) async {', start);
      expect(end, isNot(-1), reason: 'createQuestion oxirini topib bo\'lmadi');
      return source.substring(start, end);
    }

    test('datasource `body` invariantini 422 ga map qiladi (23502 emas)', () {
      final source = read(dsPath);
      expect(source.contains('on QuestionContentException catch (e)'), isTrue,
          reason: 'body/title NOT NULL xatosi domain error sifatida '
              'ko\'rsatilmasa, foydalanuvchi xom 23502 matnini ko\'radi');
      expect(source.contains('statusCode: 422'), isTrue);
      // `questions` INSERT payloadi FAQAT qo'riqchi funksiyadan quriladi —
      // inline map (body kalitini tushirib qoldirgan eski shakl) qaytmasin.
      final block = createQuestionBody(source);
      expect(block.contains('buildQuestionInsertPayload('), isTrue);
      // Eski (`from`) shakl ham qidiriladi — qo'riqchi uslub o'zgarishi bilan
      // jimgina o'lib qolmasligi kerak.
      expect(RegExp(r"\.(?:from|db)\('questions'\)\.insert\(\{").hasMatch(block),
          isFalse,
          reason: 'inline insert map qaytdi — body kaliti yana tushib '
              'qolishi mumkin');
    });

    test('savol matni yoziladigan ustunlar ro\'yxatida `body` bor', () {
      final source =
          read('lib/features/community_forum/data/datasources/'
              'question_category_resolver.dart');
      expect(source.contains("'body',"), isTrue);
      expect(kQuestionTextColumns, contains('body'));
      expect(kQuestionTextColumns, contains('description'));
      expect(kQuestionTextColumns, contains('anonymized_question'));
    });

    test('createQuestion muvaffaqiyatli insert\'dan keyin mock qaytarmaydi',
        () {
      // Insert bo'lgan, lekin read-back yiqilgan holatda `getPostById`
      // `_fallbackPosts.first` (mock) qaytarardi — yangi savol o'rniga
      // mock post ko'rsatilishi TAQIQLANGAN.
      final block = createQuestionBody(read(dsPath));
      expect(block.contains('_fallbackPosts'), isFalse);
      expect(block.contains('return getPostById('), isFalse);
      expect(block.contains('CommunityPostModel.fromJson(row'), isTrue);
    });

    test('dialog savol matni bo\'sh bo\'lsa yubormaydi', () {
      final dialog = read(dialogPath);
      expect(dialog.contains('if (text.isEmpty)'), isTrue,
          reason: 'UI darajasidagi birinchi qo\'riqchi olib tashlangan');
      expect(dialog.contains('anonymizedQuestion: sanitized'), isTrue);
    });

    test('UI ro\'yxatlari umumiy konstantadan olinadi (hardcode yo\'q)', () {
      final dialog = read(dialogPath);
      final page = read(pagePath);
      expect(dialog.contains('kCommunityCategoryNames'), isTrue);
      expect(page.contains('kCommunityFilterCategories'), isTrue);
      // Katalogda yo'q eski nomlar UI'da qolmagan.
      for (final stale in <String>[
        "Yo'l harakati",
        "Ma'muriy jarimalar",
        "Iste'molchi huquqi",
        'Bank va kredit',
        'Soliq masalalari',
        'Uy-joy va kadastr',
        'Kadastr va Uy-joy',
      ]) {
        expect(dialog.contains('"$stale"'), isFalse, reason: stale);
        expect(page.contains('"$stale"'), isFalse, reason: stale);
      }
    });

    // ---- questions_user_id_fkey (23503) qo'riqchilari ----

    test('createQuestion insert\'dan OLDIN profil borligini tekshiradi', () {
      final block = createQuestionBody(read(dsPath));
      final guard = block.indexOf('_requireProfileExists(');
      final insert = block.indexOf("db('questions').insert(");
      expect(guard, isNot(-1),
          reason: 'profil pre-flight qo\'riqchisi yo\'q — foydalanuvchi xom '
              '"questions_user_id_fkey" matnini ko\'radi');
      expect(insert, isNot(-1));
      expect(guard < insert, isTrue,
          reason: 'tekshiruv insert\'dan KEYIN bajarilmasligi kerak');
    });

    test('datasource profil yo\'qligini 409 ga map qiladi', () {
      final source = read(dsPath);
      expect(source.contains('on ProfileMissingException catch (e)'), isTrue);
      expect(source.contains('statusCode: 409'), isTrue);
      expect(source.contains('isQuestionUserFkViolation('), isTrue,
          reason: '23503 xom holda chiqmasligi kerak');
    });

    test('client HECH QACHON profil qatori yaratmaydi (fake profile yo\'q)',
        () {
      // Foydalanuvchi talabi §6: "fake profile yaratma". `profiles.role` —
      // RBAC yuzasi, client'dan INSERT privilege escalation ochadi.
      final profileWrite =
          RegExp(r"\.(?:from|db)\('profiles'\)\.(?:insert|upsert)");
      for (final path in <String>[
        dsPath,
        'lib/features/auth/data/datasources/auth_remote_datasource.dart',
      ]) {
        final code = codeOnly(read(path));
        expect(profileWrite.hasMatch(code), isFalse, reason: path);
      }
    });

    test('getUserProfile sun\'iy profil qaytarmaydi', () {
      final auth =
          read('lib/features/auth/data/datasources/auth_remote_datasource.dart');
      expect(auth.contains('Fallback default profile'), isFalse,
          reason: 'sun\'iy profil mavjud bo\'lmagan DB qatorini borday '
              'ko\'rsatib, FK buzilishini yashiradi');
      expect(auth.contains('statusCode: 404'), isTrue);
      expect(auth.contains('if (e is ServerException) rethrow;'), isTrue,
          reason: 'aniq 404 tashqi catch tomonidan qayta o\'ralmasligi kerak');
    });
  });

  group('isQuestionUserFkViolation', () {
    test('real device xabarini aniqlaydi', () {
      expect(
        isQuestionUserFkViolation(
          code: '23503',
          message: 'insert or update on table "questions" violates foreign '
              'key constraint "questions_user_id_fkey"',
        ),
        isTrue,
      );
    });

    test('constraint nomi kod bo\'lmasa ham yetarli', () {
      expect(
        isQuestionUserFkViolation(
          message: 'violates foreign key constraint "questions_user_id_fkey"',
        ),
        isTrue,
      );
    });

    test('category FK buzilishini user FK deb hisoblamaydi', () {
      expect(
        isQuestionUserFkViolation(
          code: '23503',
          message: 'insert or update on table "questions" violates foreign '
              'key constraint "questions_category_id_fkey"',
        ),
        isFalse,
      );
    });

    test('boshqa xato kodlari rad etiladi', () {
      expect(
        isQuestionUserFkViolation(
          code: '23502',
          message: 'null value in column "body" violates not-null constraint',
        ),
        isFalse,
      );
      expect(isQuestionUserFkViolation(code: '23503', message: ''), isFalse);
      expect(isQuestionUserFkViolation(), isFalse);
    });
  });
}

Map<String, dynamic> _payloadWith(
  String categoryId, {
  String title = 'Test savol',
  String body = 'Test tavsif',
}) =>
    buildQuestionInsertPayload(
      userId: '99999999-8888-4777-8666-555555555555',
      title: title,
      description: body,
      aiSummary: 'Test xulosa',
      isAnonymous: true,
      categoryId: categoryId,
    );
