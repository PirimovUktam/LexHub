import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/legal_talk/data/datasources/legal_talk_local_datasource.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';

class LegalTalkRepositoryImpl implements LegalTalkRepository {
  final LegalTalkLocalDataSource localDataSource;

  LegalTalkRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<TalkRoom>>> getTalkRooms({
    String? category,
    String? searchQuery,
  }) async {
    try {
      final rooms = await localDataSource.getRooms(
        category: category,
        searchQuery: searchQuery,
      );
      return Right(rooms);
    } catch (e) {
      return Left(CacheFailure(message: "Xonalarni yuklashda xatolik: $e"));
    }
  }

  @override
  Future<Either<Failure, List<TalkMessage>>> getRoomMessages(String roomId) async {
    try {
      final messages = await localDataSource.getRoomMessages(roomId);
      return Right(messages);
    } catch (e) {
      return Left(CacheFailure(message: "Xabarlarni yuklashda xatolik: $e"));
    }
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
    try {
      final message = await localDataSource.sendMessage(
        roomId: roomId,
        senderName: senderName,
        senderRole: senderRole,
        messageText: messageText,
        isAudioMessage: isAudioMessage,
        audioDuration: audioDuration,
      );
      return Right(message);
    } catch (e) {
      return Left(CacheFailure(message: "Xabar yuborishda xatolik: $e"));
    }
  }

  @override
  Future<Either<Failure, TalkMessage>> toggleMessageLike({
    required String roomId,
    required String messageId,
  }) async {
    try {
      final message = await localDataSource.toggleLike(
        roomId: roomId,
        messageId: messageId,
      );
      return Right(message);
    } catch (e) {
      return Left(CacheFailure(message: "Reaksiya bildirishda xatolik: $e"));
    }
  }

  @override
  Future<Either<Failure, TalkRoom>> createTalkRoom({
    required String title,
    required String category,
    required String description,
  }) async {
    try {
      final room = await localDataSource.createRoom(
        title: title,
        category: category,
        description: description,
      );
      return Right(room);
    } catch (e) {
      return Left(CacheFailure(message: "Xona yaratishda xatolik: $e"));
    }
  }
}
