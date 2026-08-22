import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';

abstract class LegalTalkRepository {
  Future<Either<Failure, List<TalkRoom>>> getTalkRooms({
    String? category,
    String? searchQuery,
  });

  Future<Either<Failure, List<TalkMessage>>> getRoomMessages(String roomId);

  Future<Either<Failure, TalkMessage>> sendMessage({
    required String roomId,
    required String senderName,
    required TalkSenderRole senderRole,
    required String messageText,
    bool isAudioMessage = false,
    String? audioDuration,
  });

  Future<Either<Failure, TalkMessage>> toggleMessageLike({
    required String roomId,
    required String messageId,
  });

  Future<Either<Failure, TalkRoom>> createTalkRoom({
    required String title,
    required String category,
    required String description,
  });
}
