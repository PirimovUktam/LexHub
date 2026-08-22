import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/create_talk_room_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/get_room_messages_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/get_talk_rooms_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/like_talk_message_usecase.dart';
import 'package:lexhub/features/legal_talk/domain/usecases/send_talk_message_usecase.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_bloc.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_event.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_state.dart';

class MockLegalTalkRepository implements LegalTalkRepository {
  List<TalkRoom> mockRooms = [
    TalkRoom(
      id: 'room_1',
      title: "Jonli Mehnat Muhokamasi",
      category: "Mehnat",
      description: "Mehnat qonunchiligi bo'yicha",
      participantsCount: 50,
      activeNowCount: 12,
      isLive: true,
      createdAt: DateTime.now(),
    ),
    TalkRoom(
      id: 'room_2',
      title: "Haydovchilar va YPX",
      category: "Haydovchilar",
      description: "Guvohnoma va jarimalar",
      participantsCount: 30,
      activeNowCount: 5,
      isLive: false,
      createdAt: DateTime.now(),
    ),
  ];

  Map<String, List<TalkMessage>> mockMessages = {
    'room_1': [
      TalkMessage(
        id: 'msg_1',
        roomId: 'room_1',
        senderName: 'Advokat Jamshid',
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText: 'Savollaringizni bering',
        timestamp: DateTime.now(),
        likesCount: 5,
        isLikedByMe: false,
      ),
    ],
  };

  @override
  Future<Either<Failure, List<TalkRoom>>> getTalkRooms({
    String? category,
    String? searchQuery,
  }) async {
    var result = List<TalkRoom>.from(mockRooms);
    if (category != null && category != "Barchasi") {
      result = result.where((r) => r.category == category).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = result.where((r) => r.title.contains(searchQuery)).toList();
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, List<TalkMessage>>> getRoomMessages(String roomId) async {
    return Right(List<TalkMessage>.from(mockMessages[roomId] ?? []));
  }

  @override
  Future<Either<Failure, TalkMessage>> sendMessage({
    required String roomId,
    required String senderName,
    required TalkSenderRole senderRole,
    required String messageText,
    bool isAudioMessage = false,
    String? audioDuration,
  }) async {
    final msg = TalkMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderName: senderName,
      senderRole: senderRole,
      messageText: messageText,
      timestamp: DateTime.now(),
      likesCount: 0,
      isAudioMessage: isAudioMessage,
      audioDuration: audioDuration,
      isLikedByMe: false,
    );
    mockMessages[roomId] = (mockMessages[roomId] ?? [])..add(msg);
    return Right(msg);
  }

  @override
  Future<Either<Failure, TalkMessage>> toggleMessageLike({
    required String roomId,
    required String messageId,
  }) async {
    final list = mockMessages[roomId] ?? [];
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final old = list[idx];
      final updated = old.copyWith(
        likesCount: old.likesCount + (old.isLikedByMe ? -1 : 1),
        isLikedByMe: !old.isLikedByMe,
      );
      list[idx] = updated;
      return Right(updated);
    }
    return const Left(CacheFailure(message: "Not found"));
  }

  @override
  Future<Either<Failure, TalkRoom>> createTalkRoom({
    required String title,
    required String category,
    required String description,
  }) async {
    final newRoom = TalkRoom(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      description: description,
      participantsCount: 1,
      activeNowCount: 1,
      isLive: true,
      createdAt: DateTime.now(),
    );
    mockRooms.insert(0, newRoom);
    return Right(newRoom);
  }
}

