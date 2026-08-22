import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late MockAuthRepository repository;
  late AuthBloc authBloc;

  setUp(() {
    repository = MockAuthRepository();
    authBloc = AuthBloc(
      authRepository: repository,
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      signInWithEmailUseCase: SignInWithEmailUseCase(repository),
      signUpWithEmailUseCase: SignUpWithEmailUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getUserProfileUseCase: GetUserProfileUseCase(repository),
      updateUserProfileUseCase: UpdateUserProfileUseCase(repository),
    );
  });

  tearDown(() {
    authBloc.close();
  });

  test('initial state should be AuthInitial', () {
    expect(authBloc.state, equals(const AuthInitial()));
  });

  test('emits [AuthLoading, Unauthenticated] on CheckAuthStatusEvent when no user is logged in', () async {
    final expectedStates = [
      const AuthLoading(message: 'Sessiya tekshirilmoqda...'),
      const Unauthenticated(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));

    authBloc.add(const CheckAuthStatusEvent());
  });

  test('emits [AuthLoading, Authenticated] on SignInWithEmailEvent when credentials are valid', () async {
    final user = UserEntity(id: 'u1', email: 'test@lexhub.uz', createdAt: DateTime.now());
    final profile = UserProfileEntity(
      id: 'u1',
      fullName: 'Test User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    repository.mockUser = user;
    repository.mockProfile = profile;

    final expectedStates = [
      const AuthLoading(message: 'Tizimga kirilmoqda...'),
      Authenticated(user: user, profile: profile),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));

    authBloc.add(const SignInWithEmailEvent(email: 'test@lexhub.uz', password: 'password123'));
  });

  test('emits [AuthLoading, AuthFailure] on SignInWithEmailEvent when error occurs', () async {
    repository.throwError = true;

    final expectedStates = [
      const AuthLoading(message: 'Tizimga kirilmoqda...'),
      const AuthFailure('Invalid credentials'),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));

    authBloc.add(const SignInWithEmailEvent(email: 'wrong@lexhub.uz', password: 'bad'));
  });

  test('emits [AuthLoading, Unauthenticated] on SignOutEvent', () async {
    final expectedStates = [
      const AuthLoading(message: 'Tizimdan chiqilmoqda...'),
      const Unauthenticated(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));

    authBloc.add(const SignOutEvent());
  });
}
