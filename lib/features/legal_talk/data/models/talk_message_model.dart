import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';

class TalkMessageModel extends TalkMessage {
  const TalkMessageModel({
    required super.id,
    required super.roomId,
    required super.senderName,
    required super.senderRole,
    required super.messageText,
    required super.timestamp,
    super.likesCount = 0,
    super.isPinned = false,
    super.isAudioMessage = false,
    super.audioDuration,
    super.isLikedByMe = false,
  });

  factory TalkMessageModel.fromJson(Map<String, dynamic> json) {
    TalkSenderRole role;
    switch (json['senderRole']) {
      case 'verifiedLawyer':
      case 'verified_lawyer':
        role = TalkSenderRole.verifiedLawyer;
        break;
      case 'moderator':
        role = TalkSenderRole.moderator;
        break;
      default:
        role = TalkSenderRole.citizen;
    }

    return TalkMessageModel(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderName: json['senderName'] as String,
      senderRole: role,
      messageText: json['messageText'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      likesCount: json['likesCount'] as int? ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isAudioMessage: json['isAudioMessage'] as bool? ?? false,
      audioDuration: json['audioDuration'] as String?,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'messageText': messageText,
      'timestamp': timestamp.toIso8601String(),
      'likesCount': likesCount,
      'isPinned': isPinned,
      'isAudioMessage': isAudioMessage,
      'audioDuration': audioDuration,
      'isLikedByMe': isLikedByMe,
    };
  }

  factory TalkMessageModel.fromEntity(TalkMessage entity) {
    return TalkMessageModel(
      id: entity.id,
      roomId: entity.roomId,
      senderName: entity.senderName,
      senderRole: entity.senderRole,
      messageText: entity.messageText,
      timestamp: entity.timestamp,
      likesCount: entity.likesCount,
      isPinned: entity.isPinned,
      isAudioMessage: entity.isAudioMessage,
      audioDuration: entity.audioDuration,
      isLikedByMe: entity.isLikedByMe,
    );
  }
}
