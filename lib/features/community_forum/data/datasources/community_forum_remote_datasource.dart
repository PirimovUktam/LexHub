/// TIMEOUT YUTILMAYDI (bu fayldagi barcha generic `catch (e)` uchun).
///
/// Bu datasource'ning har bir shoxi xatoni `ServerException` ga o'rab
/// tashlaydi. `TimeoutException` ham shu yo'lga tushsa ikki nuqson yuzaga
/// keladi: (1) `ErrorHandler` `FailureCode.server` beradi, ya'ni ingliz UI
/// ARB'dan "Server javob bermadi" matnini TANLAY OLMAYDI; (2) ba'zi shoxlar
/// `e.toString()` ni foydalanuvchi ko'radigan `message` ga qo'shadi, ya'ni
/// ekranga XOM `TimeoutException after 0:00:20.000000: rest/v1/...` chiqadi.
/// Shu sababli har bir generic shoxda timeout QAYTA OTILADI —
/// `lib/core/network/timeout_http_client.dart` qo'ygan chegara UI'ga to'g'ri
/// `FailureCode.timeout` bo'lib yetib boradi.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/community_forum/data/datasources/answer_schema.dart';
import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:lexhub/features/community_forum/data/models/community_post_model.dart';
import 'package:lexhub/features/community_forum/data/models/question_answer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CommunityForumDataSource {
  Future<List<CommunityPostModel>> getPosts({String? category, String? searchQuery});
  Future<CommunityPostModel> getPostById(String postId);
  Future<CommunityPostModel> createQuestion({
    required String title,
    required String rawQuestion,
    required String category,
    required bool isAnonymous,
    required String authorName,
  });
  Future<CommunityPostModel> votePost(String postId);
  Future<QuestionAnswerModel> addAnswer({
    required String postId,
    required String content,
    required String authorName,
    required bool isExpert,
    String? authorRole,
  });
  Future<QuestionAnswerModel> voteAnswer(String answerId);
  Future<void> acceptAnswer({
    required String questionId,
    required String answerId,
  });
}

class CommunityForumDataSourceImpl implements CommunityForumDataSource {
  final SupabaseClient supabaseClient;

  CommunityForumDataSourceImpl({required this.supabaseClient});

  /// `public.categories` snapshot'i (session davomida bir marta o'qiladi).
  ///
  /// LIVE EVIDENCE (2026-08-22, prod anon key):
  ///   GET /rest/v1/categories?select=* -> HTTP 200, 5 qator
  ///   (id uuid, name, slug, description, icon, created_at)
  ///
  /// `question_categories` ATAYLAB ishlatilmaydi: live cloud'da u bo'sh va
  /// `questions.category_id` FK'si `public.categories(id)`ga qaraydi.
  QuestionCategoryCatalog? _categoryCatalogCache;

  /// DOIMIY nosozlik memoizatsiyasi (sxema/parse xatosi kabi): qayta urinish
  /// ayni natijani beradi, shuning uchun so'rov takrorlanmaydi.
  Object? _categoryCatalogError;

  /// OXIRGI nosozlik — memoizatsiyadan MUSTAQIL. `_requireCategoryId` aynan
  /// shu qiymatga qarab timeout'ni qayta otadi, ya'ni UI umumiy "katalog
  /// o'qilmadi" xabari o'rniga `FailureCode.timeout` oladi.
  Object? _lastCategoryCatalogFailure;

