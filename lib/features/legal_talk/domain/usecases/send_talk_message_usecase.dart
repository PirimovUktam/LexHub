import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';

class SendTalkMessageParams {
  final String roomId;
  final String senderName;
  final TalkSenderRole senderRole;
  final String messageText;
  final bool isAudioMessage;
  final String? audioDuration;

  const SendTalkMessageParams({
    required this.roomId,
    required this.senderName,
    required this.senderRole,
    required this.messageText,
    this.isAudioMessage = false,
    this.audioDuration,
  });
}

class SendTalkMessageUseCase implements UseCase<TalkMessage, SendTalkMessageParams> {
  final LegalTalkRepository repository;

  SendTalkMessageUseCase(this.repository);

  @override
  Future<Either<Failure, TalkMessage>> call(SendTalkMessageParams params) async {
    return await repository.sendMessage(
      roomId: params.roomId,
      senderName: params.senderName,
      senderRole: params.senderRole,
      messageText: params.messageText,
      isAudioMessage: params.isAudioMessage,
      audioDuration: params.audioDuration,
    );
  }
}
