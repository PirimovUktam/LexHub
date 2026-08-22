import 'package:equatable/equatable.dart';

/// Role of the message sender in Legal Talk
enum TalkSenderRole {
  citizen,
  verifiedLawyer,
  moderator,
}

/// Entity representing a message inside a discussion room
class TalkMessage extends Equatable {
  final String id;
  final String roomId;
  final String senderName;
  final TalkSenderRole senderRole;
  final String messageText;
  final DateTime timestamp;
  final int likesCount;
  final bool isPinned;
  final bool isAudioMessage;
  final String? audioDuration;
  final bool isLikedByMe;

  const TalkMessage({
    required this.id,
    required this.roomId,
    required this.senderName,
    required this.senderRole,
    required this.messageText,
    required this.timestamp,
    this.likesCount = 0,
    this.isPinned = false,
    this.isAudioMessage = false,
    this.audioDuration,
    this.isLikedByMe = false,
  });

  TalkMessage copyWith({
    String? id,
    String? roomId,
    String? senderName,
    TalkSenderRole? senderRole,
    String? messageText,
    DateTime? timestamp,
    int? likesCount,
    bool? isPinned,
    bool? isAudioMessage,
    String? audioDuration,
    bool? isLikedByMe,
  }) {
    return TalkMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      messageText: messageText ?? this.messageText,
      timestamp: timestamp ?? this.timestamp,
      likesCount: likesCount ?? this.likesCount,
      isPinned: isPinned ?? this.isPinned,
      isAudioMessage: isAudioMessage ?? this.isAudioMessage,
      audioDuration: audioDuration ?? this.audioDuration,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        senderName,
        senderRole,
        messageText,
        timestamp,
        likesCount,
        isPinned,
        isAudioMessage,
        audioDuration,
        isLikedByMe,
      ];
}