void main() {
  late MockLegalTalkRepository mockRepo;
  late GetTalkRoomsUseCase getTalkRoomsUseCase;
  late GetRoomMessagesUseCase getRoomMessagesUseCase;
  late SendTalkMessageUseCase sendTalkMessageUseCase;
  late LikeTalkMessageUseCase likeTalkMessageUseCase;
  late CreateTalkRoomUseCase createTalkRoomUseCase;
  late LegalTalkBloc bloc;

  setUp(() {
    mockRepo = MockLegalTalkRepository();
    getTalkRoomsUseCase = GetTalkRoomsUseCase(mockRepo);
    getRoomMessagesUseCase = GetRoomMessagesUseCase(mockRepo);
    sendTalkMessageUseCase = SendTalkMessageUseCase(mockRepo);
    likeTalkMessageUseCase = LikeTalkMessageUseCase(mockRepo);
    createTalkRoomUseCase = CreateTalkRoomUseCase(mockRepo);

    bloc = LegalTalkBloc(
      getTalkRoomsUseCase: getTalkRoomsUseCase,
      getRoomMessagesUseCase: getRoomMessagesUseCase,
      sendTalkMessageUseCase: sendTalkMessageUseCase,
      likeTalkMessageUseCase: likeTalkMessageUseCase,
      createTalkRoomUseCase: createTalkRoomUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be LegalTalkInitial', () {
    expect(bloc.state, equals(LegalTalkInitial()));
  });

  test('emits LegalTalkRoomsLoading and LegalTalkRoomsLoaded on LoadTalkRoomsEvent', () async {
    final expectedStates = [
      isA<LegalTalkRoomsLoading>(),
      isA<LegalTalkRoomsLoaded>(),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));
    bloc.add(const LoadTalkRoomsEvent());
  });

  test('filters discussion rooms by category correctly', () async {
    bloc.add(const LoadTalkRoomsEvent());
    await expectLater(bloc.stream, emitsThrough(isA<LegalTalkRoomsLoaded>()));

    bloc.add(const FilterTalkRoomsByCategoryEvent('Mehnat'));
    await expectLater(
      bloc.stream,
      emits(
        predicate<LegalTalkState>((state) {
          if (state is LegalTalkRoomsLoaded) {
            return state.selectedCategory == 'Mehnat' &&
                state.filteredRooms.length == 1 &&
                state.filteredRooms.first.category == 'Mehnat';
          }
          return false;
        }),
      ),
    );
  });

  test('searches discussion rooms by query correctly', () async {
    bloc.add(const LoadTalkRoomsEvent());
    await expectLater(bloc.stream, emitsThrough(isA<LegalTalkRoomsLoaded>()));

    bloc.add(const SearchTalkRoomsEvent('Haydovchilar'));
    await expectLater(
      bloc.stream,
      emits(
        predicate<LegalTalkState>((state) {
          if (state is LegalTalkRoomsLoaded) {
            return state.filteredRooms.length == 1 &&
                state.filteredRooms.first.title.contains('Haydovchilar');
          }
          return false;
        }),
      ),
    );
  });

  test('enters room chat and loads messages successfully', () async {
    final room = mockRepo.mockRooms.first;
    bloc.add(EnterTalkRoomChatEvent(room));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<LegalTalkRoomChatLoading>(),
        predicate<LegalTalkState>((state) {
          if (state is LegalTalkRoomChatLoaded) {
            return state.room.id == room.id && state.messages.isNotEmpty;
          }
          return false;
        }),
      ]),
    );
  });

  test('sends talk message and updates chat state', () async {
    final room = mockRepo.mockRooms.first;
    bloc.add(EnterTalkRoomChatEvent(room));
    await expectLater(bloc.stream, emitsThrough(isA<LegalTalkRoomChatLoaded>()));

    bloc.add(SendTalkMessageEvent(
      roomId: room.id,
      text: "Yangi savol matni",
      senderName: "Test Fuqaro",
      senderRole: TalkSenderRole.citizen,
    ));

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<LegalTalkState>((state) {
          if (state is LegalTalkRoomChatLoaded) {
            return state.messages.any((m) => m.messageText == "Yangi savol matni");
          }
          return false;
        }),
      ),
    );
  });

  test('likes talk message and updates like count', () async {
    final room = mockRepo.mockRooms.first;
    bloc.add(EnterTalkRoomChatEvent(room));
    await expectLater(bloc.stream, emitsThrough(isA<LegalTalkRoomChatLoaded>()));

    bloc.add(LikeTalkMessageEvent(
      roomId: room.id,
      messageId: 'msg_1',
    ));

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<LegalTalkState>((state) {
          if (state is LegalTalkRoomChatLoaded) {
            final msg = state.messages.firstWhere((m) => m.id == 'msg_1');
            return msg.likesCount == 6 && msg.isLikedByMe == true;
          }
          return false;
        }),
      ),
    );
  });

  test('creates a new discussion room and prepends to list', () async {
    bloc.add(const LoadTalkRoomsEvent());
    await expectLater(bloc.stream, emitsThrough(isA<LegalTalkRoomsLoaded>()));

    bloc.add(const CreateTalkRoomEvent(
      title: "Yangi ochilgan xona",
      category: "Uy-joy",
      description: "Uy-joy nizolari",
    ));

    await expectLater(
      bloc.stream,
      emits(
        predicate<LegalTalkState>((state) {
          if (state is LegalTalkRoomsLoaded) {
            return state.allRooms.first.title == "Yangi ochilgan xona" &&
                state.allRooms.length == 3;
          }
          return false;
        }),
      ),
    );
  });
}
