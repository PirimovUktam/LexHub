import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class AddCommunityAnswerParams extends Equatable {
  final String postId;
  final String content;
  final String authorName;
  final bool isExpert;
  final String? authorRole;

  const AddCommunityAnswerParams({
    required this.postId,
    required this.content,
    required this.authorName,
    required this.isExpert,
    this.authorRole,
  });

  @override
  List<Object?> get props => [postId, content, authorName, isExpert, authorRole];
}

class AddCommunityAnswerUseCase implements UseCase<QuestionAnswer, AddCommunityAnswerParams> {
  final CommunityForumRepository repository;

  AddCommunityAnswerUseCase(this.repository);

  @override
  Future<Either<Failure, QuestionAnswer>> call(AddCommunityAnswerParams params) async {
    return await repository.addAnswer(
      postId: params.postId,
      content: params.content,
      authorName: params.authorName,
      isExpert: params.isExpert,
      authorRole: params.authorRole,
    );
  }
}
