import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class GetCommunityPostsParams extends Equatable {
  final String? category;
  final String? searchQuery;

  const GetCommunityPostsParams({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class GetCommunityPostsUseCase implements UseCase<List<CommunityPost>, GetCommunityPostsParams> {
  final CommunityForumRepository repository;

  GetCommunityPostsUseCase(this.repository);

  @override
  Future<Either<Failure, List<CommunityPost>>> call(GetCommunityPostsParams params) async {
    return await repository.getPosts(
      category: params.category,
      searchQuery: params.searchQuery,
    );
  }
}
