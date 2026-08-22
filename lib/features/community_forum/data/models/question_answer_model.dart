import 'package:lexhub/features/community_forum/data/datasources/answer_schema.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';

class QuestionAnswerModel extends QuestionAnswer {
  const QuestionAnswerModel({
    required super.id,
    super.questionId,
    super.userId,
    required super.authorName,
    super.authorRole,
    super.isExpert,
    super.isAccepted,
    required super.content,
    super.upvotesCount,
    super.legalReferences,
    required super.createdAt,
    super.isUpvotedByMe,
  });

  /// Domain entity'dan model quradi (qayta parse QILMAYDI).
  ///
  /// Nima uchun kerak: o'qish yo'lida javob ba'zan ALLAQACHON model/entity
  /// sifatida qurilgan bo'ladi. Uni yana `fromJson`ga berish
  /// `type 'QuestionAnswerModel' is not a subtype of type 'Map<String, dynamic>'`
  /// TypeError'iga olib kelgan (P0 regressiya) — shuning uchun bu yo'l
  /// AYNIQSA parse'siz.
  factory QuestionAnswerModel.fromEntity(QuestionAnswer answer) {
    if (answer is QuestionAnswerModel) return answer;
    return QuestionAnswerModel(
      id: answer.id,
      questionId: answer.questionId,
      userId: answer.userId,
      authorName: answer.authorName,
      authorRole: answer.authorRole,
      isExpert: answer.isExpert,
      isAccepted: answer.isAccepted,
      content: answer.content,
      upvotesCount: answer.upvotesCount,
      legalReferences: answer.legalReferences,
      createdAt: answer.createdAt,
      isUpvotedByMe: answer.isUpvotedByMe,
    );
  }

  factory QuestionAnswerModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    // Check if author profile is joined
    final profile = json['profiles'] as Map<String, dynamic>?;
    final authorName = json['author_name'] as String? ?? profile?['full_name'] as String? ?? 'Fuqaro';
    final authorRole = json['author_role'] as String? ?? profile?['role'] as String?;
    final isExpert = json['is_expert_answer'] as bool? ?? json['is_expert'] as bool? ?? (profile?['role'] == 'lawyer' || profile?['role'] == 'verified_expert');

    final userId = json['user_id'] as String?;

    return QuestionAnswerModel(
      id: json['id'] as String? ?? '',
      questionId: json['question_id'] as String?,
      userId: userId,
      authorName: authorName,
      authorRole: authorRole,
      isExpert: isExpert,
      isAccepted: json['is_accepted'] as bool? ?? false,
      // LIVE'da javob matni `body` da (`content` ustuni MAVJUD EMAS — 42703).
      // Eski `json['content'] as String? ?? ''` HAR DOIM `''` qaytargan,
      // ya'ni javob saqlansa ham UI'da BO'SH ko'rinardi.
      content: readAnswerText(json) ?? '',
      upvotesCount: json['upvotes_count'] as int? ?? 0,
      legalReferences: (json['legal_references'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isUpvotedByMe: json['is_upvoted_by_me'] as bool? ?? false,
    );
  }

  /// DIQQAT: bu ilova ICHIDAGI (cache / round-trip) shakl, PostgREST
  /// payload'i EMAS. DB'ga yozish uchun FAQAT [buildAnswerInsertPayload]
  /// ishlatiladi. Matn kaliti real live ustun nomi bilan bir xil
  /// ([kAnswerTextColumn] = `body`), shuning uchun tasodifan `.insert()`ga
  /// berilsa ham mavjud bo'lmagan `content` ustuni yuborilmaydi.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (questionId != null) 'question_id': questionId,
      if (userId != null) 'user_id': userId,
      'author_name': authorName,
      'author_role': authorRole,
      'is_expert_answer': isExpert,
      'is_accepted': isAccepted,
      kAnswerTextColumn: content,
      'upvotes_count': upvotesCount,
      'legal_references': legalReferences,
      'created_at': createdAt.toIso8601String(),
      'is_upvoted_by_me': isUpvotedByMe,
    };
  }
}