  /// Katalogni o'qiydi. O'qilmasa `null`.
  Future<QuestionCategoryCatalog?> _loadCategoryCatalog() async {
    final cached = _categoryCatalogCache;
    if (cached != null) return cached;
    if (_categoryCatalogError != null) return null;

    try {
      final rows = await supabaseClient.db(kCategoriesTable).select();
      return _categoryCatalogCache = QuestionCategoryCatalog.fromRows(rows);
    } catch (e) {
      _lastCategoryCatalogFailure = e;
      // TIMEOUT MEMOIZATSIYA QILINMAYDI: u O'TKINCHI nosozlik. Ilgari har
      // qanday xato umrbod eslab qolinardi — ya'ni ilova ochilishida tarmoq
      // bir marta sekin bo'lsa, foydalanuvchi shu sessiyada BOSHQA HECH
      // QACHON savol joylay olmasdi (`_requireCategoryId` doim yiqilardi),
      // tarmoq tiklanganda ham. Doimiy xatolar (sxema/parse) esa eslab
      // qolinadi, aks holda har bir operatsiya bir xil so'rovni qaytarardi.
      if (e is! TimeoutException) _categoryCatalogError = e;
      if (kDebugMode) {
        debugPrint('[community] kategoriya katalogi o\'qilmadi: $e');
      }
      return null;
    }
  }

  /// FAQAT display uchun: katalog o'qilmasa ham feed yiqilmaydi (nom
  /// o'rniga `Umumiy` ko'rsatiladi). Bu ma'lumot butunligiga ta'sir qilmaydi.
  Future<QuestionCategoryCatalog> _displayCatalog() async =>
      await _loadCategoryCatalog() ?? const QuestionCategoryCatalog.empty();

  /// FK yozish / filtrlash uchun: katalog MAJBURIY.
  ///
  /// Topilmasa aniq domain error qaytaradi — nom hech qachon `category_id`ga
  /// yuborilmaydi va jimjitlikda tashlab ketilmaydi.
  Future<String> _requireCategoryId(String? category) async {
    final catalog = await _loadCategoryCatalog();
    if (catalog == null) {
      // Sabab TIMEOUT bo'lsa, uni o'z shaklida uzatamiz: `ServerException`
      // ga o'ralsa `FailureCode.server` bo'lib qolardi va foydalanuvchi
      // "server nosoz" degan XATO xulosaga kelardi — vaholanki so'rov
      // shunchaki chegaradan o'tgan.
      final failure = _lastCategoryCatalogFailure;
      if (failure is TimeoutException) throw failure;
      throw ServerException(
        message: "Kategoriyalar katalogini (public.$kCategoriesTable) "
            "o'qib bo'lmadi, shuning uchun kategoriya ID'sini aniqlash "
            "imkonsiz. Tarmoqni tekshirib qayta urinib ko'ring.",
        statusCode: 503,
        details: _categoryCatalogError ?? failure,
      );
    }
    try {
      return catalog.requireId(category);
    } on CategoryResolutionException catch (e) {
      throw ServerException(message: e.message, statusCode: 422, details: e);
    }
  }

