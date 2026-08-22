import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';

abstract class LegalTalkState extends Equatable {
  const LegalTalkState();

  @override
  List<Object?> get props => [];
}

class LegalTalkInitial extends LegalTalkState {}

class LegalTalkRoomsLoading extends LegalTalkState {}

class LegalTalkRoomsLoaded extends LegalTalkState {
  final List<TalkRoom> allRooms;
  final List<TalkRoom> filteredRooms;
  final List<TalkRoom> liveRooms;
  final String selectedCategory;
  final String searchQuery;

  const LegalTalkRoomsLoaded({
    required this.allRooms,
    required this.filteredRooms,
    required this.liveRooms,
    this.selectedCategory = "Barchasi",
    this.searchQuery = "",
  });

  LegalTalkRoomsLoaded copyWith({
    List<TalkRoom>? allRooms,
    List<TalkRoom>? filteredRooms,
    List<TalkRoom>? liveRooms,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return LegalTalkRoomsLoaded(
      allRooms: allRooms ?? this.allRooms,
      filteredRooms: filteredRooms ?? this.filteredRooms,
      liveRooms: liveRooms ?? this.liveRooms,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        allRooms,
        filteredRooms,
        liveRooms,
        selectedCategory,
        searchQuery,
      ];
}

class LegalTalkRoomChatLoading extends LegalTalkState {}

class LegalTalkRoomChatLoaded extends LegalTalkState {
  final TalkRoom room;
  final List<TalkMessage> messages;
  final bool isSending;
  final String? errorMessage;

  const LegalTalkRoomChatLoaded({
    required this.room,
    required this.messages,
    this.isSending = false,
    this.errorMessage,
  });

  LegalTalkRoomChatLoaded copyWith({
    TalkRoom? room,
    List<TalkMessage>? messages,
    bool? isSending,
    String? errorMessage,
  }) {
    return LegalTalkRoomChatLoaded(
      room: room ?? this.room,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        room,
        messages,
        isSending,
        errorMessage,
      ];
}

class LegalTalkError extends LegalTalkState {
  final String message;

  const LegalTalkError(this.message);

  @override
  List<Object?> get props => [message];
}
