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

/// HISOB YARATILDI, LEKIN SESSIYA YO'Q — email tasdiqlash kerak.
///
/// `AuthFailure` DAN ALOHIDA holat: bu nosozlik EMAS, shuning uchun UI qizil
/// xato SnackBar'i emas, ko'rsatma paneli ko'rsatadi. `Authenticated` HAM
/// EMAS: sessiya yo'q, ya'ni ilova o'zini kirgan deb hisoblasa har bir
/// so'rov anon huquqi bilan ketib jim buzilardi (§20).
class EmailConfirmationRequired extends AuthState {
  /// Tasdiqlash xati YUBORILGAN manzil — foydalanuvchi qaysi pochtani
  /// ochishini bilishi uchun ko'rsatiladi.
  final String email;

  const EmailConfirmationRequired({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthFailure extends AuthState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const AuthFailure(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}
