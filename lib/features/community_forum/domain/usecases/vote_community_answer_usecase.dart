import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class VoteCommunityAnswerUseCase implements UseCase<QuestionAnswer, String> {
  final CommunityForumRepository repository;

  VoteCommunityAnswerUseCase(this.repository);

  @override
  Future<Either<Failure, QuestionAnswer>> call(String answerId) {
    return repository.voteAnswer(answerId);
  }
}
