import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class CreateCommunityQuestionParams extends Equatable {
  final String title;
  final String rawQuestion;
  final String category;
  final bool isAnonymous;
  final String authorName;

  const CreateCommunityQuestionParams({
    required this.title,
    required this.rawQuestion,
    required this.category,
    required this.isAnonymous,
    required this.authorName,
  });

  @override
  List<Object?> get props => [title, rawQuestion, category, isAnonymous, authorName];
}

class CreateCommunityQuestionUseCase implements UseCase<CommunityPost, CreateCommunityQuestionParams> {
  final CommunityForumRepository repository;

  CreateCommunityQuestionUseCase(this.repository);

  @override
  Future<Either<Failure, CommunityPost>> call(CreateCommunityQuestionParams params) async {
    return await repository.createQuestion(
      title: params.title,
      rawQuestion: params.rawQuestion,
      category: params.category,
      isAnonymous: params.isAnonymous,
      authorName: params.authorName,
    );
  }
}
