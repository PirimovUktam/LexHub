import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/create_talk_room_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/get_room_messages_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/get_talk_rooms_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/like_talk_message_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/send_talk_message_usecase.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_event.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_state.dart';

class LegalTalkBloc extends Bloc<LegalTalkEvent, LegalTalkState> {
  final GetTalkRoomsUseCase getTalkRoomsUseCase;
  final GetRoomMessagesUseCase getRoomMessagesUseCase;
  final SendTalkMessageUseCase sendTalkMessageUseCase;
  final LikeTalkMessageUseCase likeTalkMessageUseCase;
  final CreateTalkRoomUseCase createTalkRoomUseCase;

  List<TalkRoom> _allRoomsCache = [];

  LegalTalkBloc({
    required this.getTalkRoomsUseCase,
    required this.getRoomMessagesUseCase,
    required this.sendTalkMessageUseCase,
    required this.likeTalkMessageUseCase,
    required this.createTalkRoomUseCase,
  }) : super(LegalTalkInitial()) {
    on<LoadTalkRoomsEvent>(_onLoadTalkRooms);
    on<FilterTalkRoomsByCategoryEvent>(_onFilterByCategory);
    on<SearchTalkRoomsEvent>(_onSearchTalkRooms);
    on<EnterTalkRoomChatEvent>(_onEnterRoomChat);
    on<SendTalkMessageEvent>(_onSendTalkMessage);
    on<LikeTalkMessageEvent>(_onLikeTalkMessage);
    on<CreateTalkRoomEvent>(_onCreateTalkRoom);
  }

  Future<void> _onLoadTalkRooms(
    LoadTalkRoomsEvent event,
    Emitter<LegalTalkState> emit,
  ) async {
    emit(LegalTalkRoomsLoading());
    final result = await getTalkRoomsUseCase(
      GetTalkRoomsParams(
        category: event.category,
        searchQuery: event.searchQuery,
      ),
    );

    result.fold(
      (failure) => emit(LegalTalkError(failure.message)),
      (rooms) {
        _allRoomsCache = rooms;
        final liveRooms = rooms.where((r) => r.isLive).toList();
        emit(
          LegalTalkRoomsLoaded(
            allRooms: rooms,
            filteredRooms: rooms,
            liveRooms: liveRooms,
            selectedCategory: event.category ?? "Barchasi",
            searchQuery: event.searchQuery ?? "",
          ),
        );
      },
    );
  }

  void _onFilterByCategory(
    FilterTalkRoomsByCategoryEvent event,
    Emitter<LegalTalkState> emit,
  ) {
    if (state is LegalTalkRoomsLoaded) {
      final currentState = state as LegalTalkRoomsLoaded;
      final category = event.category;

      List<TalkRoom> filtered = _allRoomsCache;
      if (category.isNotEmpty && category != "Barchasi") {
        filtered = filtered.where((r) => r.category == category).toList();
      }

      if (currentState.searchQuery.isNotEmpty) {
        final q = currentState.searchQuery.toLowerCase();
        filtered = filtered
            .where((r) =>
                r.title.toLowerCase().contains(q) ||
                r.description.toLowerCase().contains(q))
            .toList();
      }

      emit(
        currentState.copyWith(
          filteredRooms: filtered,
          selectedCategory: category,
        ),
      );
    }
  }

  void _onSearchTalkRooms(
    SearchTalkRoomsEvent event,
    Emitter<LegalTalkState> emit,
  ) {
    if (state is LegalTalkRoomsLoaded) {
      final currentState = state as LegalTalkRoomsLoaded;
      final query = event.query.toLowerCase().trim();

      List<TalkRoom> filtered = _allRoomsCache;
      if (currentState.selectedCategory != "Barchasi") {
        filtered = filtered
            .where((r) => r.category == currentState.selectedCategory)
            .toList();
      }

      if (query.isNotEmpty) {
        filtered = filtered
            .where((r) =>
                r.title.toLowerCase().contains(query) ||
                r.description.toLowerCase().contains(query) ||
                r.category.toLowerCase().contains(query))
            .toList();
      }

      emit(
        currentState.copyWith(
          filteredRooms: filtered,
          searchQuery: event.query,
        ),
      );
    }
  }

  Future<void> _onEnterRoomChat(
    EnterTalkRoomChatEvent event,
    Emitter<LegalTalkState> emit,
  ) async {
    emit(LegalTalkRoomChatLoading());
    final result = await getRoomMessagesUseCase(event.room.id);

    result.fold(
      (failure) => emit(LegalTalkError(failure.message)),
      (messages) {
        emit(
          LegalTalkRoomChatLoaded(
            room: event.room,
            messages: messages,
          ),
        );
      },
    );
  }

  Future<void> _onSendTalkMessage(
    SendTalkMessageEvent event,
    Emitter<LegalTalkState> emit,
  ) async {
    if (state is LegalTalkRoomChatLoaded) {
      final currentChat = state as LegalTalkRoomChatLoaded;
      emit(currentChat.copyWith(isSending: true));

      final result = await sendTalkMessageUseCase(
        SendTalkMessageParams(
          roomId: event.roomId,
          senderName: event.senderName,
          senderRole: event.senderRole,
          messageText: event.text,
          isAudioMessage: event.isAudio,
          audioDuration: event.audioDuration,
        ),
      );

      result.fold(
        (failure) => emit(
          currentChat.copyWith(
            isSending: false,
            errorMessage: failure.message,
          ),
        ),
        (newMessage) {
          final updatedMessages = List.of(currentChat.messages)..add(newMessage);
          emit(
            currentChat.copyWith(
              isSending: false,
              messages: updatedMessages,
            ),
          );
        },
      );
    }
  }

  Future<void> _onLikeTalkMessage(
    LikeTalkMessageEvent event,
    Emitter<LegalTalkState> emit,
  ) async {
    if (state is LegalTalkRoomChatLoaded) {
      final currentChat = state as LegalTalkRoomChatLoaded;

      final result = await likeTalkMessageUseCase(
        LikeTalkMessageParams(
          roomId: event.roomId,
          messageId: event.messageId,
        ),
      );

      result.fold(
        (_) => null,
        (updatedMessage) {
          final updatedMessages = currentChat.messages.map((m) {
            return m.id == updatedMessage.id ? updatedMessage : m;
          }).toList();

          emit(
            currentChat.copyWith(
              messages: updatedMessages,
            ),
          );
        },
      );
    }
  }

  Future<void> _onCreateTalkRoom(
    CreateTalkRoomEvent event,
    Emitter<LegalTalkState> emit,
  ) async {
    final result = await createTalkRoomUseCase(
      CreateTalkRoomParams(
        title: event.title,
        category: event.category,
        description: event.description,
      ),
    );

    result.fold(
      (failure) => emit(LegalTalkError(failure.message)),
      (newRoom) {
        _allRoomsCache.insert(0, newRoom);
        final liveRooms = _allRoomsCache.where((r) => r.isLive).toList();
        emit(
          LegalTalkRoomsLoaded(
            allRooms: List.from(_allRoomsCache),
            filteredRooms: List.from(_allRoomsCache),
            liveRooms: liveRooms,
            selectedCategory: "Barchasi",
          ),
        );
      },
    );
  }
}
