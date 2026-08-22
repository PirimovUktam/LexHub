import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';

abstract class CommunityForumState extends Equatable {
  const CommunityForumState();

  @override
  List<Object?> get props => [];
}

class CommunityForumInitial extends CommunityForumState {}

class CommunityForumLoading extends CommunityForumState {}

class CommunityForumLoaded extends CommunityForumState {
  final List<CommunityPost> posts;
  final String selectedCategory;
  final String searchQuery;

  const CommunityForumLoaded({
    required this.posts,
    this.selectedCategory = 'Barchasi',
    this.searchQuery = '',
  });

  CommunityForumLoaded copyWith({
    List<CommunityPost>? posts,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return CommunityForumLoaded(
      posts: posts ?? this.posts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [posts, selectedCategory, searchQuery];
}

class CommunityForumError extends CommunityForumState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const CommunityForumError(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}

class CommunityQuestionCreatedSuccess extends CommunityForumState {
  final CommunityPost post;

  const CommunityQuestionCreatedSuccess(this.post);

  @override
  List<Object?> get props => [post];
}
