import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';

class LikeTalkMessageParams {
  final String roomId;
  final String messageId;

  const LikeTalkMessageParams({
    required this.roomId,
    required this.messageId,
  });
}

class LikeTalkMessageUseCase implements UseCase<TalkMessage, LikeTalkMessageParams> {
  final LegalTalkRepository repository;

  LikeTalkMessageUseCase(this.repository);

  @override
  Future<Either<Failure, TalkMessage>> call(LikeTalkMessageParams params) async {
    return await repository.toggleMessageLike(
      roomId: params.roomId,
      messageId: params.messageId,
    );
  }
}
