import 'package:equatable/equatable.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';

class CommunityPost extends Equatable {
  final String id;
  final String? userId;
  final String title;
  final String anonymizedQuestion;
  final String category;
  final String aiSummary;
  final int helpfulCount;
  final int viewsCount;
  final int answersCount;
  final bool isAnonymous;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final bool isLikedByMe;
  final List<QuestionAnswer> answers;

  const CommunityPost({
    required this.id,
    this.userId,
    required this.title,
    required this.anonymizedQuestion,
    required this.category,
    required this.aiSummary,
    this.helpfulCount = 0,
    this.viewsCount = 0,
    this.answersCount = 0,
    this.isAnonymous = false,
    this.authorName = "Fuqaro",
    this.authorAvatarUrl,
    required this.createdAt,
    this.isLikedByMe = false,
    this.answers = const [],
  });

  CommunityPost copyWith({
    String? id,
    String? userId,
    String? title,
    String? anonymizedQuestion,
    String? category,
    String? aiSummary,
    int? helpfulCount,
    int? viewsCount,
    int? answersCount,
    bool? isAnonymous,
    String? authorName,
    String? authorAvatarUrl,
    DateTime? createdAt,
    bool? isLikedByMe,
    List<QuestionAnswer>? answers,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      anonymizedQuestion: anonymizedQuestion ?? this.anonymizedQuestion,
      category: category ?? this.category,
      aiSummary: aiSummary ?? this.aiSummary,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      viewsCount: viewsCount ?? this.viewsCount,
      answersCount: answersCount ?? this.answersCount,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        anonymizedQuestion,
        category,
        aiSummary,
        helpfulCount,
        viewsCount,
        answersCount,
        isAnonymous,
        authorName,
        authorAvatarUrl,
        createdAt,
        isLikedByMe,
        answers,
      ];
}
