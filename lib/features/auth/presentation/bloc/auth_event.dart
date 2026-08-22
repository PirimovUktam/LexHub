import 'package:equatable/equatable.dart';
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when application starts to check existing session
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

/// Dispatched when user signs in with email & password
class SignInWithEmailEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Dispatched when user registers with email & password
class SignUpWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  final String fullName;

  const SignUpWithEmailEvent({
    required this.email,
    required this.password,
    required this.fullName,
  });

  @override
  List<Object?> get props => [email, password, fullName];
}

/// Dispatched when user clicks sign out
class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}

/// Internal event when Supabase auth session changes
class AuthStateChangedEvent extends AuthEvent {
  final UserEntity? user;

  const AuthStateChangedEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Dispatched to refresh user profile data
class LoadUserProfileEvent extends AuthEvent {
  final String userId;

  const LoadUserProfileEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Dispatched to update user profile
class UpdateProfileEvent extends AuthEvent {
  final UserProfileEntity profile;

  const UpdateProfileEvent(this.profile);

  @override
  List<Object?> get props => [profile];
}