  /// Savol yozishdan OLDIN `public.profiles` ichida joriy user uchun qator
  /// borligini tekshiradi.
  ///
  /// Nima uchun kerak: `questions.user_id` FK'si `public.profiles(id)`ga
  /// ishora qiladi (live'da `select=id,profiles!questions_user_id_fkey(id)`
  /// -> HTTP 200 bilan tasdiqlangan). Profil qatori bo'lmasa PostgreSQL 23503
  /// qaytaradi va foydalanuvchi tushunarsiz constraint nomini ko'radi.
  ///
  /// MUHIM cheklovlar:
  ///  * Profil bu yerda YARATILMAYDI — `profiles.role` RBAC yuzasi, uni
  ///    client'dan to'ldirish privilege escalation xavfini ochadi.
  ///  * SELECT o'zi xato bersa (tarmoq / RLS) — savol yaratish TO'XTATILMAYDI.
  ///    Bu holda hakam DB bo'ladi: insert 23503 bersa, catch bloki aynan shu
  ///    xabarni beradi. Aks holda o'qish muammosi yozishni ham bloklab
  ///    qo'yardi.
  Future<void> _requireProfileExists(String userId) async {
    Map<String, dynamic>? row;
    try {
      row = await supabaseClient
          .db('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return; // O'qish imkonsiz — qarorni DB (FK) qabul qiladi.
    }
    if (row == null) {
      throw ProfileMissingException(kProfileMissingMessage, userId: userId);
    }
  }

  /// O'qish yo'li uchun: UI'ga xom `category_id` (uuid) emas, display nom
  /// beriladi. `public_questions_view` `category` ustunini bermaydi (live
  /// evidence: `select=category` -> HTTP 400), shuning uchun nom shu joyda
  /// qo'shiladi.
  void _applyCategoryDisplayName(
    Map<String, dynamic> qMap,
    QuestionCategoryCatalog catalog,
  ) {
    final existing = qMap['category'];
    if (existing is String && existing.trim().isNotEmpty) return;

    final rawId = qMap['category_id']?.toString();
    final name = catalog.displayNameFor(rawId);
    if (name != null) {
      qMap['category'] = name;
      return;
    }
    if (rawId != null && QuestionCategoryCatalog.isUuid(rawId)) {
      qMap['category'] = kUnknownCategoryLabel;
    }
  }

  // MOCK FALLBACK OLIB TASHLANDI (P0, 2026-08-22).
  //
  // Ilgari bu yerda `_fallbackPosts` (`id: 'post_labor_1'`) statik ro'yxati
  // turardi va o'qish yo'lidagi HAR QANDAY xato jimgina shu mock post bilan
  // almashtirilardi. Live integration test aynan shuni ko'rsatdi:
  //   EXPECTED post.id = 36e0782e-97de-4f7e-8aae-48646c5ea27e
  //   ACTUAL   post.id = post_labor_1
  // Huquqiy ilovada o'ylab topilgan savol/javob ko'rsatish = YOLG'ON SUCCESS.
  // Endi o'qish yo'li real xatoni `ServerException` sifatida qaytaradi.

  @override
  Future<List<CommunityPostModel>> getPosts({String? category, String? searchQuery}) async {
    final hasCategoryFilter = !QuestionCategoryCatalog.isAllCategories(category);
    final hasSearch = searchQuery != null && searchQuery.trim().isNotEmpty;

    // Kategoriya NOMI -> real UUID. Bu qadam ATAYLAB pastdagi `try`dan
    // TASHQARIDA: rezolyutsiya xatosi yashirilmasligi kerak.
    // Nomni uuid ustuniga yuborish 22P02 beradi.
    final String? categoryId =
        hasCategoryFilter ? await _requireCategoryId(category) : null;

    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      final catalog = await _displayCatalog();

      // 1. Try querying public_questions_view or fallback to questions
      List<dynamic> rawList = [];
      try {
        var query = supabaseClient.db('public_questions_view').select();
        if (categoryId != null) {
          query = query.eq('category_id', categoryId);
        }
        if (hasSearch) {
          query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
        }
        final response = await query.order('created_at', ascending: false);
        rawList = response as List<dynamic>;
      } catch (_) {
        // View mavjud bo'lmasa/o'qilmasa BAZA jadvaliga tushamiz. Bu yerdagi
        // xato YUTILMAYDI: pastdagi so'rov ham yiqilsa, xato yuqoriga chiqadi.
        var qQuery = supabaseClient.db('questions').select('*, profiles(full_name, role, is_verified, avatar_url)');
        if (categoryId != null) {
          qQuery = qQuery.eq('category_id', categoryId);
        }
        if (hasSearch) {
          qQuery = qQuery.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
        }
        final response = await qQuery.order('created_at', ascending: false);
        rawList = response as List<dynamic>;
      }

      // BO'SH natija HAQIQIY natija — mock post bilan to'ldirilmaydi.
      if (rawList.isEmpty) {
        return <CommunityPostModel>[];
      }

      // 2. Fetch answers and votes for these questions
      final questionIds = rawList.map((e) => e['id'] as String).toList();

      // Javoblar — feed'ning ASOSIY ma'lumoti. Xato YUTILMAYDI: aks holda
      // "hech kim javob bermagan" degan YOLG'ON holat ko'rsatiladi.
      final answersResponse = await supabaseClient
          .db(kAnswersTable)
          .select('*, profiles(full_name, role, is_verified, avatar_url)')
          .inFilter('question_id', questionIds)
          .order('created_at', ascending: true);
      final rawAnswers = answersResponse as List<dynamic>;

      // Ovozlar — FAQAT bezak (like belgisi). O'qilmasa sahifa yiqilmaydi.
      final userVotes = await _currentUserVotes(currentUserId);

      // Javoblarni savol bo'yicha guruhlash. DIQQAT: bu yerda XOM JSON
      // saqlanadi — parse FAQAT `CommunityPostModel.fromJson` ichida bir
      // marta bajariladi (ikki marta map qilish P0 TypeError bergan).
      final answersByQuestion = <String, List<Map<String, dynamic>>>{};
      for (final a in rawAnswers) {
        final ansMap = Map<String, dynamic>.from(a as Map);
        final qId = ansMap['question_id'] as String;
        ansMap['is_upvoted_by_me'] = userVotes.contains(ansMap['id']);
        answersByQuestion.putIfAbsent(qId, () => []).add(ansMap);
      }

      // Build CommunityPostModels
      return rawList.map((q) {
        final qMap = Map<String, dynamic>.from(q as Map);
        final qId = qMap['id'] as String;
        qMap['is_liked_by_me'] = userVotes.contains(qId);
        qMap['answers'] = answersByQuestion[qId] ?? const <dynamic>[];
        _applyCategoryDisplayName(qMap, catalog);
        return CommunityPostModel.fromJson(qMap, currentUserId: currentUserId);
      }).toList();
    } on ServerException {
      // Kategoriya rezolyutsiyasi / domain xatolari yashirilmaydi.
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        statusCode: int.tryParse(e.code ?? '500'),
        details: e,
      );
    } on AnswerMappingException catch (e) {
      throw ServerException(message: e.message, statusCode: 500, details: e);
    } catch (e) {
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      // Tarmoq / parse xatosi. MOCK QAYTARILMAYDI: aks holda foydalanuvchi
      // o'ylab topilgan savolni real deb o'qiydi.
      throw ServerException(
        message: "Jamiyat savollarini yuklab bo'lmadi. Internet aloqasini "
            "tekshirib qayta urinib ko'ring.",
        statusCode: 503,
        details: e,
      );
    }
  }

  /// Joriy foydalanuvchining ovoz bergan `target_id`lari.
  ///
  /// FAQAT BEZAK: like/upvote belgisini ko'rsatish uchun. Shu sababli xato
  /// bo'lsa bo'sh to'plam qaytadi — savol va javob matni (ASOSIY ma'lumot)
  /// bundan qat'i nazar ko'rsatiladi. Bu YOLG'ON SUCCESS emas: yo'qolgan
  /// narsa faqat "men ovoz bergan" belgisi.
  Future<Set<String>> _currentUserVotes(String? currentUserId) async {
    if (currentUserId == null) return const <String>{};
    try {
      final votesResponse = await supabaseClient
          .db('votes')
          .select('target_id')
          .eq('user_id', currentUserId);
      return {
        for (final v in votesResponse as List<dynamic>)
          if (v['target_id'] != null) v['target_id'] as String,
      };
    } catch (_) {
      return const <String>{};
    }
  }

  /// Savolni ID bo'yicha o'qiydi.
  ///
  /// INVARIANT (P0, live evidence 2026-08-22): bu metod HECH QACHON mock post
  /// qaytarmaydi. Savol topilmasa 404, DB/parse xatosi bo'lsa real
  /// `ServerException` — UI aniq xabar ko'rsatadi, o'ylab topilgan savol emas.
  @override
  Future<CommunityPostModel> getPostById(String postId) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      Map<String, dynamic>? qMap;

      try {
        final response = await supabaseClient
            .db('public_questions_view')
            .select()
            .eq('id', postId)
            .maybeSingle();
        if (response != null) {
          qMap = Map<String, dynamic>.from(response);
        }
      } catch (_) {
        // View o'qilmasa BAZA jadvali. Bu ikkinchi so'rovning xatosi
        // YUTILMAYDI — pastdagi typed `catch` bloklariga boradi.
        final response = await supabaseClient
            .db('questions')
            .select('*, profiles(full_name, role, is_verified, avatar_url)')
            .eq('id', postId)
            .maybeSingle();
        if (response != null) {
          qMap = Map<String, dynamic>.from(response);
        }
      }

      // TOPILMADI = 404. Ilgari bu yerda `_fallbackPosts.first` qaytardi,
      // ya'ni o'chirilgan/mavjud bo'lmagan savol o'rniga MOCK ko'rsatilardi.
      if (qMap == null) {
        throw ServerException(
          message: "Savol topilmadi. U o'chirilgan bo'lishi mumkin.",
          statusCode: 404,
          details: postId,
        );
      }

      // Javoblar — savol tafsilotlarining ASOSIY ma'lumoti. Xato YUTILMAYDI:
      // aks holda javob YOZILGAN savol "javobsiz" ko'rinadi (yolg'on holat).
      final answersResponse = await supabaseClient
          .db(kAnswersTable)
          .select('*, profiles(full_name, role, is_verified, avatar_url)')
          .eq('question_id', postId)
          .order('created_at', ascending: true);
      final rawAnswers = answersResponse as List<dynamic>;

      // Ovozlar — faqat bezak (qarang: `_currentUserVotes`).
      final userVotes = await _currentUserVotes(currentUserId);

      // XOM JSON beriladi: parse FAQAT `CommunityPostModel.fromJson` ichida
      // BIR MARTA bajariladi. Ilgari bu yerda javoblar model obyektiga
      // aylantirilib map'ga solinardi va `fromJson` ularni `Map` deb cast
      // qilib TypeError tashlardi -> tashqi `catch` -> `post_labor_1`.
      final answerMaps = rawAnswers.map((a) {
        final aMap = Map<String, dynamic>.from(a as Map);
        aMap['is_upvoted_by_me'] = userVotes.contains(aMap['id']);
        return aMap;
      }).toList();

      qMap['is_liked_by_me'] = userVotes.contains(postId);
      qMap['answers'] = answerMaps;
      _applyCategoryDisplayName(qMap, await _displayCatalog());

      return CommunityPostModel.fromJson(qMap, currentUserId: currentUserId);
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      // Real DB xatosi (RLS 42501, 42703, 22P02 ...) — mock bilan
      // ALMASHTIRILMAYDI, xabar foydalanuvchiga yetib boradi.
      throw ServerException(
        message: e.message,
        statusCode: int.tryParse(e.code ?? '500'),
        details: e,
      );
    } on AnswerMappingException catch (e) {
      throw ServerException(message: e.message, statusCode: 500, details: e);
    } catch (e) {
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Savol ma'lumotlarini yuklab bo'lmadi. Internet aloqasini "
            "tekshirib qayta urinib ko'ring.",
        statusCode: 503,
        details: e,
      );
    }
  }

  @override
  Future<CommunityPostModel> createQuestion({
    required String title,
    required String rawQuestion,
    required String category,
    required bool isAnonymous,
    required String authorName,
  }) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const ServerException(message: "Savol berish uchun avval tizimga kiring", statusCode: 401);
      }

      // Mandatory PII Sanitization
      final sanitized = PiiAnonymizer.anonymize(rawQuestion);
      final aiSummary = "Ushbu savol $category doirasida ko'rib chiqiladi. Fuqaroning huquqlari qonunchilik bilan kafolatlangan.";

      // INVARIANT: UI display nomi ("Mehnat huquqi") HECH QACHON
      // `questions.category_id` ustuniga yuborilmaydi. Katalogdan real UUID
      // topilmasa — aniq domain error (422), silent fallback YO'Q.
      final categoryId = await _requireCategoryId(category);

      // INVARIANT: `questions.user_id` FK'si `public.profiles(id)`ga ishora
      // qiladi (live'da tasdiqlangan). Profil qatori bo'lmasa insert 23503
      // beradi. Bu yerda profil YARATILMAYDI — faqat aniq domain error
      // qaytariladi (foydalanuvchi talabi §7: profil bo'lmasa davom etmaslik).
      await _requireProfileExists(currentUserId);

      final inserted = await supabaseClient.db('questions').insert(
        buildQuestionInsertPayload(
          userId: currentUserId,
          title: title,
          description: sanitized,
          aiSummary: aiSummary,
          isAnonymous: isAnonymous,
          categoryId: categoryId,
        ),
      ).select().single();

      // Yaratilgan post AYNAN INSERT qaytargan qatordan quriladi — read-back
      // qilinmaydi (bitta round-trip tejaladi va yangi savol darhol
      // ko'rsatiladi).
      final row = Map<String, dynamic>.from(inserted);
      row['author_name'] = isAnonymous ? 'Anonim fuqaro' : authorName;
      row['answers'] = const <dynamic>[];
      row['is_liked_by_me'] = false;
      _applyCategoryDisplayName(row, await _displayCatalog());
      return CommunityPostModel.fromJson(row, currentUserId: currentUserId);
    } on PostgrestException catch (e) {
      // 23503 + `questions_user_id_fkey` => profil qatori yo'q. Xom DB matni
      // yutilmaydi: `details`da saqlanadi, foydalanuvchiga esa nima
      // qilishi kerakligi tushunarli tilda aytiladi.
      if (isQuestionUserFkViolation(code: e.code, message: e.message)) {
        throw ServerException(
          message: '$kProfileMissingMessage\n\nDB: ${e.message}',
          statusCode: 409,
          details: e,
        );
      }
      throw ServerException(message: e.message, statusCode: int.tryParse(e.code ?? '500'));
    } on CategoryResolutionException catch (e) {
      // Defense in depth: payload qo'riqchisi ishga tushdi.
      throw ServerException(message: e.message, statusCode: 422, details: e);
    } on ProfileMissingException catch (e) {
      // Pre-flight qo'riqchisi: PostgREST'ga insert YUBORILMADI, shuning uchun
      // 23503 hosil bo'lmadi. Profil bu yerda YARATILMAYDI.
      throw ServerException(message: e.message, statusCode: 409, details: e);
    } on QuestionContentException catch (e) {
      // `body` / `title` NOT NULL invarianti buzildi — PostgREST'ga
      // yuborilmadi (23502 hosil bo'lishiga yo'l qo'yilmadi).
      throw ServerException(message: e.message, statusCode: 422, details: e);
    } catch (e) {
      if (e is ServerException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CommunityPostModel> votePost(String postId) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const ServerException(message: "Ovoz berish uchun tizimga kiring", statusCode: 401);
      }

      // Check if vote exists
      final existingVote = await supabaseClient
          .db('votes')
          .select()
          .eq('user_id', currentUserId)
          .eq('target_type', 'question')
          .eq('target_id', postId)
          .maybeSingle();

      if (existingVote != null) {
        // Toggle off
        await supabaseClient
            .db('votes')
            .delete()
            .eq('user_id', currentUserId)
            .eq('target_type', 'question')
            .eq('target_id', postId);
      } else {
        // Insert vote
        await supabaseClient.db('votes').insert({
          'user_id': currentUserId,
          'target_type': 'question',
          'target_id': postId,
          'vote_value': 1,
        });
      }

      return getPostById(postId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, statusCode: int.tryParse(e.code ?? '500'));
    } catch (e) {
      if (e is ServerException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<QuestionAnswerModel> addAnswer({
    required String postId,
    required String content,
    required String authorName,
    required bool isExpert,
    String? authorRole,
  }) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const ServerException(message: "Javob yozish uchun tizimga kiring", statusCode: 401);
      }

      // `answers.user_id` -> `profiles(id)` FK: profil yo'q bo'lsa 23503.
      // Guard INSERT'dan OLDIN, savollar yo'li bilan bir xil.
      await _requireProfileExists(currentUserId);

      // Ekspert huquqi CLIENT STATE'dan emas, REAL `profiles` qatoridan.
      final canPostAsExpert =
          isExpert ? await _canCurrentUserAnswerAsExpert(currentUserId) : false;

      final sanitized = PiiAnonymizer.anonymize(content);

      final inserted = await supabaseClient
          .db(kAnswersTable)
          .insert(buildAnswerInsertPayload(
            questionId: postId,
            userId: currentUserId,
            text: sanitized,
            isExpert: isExpert,
            canPostAsExpert: canPostAsExpert,
          ))
          .select('*, profiles(full_name, role, is_verified, avatar_url)')
          .single();

      return QuestionAnswerModel.fromJson(inserted, currentUserId: currentUserId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, statusCode: int.tryParse(e.code ?? '500'));
    } on ProfileMissingException catch (e) {
      // Pre-flight qo'riqchisi: profil qatori yo'q (`answers.user_id` FK).
      // PostgREST'ga insert YUBORILMADI, profil bu yerda YARATILMAYDI.
      throw ServerException(message: e.message, statusCode: 409, details: e);
    } on ExpertAnswerNotAuthorizedException catch (e) {
      // RBAC: `is_expert_answer = true` yuborishga huquq yo'q. 403 —
      // foydalanuvchi oddiy javob sifatida qayta yuborishi mumkin.
      // Xabar TOZA (`e.message`), `toString()` EMAS: aks holda SnackBar'da
      // "ExpertAnswerNotAuthorizedException: ..." ko'rinadi.
      throw ServerException(message: e.message, statusCode: 403, details: e);
    } on AnswerContentException catch (e) {
      // Bo'sh javob matni — PostgREST'ga yuborilmadi.
      throw ServerException(message: e.message, statusCode: 422, details: e);
    } catch (e) {
      if (e is ServerException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  /// REAL `public.profiles` qatoridan ekspert huquqini o'qiydi.
  ///
  /// Bu client'dagi `_isExpertReply` bool'iga ISHONMAYDI. Profil o'qilmasa
  /// `false` — ya'ni default holat eng KAM imtiyoz (fail-closed).
  Future<bool> _canCurrentUserAnswerAsExpert(String userId) async {
    Map<String, dynamic>? row;
    try {
      row = await supabaseClient
          .db('profiles')
          .select('role, is_verified')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return false;
    }
    if (row == null) return false;
    return canAnswerAsExpert(
      role: row['role'] as String?,
      isVerified: row['is_verified'] as bool? ?? false,
    );
  }

  @override
  Future<QuestionAnswerModel> voteAnswer(String answerId) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const ServerException(message: "Ovoz berish uchun tizimga kiring", statusCode: 401);
      }

      // Check if vote exists
      final existingVote = await supabaseClient
          .db('votes')
          .select()
          .eq('user_id', currentUserId)
          .eq('target_type', 'answer')
          .eq('target_id', answerId)
          .maybeSingle();

      if (existingVote != null) {
        await supabaseClient
            .db('votes')
            .delete()
            .eq('user_id', currentUserId)
            .eq('target_type', 'answer')
            .eq('target_id', answerId);
      } else {
        await supabaseClient.db('votes').insert({
          'user_id': currentUserId,
          'target_type': 'answer',
          'target_id': answerId,
          'vote_value': 1,
        });
      }

      final updated = await supabaseClient
          .db('answers')
          .select('*, profiles(full_name, role, is_verified, avatar_url)')
          .eq('id', answerId)
          .single();

      final aMap = Map<String, dynamic>.from(updated);
      aMap['is_upvoted_by_me'] = existingVote == null;

      return QuestionAnswerModel.fromJson(aMap, currentUserId: currentUserId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, statusCode: int.tryParse(e.code ?? '500'));
    } catch (e) {
      if (e is ServerException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> acceptAnswer({
    required String questionId,
    required String answerId,
  }) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const ServerException(message: "Amalni bajarish uchun tizimga kiring", statusCode: 401);
      }

      await supabaseClient
          .db('answers')
          .update({'is_accepted': true})
          .eq('id', answerId)
          .eq('question_id', questionId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, statusCode: int.tryParse(e.code ?? '500'));
    } catch (e) {
      if (e is ServerException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
