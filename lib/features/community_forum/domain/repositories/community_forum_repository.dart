import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';

abstract class CommunityForumRepository {
  Future<Either<Failure, List<CommunityPost>>> getPosts({String? category, String? searchQuery});
  Future<Either<Failure, CommunityPost>> getPostById(String postId);
  Future<Either<Failure, CommunityPost>> createQuestion({
    required String title,
    required String rawQuestion,
    required String category,
    required bool isAnonymous,
    required String authorName,
  });
  Future<Either<Failure, CommunityPost>> votePost(String postId);
  Future<Either<Failure, QuestionAnswer>> addAnswer({
    required String postId,
    required String content,
    required String authorName,
    required bool isExpert,
    String? authorRole,
  });
  Future<Either<Failure, QuestionAnswer>> voteAnswer(String answerId);
  Future<Either<Failure, void>> acceptAnswer({
    required String questionId,
    required String answerId,
  });
}
