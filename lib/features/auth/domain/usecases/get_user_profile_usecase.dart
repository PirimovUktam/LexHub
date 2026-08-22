import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';

class GetUserProfileUseCase implements UseCase<UserProfileEntity, String> {
  final AuthRepository repository;

  GetUserProfileUseCase(this.repository);

  @override
  Future<Either<Failure, UserProfileEntity>> call(String userId) async {
    return await repository.getUserProfile(userId);
  }
}
