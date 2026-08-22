import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  final String? message;

  const AuthLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class Authenticated extends AuthState {
  final UserEntity user;
  final UserProfileEntity? profile;

  const Authenticated({
    required this.user,
    this.profile,
  });

  Authenticated copyWith({
    UserEntity? user,
    UserProfileEntity? profile,
  }) {
    return Authenticated(
      user: user ?? this.user,
      profile: profile ?? this.profile,
    );
  }

  @override
  List<Object?> get props => [user, profile];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthFailure extends AuthState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const AuthFailure(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}
