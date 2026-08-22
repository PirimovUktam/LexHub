import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';

class MockAuthRepository implements AuthRepository {
  UserEntity? mockUser;
  UserProfileEntity? mockProfile;
  bool throwError = false;

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (throwError) return const Left(ServerFailure(message: 'Invalid credentials'));
    return Right(mockUser ?? UserEntity(id: 'u1', email: email, createdAt: DateTime.now()));
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (throwError) return const Left(ServerFailure(message: 'Email already registered'));
    return Right(mockUser ?? UserEntity(id: 'u1', email: email, createdAt: DateTime.now()));
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    mockUser = null;
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    return Right(mockUser);
  }

  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile(String userId) async {
    if (throwError) return const Left(ServerFailure(message: 'Profile not found'));
    return Right(
      mockProfile ??
          UserProfileEntity(
            id: userId,
            fullName: 'Test User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );
  }

  @override
  Future<Either<Failure, UserProfileEntity>> updateUserProfile(UserProfileEntity profile) async {
    mockProfile = profile;
    return Right(profile);
  }

  final StreamController<UserEntity?> _authController = StreamController<UserEntity?>.broadcast();

  @override
  Stream<UserEntity?> get authStateChanges => _authController.stream;

  void emitAuthState(UserEntity? user) {
    _authController.add(user);
  }

  void dispose() {
    _authController.close();
  }
}

void main() {
  late MockAuthRepository repository;
  late SignInWithEmailUseCase signInUseCase;
  late SignUpWithEmailUseCase signUpUseCase;
  late SignOutUseCase signOutUseCase;
  late GetCurrentUserUseCase getCurrentUserUseCase;
  late GetUserProfileUseCase getUserProfileUseCase;
  late UpdateUserProfileUseCase updateUserProfileUseCase;

  setUp(() {
    repository = MockAuthRepository();
    signInUseCase = SignInWithEmailUseCase(repository);
    signUpUseCase = SignUpWithEmailUseCase(repository);
    signOutUseCase = SignOutUseCase(repository);
    getCurrentUserUseCase = GetCurrentUserUseCase(repository);
    getUserProfileUseCase = GetUserProfileUseCase(repository);
    updateUserProfileUseCase = UpdateUserProfileUseCase(repository);
  });

  test('SignInWithEmailUseCase signs in user successfully', () async {
    final result = await signInUseCase(
      const SignInWithEmailParams(email: 'test@lexhub.uz', password: 'password123'),
    );

    expect(result.isRight(), isTrue);
    result.fold((_) => null, (user) {
      expect(user.email, 'test@lexhub.uz');
    });
  });

  test('SignUpWithEmailUseCase registers user successfully', () async {
    final result = await signUpUseCase(
      const SignUpWithEmailParams(
        email: 'newuser@lexhub.uz',
        password: 'password123',
        fullName: 'Bobur',
      ),
    );

    expect(result.isRight(), isTrue);
    result.fold((_) => null, (user) {
      expect(user.email, 'newuser@lexhub.uz');
    });
  });

  test('SignOutUseCase completes successfully', () async {
    final result = await signOutUseCase(const NoParams());
    expect(result.isRight(), isTrue);
  });

  test('GetUserProfileUseCase returns profile data', () async {
    final result = await getUserProfileUseCase('u1');
    expect(result.isRight(), isTrue);
    result.fold((_) => null, (profile) {
      expect(profile.id, 'u1');
      expect(profile.fullName, 'Test User');
      expect(profile.role, UserRole.citizen);
    });
  });

  test('GetCurrentUserUseCase returns current user entity', () async {
    repository.mockUser = UserEntity(id: 'u1', email: 'test@lexhub.uz', createdAt: DateTime.now());
    final result = await getCurrentUserUseCase(const NoParams());
    expect(result.isRight(), isTrue);
    result.fold((_) => null, (user) {
      expect(user?.email, 'test@lexhub.uz');
    });
  });

  test('UpdateUserProfileUseCase updates profile successfully', () async {
    final updatedProfile = UserProfileEntity(
      id: 'u1',
      fullName: 'Updated Name',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final result = await updateUserProfileUseCase(updatedProfile);
    expect(result.isRight(), isTrue);
    result.fold((_) => null, (profile) {
      expect(profile.fullName, 'Updated Name');
    });
  });
}
