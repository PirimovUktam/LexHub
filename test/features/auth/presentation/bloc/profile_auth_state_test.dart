// 2026-09-21: profile requests must not resurrect logged-out/other accounts.
// Real AuthBloc with synthetic repository; not Supabase session revocation proof.
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import '../../domain/usecases/auth_usecases_test.dart';

class _Repository extends MockAuthRepository {
  Completer<Either<Failure, UserProfileEntity>>? pending;
  int updates = 0;
  bool fail = false;
  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile(String userId) =>
      pending?.future ?? super.getUserProfile(userId);
  @override
  Future<Either<Failure, UserProfileEntity>> updateUserProfile(
      UserProfileEntity profile) async {
    updates++;
    if (fail) {
      return const Left(ServerFailure(message: '', code: FailureCode.server));
    }
    return pending?.future ?? super.updateUserProfile(profile);
  }
}

void main() {
  late _Repository repo;
  late AuthBloc bloc;
  final profile = UserProfileEntity(
      id: 'owner',
      fullName: 'Synthetic',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  setUp(() async {
    repo = _Repository()
      ..mockUser =
          const UserEntity(id: 'owner', email: 'synthetic@example.invalid')
      ..mockProfile = profile;
    bloc = AuthBloc(
        authRepository: repo,
        getCurrentUserUseCase: GetCurrentUserUseCase(repo),
        signInWithEmailUseCase: SignInWithEmailUseCase(repo),
        signUpWithEmailUseCase: SignUpWithEmailUseCase(repo),
        signOutUseCase: SignOutUseCase(repo),
        getUserProfileUseCase: GetUserProfileUseCase(repo),
        updateUserProfileUseCase: UpdateUserProfileUseCase(repo));
    final ready = bloc.stream.firstWhere((state) => state is Authenticated);
    bloc.add(const CheckAuthStatusEvent());
    await ready;
  });
  tearDown(() async {
    await bloc.close();
    repo.dispose();
  });
  test(
      'save error preserves authenticated user and exposes typed profile error',
      () async {
    repo.fail = true;
    final changed = bloc.stream.firstWhere(
        (state) => state is Authenticated && state.profileError != null);
    bloc.add(UpdateProfileEvent(profile));
    final result = await changed;
    expect(
        result,
        isA<Authenticated>()
            .having((state) => state.user.id, 'user', 'owner')
            .having(
                (state) => state.profileError, 'error', FailureCode.server));
  });
  for (final update in [false, true]) {
    test('late ${update ? 'save' : 'load'} cannot restore a logged-out account',
        () async {
      repo.pending = Completer<Either<Failure, UserProfileEntity>>();
      bloc.add(update
          ? UpdateProfileEvent(profile)
          : const LoadUserProfileEvent('owner'));
      await Future<void>.delayed(Duration.zero);
      final signedOut =
          bloc.stream.firstWhere((state) => state is Unauthenticated);
      bloc.add(const AuthStateChangedEvent(null));
      await signedOut;
      repo.pending?.complete(Right(profile));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<Unauthenticated>());
    });
  }
  test('wrong-owner profile update never reaches repository', () async {
    bloc.add(UpdateProfileEvent(profile.copyWith(id: 'outsider')));
    await Future<void>.delayed(Duration.zero);
    expect(repo.updates, 0);
    expect(bloc.state,
        isA<Authenticated>().having((s) => s.user.id, 'user', 'owner'));
  });
}
