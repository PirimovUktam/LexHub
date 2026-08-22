import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class AcceptCommunityAnswerParams extends Equatable {
  final String questionId;
  final String answerId;

  const AcceptCommunityAnswerParams({
    required this.questionId,
    required this.answerId,
  });

  @override
  List<Object?> get props => [questionId, answerId];
}

class AcceptCommunityAnswerUseCase implements UseCase<void, AcceptCommunityAnswerParams> {
  final CommunityForumRepository repository;

  AcceptCommunityAnswerUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(AcceptCommunityAnswerParams params) {
    return repository.acceptAnswer(
      questionId: params.questionId,
      answerId: params.answerId,
    );
  }
}
