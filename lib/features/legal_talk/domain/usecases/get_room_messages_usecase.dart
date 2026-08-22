import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';

class GetRoomMessagesUseCase implements UseCase<List<TalkMessage>, String> {
  final LegalTalkRepository repository;

  GetRoomMessagesUseCase(this.repository);

  @override
  Future<Either<Failure, List<TalkMessage>>> call(String roomId) async {
    return await repository.getRoomMessages(roomId);
  }
}
