import 'package:equatable/equatable.dart';

abstract class CommunityForumEvent extends Equatable {
  const CommunityForumEvent();

  @override
  List<Object?> get props => [];
}

class LoadCommunityPostsEvent extends CommunityForumEvent {
  final String? category;
  final String? searchQuery;

  const LoadCommunityPostsEvent({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class SelectCommunityCategoryEvent extends CommunityForumEvent {
  final String category;

  const SelectCommunityCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class SearchCommunityPostsEvent extends CommunityForumEvent {
  final String query;

  const SearchCommunityPostsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class VoteCommunityPostEvent extends CommunityForumEvent {
  final String postId;

  const VoteCommunityPostEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CreateCommunityQuestionEvent extends CommunityForumEvent {
  final String title;
  final String rawQuestion;
  final String category;
  final bool isAnonymous;
  final String authorName;

  const CreateCommunityQuestionEvent({
    required this.title,
    required this.rawQuestion,
    required this.category,
    required this.isAnonymous,
    required this.authorName,
  });

  @override
  List<Object?> get props => [title, rawQuestion, category, isAnonymous, authorName];
}

class AddAnswerToQuestionEvent extends CommunityForumEvent {
  final String postId;
  final String content;
  final String authorName;
  final bool isExpert;
  final String? authorRole;

  const AddAnswerToQuestionEvent({
    required this.postId,
    required this.content,
    required this.authorName,
    required this.isExpert,
    this.authorRole,
  });

  @override
  List<Object?> get props => [postId, content, authorName, isExpert, authorRole];
}

class VoteCommunityAnswerEvent extends CommunityForumEvent {
  final String questionId;
  final String answerId;

  const VoteCommunityAnswerEvent({
    required this.questionId,
    required this.answerId,
  });

  @override
  List<Object?> get props => [questionId, answerId];
}

class AcceptCommunityAnswerEvent extends CommunityForumEvent {
  final String questionId;
  final String answerId;

  const AcceptCommunityAnswerEvent({
    required this.questionId,
    required this.answerId,
  });

  @override
  List<Object?> get props => [questionId, answerId];
}
