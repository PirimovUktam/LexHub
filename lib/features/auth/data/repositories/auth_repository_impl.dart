import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lexhub/features/auth/data/models/user_profile_model.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';

/// Auth repozitoriysi — barcha xatolar MARKAZDAN (`ErrorHandler.handle`)
/// o'tadi.
///
/// ILGARI bu qatlamda har bir metod ikki shox tutardi:
/// `on ServerException -> ServerFailure(message: e.message)` va
/// `catch (e) -> ServerFailure(message: e.toString())`. Ikkisining ham
/// kamchiligi bor edi:
///   * `code` (`FailureCode`) HECH QACHON to'ldirilmasdi — ya'ni ingliz UI
///     xato matnini ARB'dan tanlay olmasdi (`failureText` kodga qarab
///     ishlaydi), `sanitizeUserMessage` ham chaqirilmasdi;
///   * generic shox XOM `e.toString()` ni to'g'ridan-to'g'ri ekranga
///     uzatardi — `TimeoutException` qo'shilgandan keyin bu foydalanuvchiga
///     "TimeoutException after 0:00:30.000000: auth_sign_up" ko'rsatgan
///     bo'lardi.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(user);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final user = await remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      return Right(user);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      return Right(user);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile(String userId) async {
    try {
      final profile = await remoteDataSource.getUserProfile(userId);
      return Right(profile);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, UserProfileEntity>> updateUserProfile(UserProfileEntity profile) async {
    try {
      final model = UserProfileModel(
        id: profile.id,
        fullName: profile.fullName,
        avatarUrl: profile.avatarUrl,
        phone: profile.phone,
        role: profile.role,
        reputationPoints: profile.reputationPoints,
        isVerified: profile.isVerified,
        bio: profile.bio,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
      );
      final updated = await remoteDataSource.updateUserProfile(model);
      return Right(updated);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges => remoteDataSource.authStateChanges;
}
