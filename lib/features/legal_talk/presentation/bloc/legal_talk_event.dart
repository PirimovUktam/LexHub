import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';

abstract class LegalTalkEvent extends Equatable {
  const LegalTalkEvent();

  @override
  List<Object?> get props => [];
}

class LoadTalkRoomsEvent extends LegalTalkEvent {
  final String? category;
  final String? searchQuery;

  const LoadTalkRoomsEvent({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class FilterTalkRoomsByCategoryEvent extends LegalTalkEvent {
  final String category;

  const FilterTalkRoomsByCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class SearchTalkRoomsEvent extends LegalTalkEvent {
  final String query;

  const SearchTalkRoomsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class EnterTalkRoomChatEvent extends LegalTalkEvent {
  final TalkRoom room;

  const EnterTalkRoomChatEvent(this.room);

  @override
  List<Object?> get props => [room];
}

class SendTalkMessageEvent extends LegalTalkEvent {
  final String roomId;
  final String text;
  final String senderName;
  final TalkSenderRole senderRole;
  final bool isAudio;
  final String? audioDuration;

  const SendTalkMessageEvent({
    required this.roomId,
    required this.text,
    this.senderName = "Siz (Fuqaro)",
    this.senderRole = TalkSenderRole.citizen,
    this.isAudio = false,
    this.audioDuration,
  });

  @override
  List<Object?> get props => [
        roomId,
        text,
        senderName,
        senderRole,
        isAudio,
        audioDuration,
      ];
}

class LikeTalkMessageEvent extends LegalTalkEvent {
  final String roomId;
  final String messageId;

  const LikeTalkMessageEvent({
    required this.roomId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [roomId, messageId];
}

class CreateTalkRoomEvent extends LegalTalkEvent {
  final String title;
  final String category;
  final String description;

  const CreateTalkRoomEvent({
    required this.title,
    required this.category,
    required this.description,
  });

  @override
  List<Object?> get props => [title, category, description];
}
