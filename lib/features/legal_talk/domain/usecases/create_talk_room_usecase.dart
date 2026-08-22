import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';

class CreateTalkRoomParams {
  final String title;
  final String category;
  final String description;

  const CreateTalkRoomParams({
    required this.title,
    required this.category,
    required this.description,
  });
}

class CreateTalkRoomUseCase implements UseCase<TalkRoom, CreateTalkRoomParams> {
  final LegalTalkRepository repository;

  CreateTalkRoomUseCase(this.repository);

  @override
  Future<Either<Failure, TalkRoom>> call(CreateTalkRoomParams params) async {
    return await repository.createTalkRoom(
      title: params.title,
      category: params.category,
      description: params.description,
    );
  }
}
