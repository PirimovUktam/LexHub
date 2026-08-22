import 'package:equatable/equatable.dart';

class QuestionAnswer extends Equatable {
  final String id;
  final String? questionId;
  final String? userId;
  final String authorName;
  final String? authorRole; // 'Advokat', 'Yurist', 'Fuqaro'
  final bool isExpert;
  final bool isAccepted;
  final String content;
  final int upvotesCount;
  final List<String> legalReferences;
  final DateTime createdAt;
  final bool isUpvotedByMe;

  const QuestionAnswer({
    required this.id,
    this.questionId,
    this.userId,
    required this.authorName,
    this.authorRole,
    this.isExpert = false,
    this.isAccepted = false,
    required this.content,
    this.upvotesCount = 0,
    this.legalReferences = const [],
    required this.createdAt,
    this.isUpvotedByMe = false,
  });

  QuestionAnswer copyWith({
    String? id,
    String? questionId,
    String? userId,
    String? authorName,
    String? authorRole,
    bool? isExpert,
    bool? isAccepted,
    String? content,
    int? upvotesCount,
    List<String>? legalReferences,
    DateTime? createdAt,
    bool? isUpvotedByMe,
  }) {
    return QuestionAnswer(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      isExpert: isExpert ?? this.isExpert,
      isAccepted: isAccepted ?? this.isAccepted,
      content: content ?? this.content,
      upvotesCount: upvotesCount ?? this.upvotesCount,
      legalReferences: legalReferences ?? this.legalReferences,
      createdAt: createdAt ?? this.createdAt,
      isUpvotedByMe: isUpvotedByMe ?? this.isUpvotedByMe,
    );
  }

  @override
  List<Object?> get props => [
        id,
        questionId,
        userId,
        authorName,
        authorRole,
        isExpert,
        isAccepted,
        content,
        upvotesCount,
        legalReferences,
        createdAt,
        isUpvotedByMe,
      ];
}
