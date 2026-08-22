import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class VoteCommunityPostUseCase implements UseCase<CommunityPost, String> {
  final CommunityForumRepository repository;

  VoteCommunityPostUseCase(this.repository);

  @override
  Future<Either<Failure, CommunityPost>> call(String postId) async {
    return await repository.votePost(postId);
  }
}
