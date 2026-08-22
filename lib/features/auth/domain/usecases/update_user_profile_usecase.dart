import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';

class UpdateUserProfileUseCase implements UseCase<UserProfileEntity, UserProfileEntity> {
  final AuthRepository repository;

  UpdateUserProfileUseCase(this.repository);

  @override
  Future<Either<Failure, UserProfileEntity>> call(UserProfileEntity profile) async {
    return await repository.updateUserProfile(profile);
  }
}
