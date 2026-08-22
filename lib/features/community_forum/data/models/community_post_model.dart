import 'package:lexhub/features/community_forum/data/models/question_answer_model.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';

/// Berilgan qiymatlardan birinchi bo'sh bo'lmagan matnni qaytaradi.
/// Live schema drift (`body` / `description` / `content`) uchun kerak.
String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return '';
}

/// Javob ro'yxatini map qilishda kutilmagan element turi topilganda.
///
/// JIMGINA TASHLAB KETILMAYDI: javobni yo'qotish "savol javobsiz" degan
/// YOLG'ON holatni ko'rsatadi. Datasource bu xatoni `ServerException`ga
/// map qiladi va UI aniq xabar beradi.
class AnswerMappingException implements Exception {
  const AnswerMappingException(this.message);

  final String message;

  @override
  String toString() => 'AnswerMappingException: $message';
}

/// `answers` maydonini BITTA joyda parse qiladi.
///
/// P0 ROOT CAUSE (2026-08-22, live evidence): `getPostById` / `getPosts`
/// `qMap['answers']`ga ALLAQACHON qurilgan `List<QuestionAnswerModel>`
/// solar edi, `CommunityPostModel.fromJson` esa har bir elementni
/// `e as Map<String, dynamic>` deb cast qilardi. Natija — javob BOR bo'lgan
/// har bir savolda:
///
///   `type 'QuestionAnswerModel' is not a subtype of type 'Map<String, dynamic>'`
///
/// Bu TypeError datasource'ning tashqi `catch`iga tushib mock post
/// (`post_labor_1`) bilan yashiringan. Javob YO'Q bo'lganda ro'yxat bo'sh
/// bo'lgani uchun cast hech qachon bajarilmasdi — shuning uchun bug
/// birinchi javob yozilgunga qadar KO'RINMAGAN.
///
/// Shuning uchun bu funksiya IKKI shaklni ham qabul qiladi:
///  * xom PostgREST JSON (`Map`) -> `fromJson`;
///  * qurilgan entity/model -> `fromEntity` (qayta parse yo'q).
List<QuestionAnswerModel> parseAnswerList(dynamic raw, {String? currentUserId}) {
  if (raw == null) return const <QuestionAnswerModel>[];
  if (raw is! List) {
    throw AnswerMappingException(
      "Javoblar ro'yxati kutilgan edi, lekin ${raw.runtimeType} keldi.",
    );
  }
  return raw.map<QuestionAnswerModel>((e) {
    if (e is QuestionAnswer) return QuestionAnswerModel.fromEntity(e);
    if (e is Map) {
      return QuestionAnswerModel.fromJson(
        Map<String, dynamic>.from(e),
        currentUserId: currentUserId,
      );
    }
    throw AnswerMappingException(
      "Javob elementi noma'lum turda: ${e.runtimeType}.",
    );
  }).toList();
}

class CommunityPostModel extends CommunityPost {
  const CommunityPostModel({
    required super.id,
    super.userId,
    required super.title,
    required super.anonymizedQuestion,
    required super.category,
    required super.aiSummary,
    super.helpfulCount,
    super.viewsCount,
    super.answersCount,
    super.isAnonymous,
    super.authorName,
    super.authorAvatarUrl,
    required super.createdAt,
    super.isLikedByMe,
    super.answers,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final answersList =
        parseAnswerList(json['answers'], currentUserId: currentUserId);

    final isAnon = json['is_anonymous'] as bool? ?? false;
    final authorName = isAnon
        ? 'Anonim fuqaro'
        : (json['author_name'] as String? ?? 'Fuqaro');
    final authorAvatar = isAnon ? null : (json['author_avatar_url'] as String?);
    final userId = isAnon ? null : (json['user_id'] as String?);

    // Live `public.questions` da savol matni uchun 4 ta ustun bor:
    // `anonymized_question`, `description`, `body` (legacy, NOT NULL),
    // `content` (legacy). `public_questions_view` esa faqat
    // `anonymized_question` + `description` ni ochadi. Yangi savollar
    // hammasiga yoziladi, lekin ESKI qatorlarda faqat `body` to'lgan
    // bo'lishi mumkin — shu sababli to'liq fallback zanjiri.
    final questionText = _firstNonEmpty(<dynamic>[
      json['anonymized_question'],
      json['description'],
      json['body'],
      json['content'],
    ]);

    return CommunityPostModel(
      id: json['id'] as String? ?? '',
      userId: userId,
      title: json['title'] as String? ?? '',
      anonymizedQuestion: questionText,
      category: json['category'] as String? ?? json['category_id'] as String? ?? 'Umumiy',
      aiSummary: json['ai_summary'] as String? ?? '',
      helpfulCount: json['helpful_count'] as int? ?? json['upvotes_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      answersCount: json['answers_count'] as int? ?? answersList.length,
      isAnonymous: isAnon,
      authorName: authorName,
      authorAvatarUrl: authorAvatar,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
      answers: answersList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'anonymized_question': anonymizedQuestion,
      'category': category,
      'ai_summary': aiSummary,
      'helpful_count': helpfulCount,
      'views_count': viewsCount,
      'answers_count': answersCount,
      'is_anonymous': isAnonymous,
      'author_name': authorName,
      if (authorAvatarUrl != null) 'author_avatar_url': authorAvatarUrl,
      'created_at': createdAt.toIso8601String(),
      'is_liked_by_me': isLikedByMe,
      'answers':
          answers.map((a) => QuestionAnswerModel.fromEntity(a).toJson()).toList(),
    };
  }
}
