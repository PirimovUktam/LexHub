import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';
import 'package:lexhub/features/legal_talk/domain/repositories/legal_talk_repository.dart';

class GetTalkRoomsParams {
  final String? category;
  final String? searchQuery;

  const GetTalkRoomsParams({
    this.category,
    this.searchQuery,
  });
}

class GetTalkRoomsUseCase implements UseCase<List<TalkRoom>, GetTalkRoomsParams?> {
  final LegalTalkRepository repository;

  GetTalkRoomsUseCase(this.repository);

  @override
  Future<Either<Failure, List<TalkRoom>>> call(GetTalkRoomsParams? params) async {
    return await repository.getTalkRooms(
      category: params?.category,
      searchQuery: params?.searchQuery,
    );
  }
}
