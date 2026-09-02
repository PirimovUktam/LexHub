import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final SignUpWithEmailUseCase signUpWithEmailUseCase;
  final SignOutUseCase signOutUseCase;
  final GetUserProfileUseCase getUserProfileUseCase;
  final UpdateUserProfileUseCase updateUserProfileUseCase;

  StreamSubscription? _authSubscription;

  AuthBloc({
    required this.authRepository,
    required this.getCurrentUserUseCase,
    required this.signInWithEmailUseCase,
    required this.signUpWithEmailUseCase,
    required this.signOutUseCase,
    required this.getUserProfileUseCase,
    required this.updateUserProfileUseCase,
  }) : super(const AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<AuthStateChangedEvent>(_onAuthStateChanged);
    on<SignInWithEmailEvent>(_onSignInWithEmail);
    on<SignUpWithEmailEvent>(_onSignUpWithEmail);
    on<SignOutEvent>(_onSignOut);
    on<LoadUserProfileEvent>(_onLoadUserProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);

    // Listen to real-time auth state changes from Supabase
    _authSubscription = authRepository.authStateChanges.listen((user) {
      add(AuthStateChangedEvent(user));
    });
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Sessiya tekshirilmoqda...'));
    final result = await getCurrentUserUseCase(const NoParams());

    await result.fold(
      (failure) async => emit(const Unauthenticated()),
      (user) async {
        if (user != null) {
          final profileResult = await getUserProfileUseCase(user.id);
          profileResult.fold(
            (_) => emit(Authenticated(user: user)),
            (profile) => emit(Authenticated(user: user, profile: profile)),
          );
        } else {
          emit(const Unauthenticated());
        }
      },
    );
  }

  Future<void> _onAuthStateChanged(
    AuthStateChangedEvent event,
    Emitter<AuthState> emit,
  ) async {
    final user = event.user;
    if (user != null) {
      final currentUserId = state is Authenticated ? (state as Authenticated).user.id : null;
      if (currentUserId != user.id) {
        final profileResult = await getUserProfileUseCase(user.id);
        profileResult.fold(
          (_) => emit(Authenticated(user: user)),
          (profile) => emit(Authenticated(user: user, profile: profile)),
        );
      }
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Tizimga kirilmoqda...'));

    final result = await signInWithEmailUseCase(
      SignInWithEmailParams(email: event.email, password: event.password),
    );

    await result.fold(
      (failure) async => emit(AuthFailure(failure.message, code: failure.code)),
      (user) async {
        final profileResult = await getUserProfileUseCase(user.id);
        profileResult.fold(
          (_) => emit(Authenticated(user: user)),
          (profile) => emit(Authenticated(user: user, profile: profile)),
        );
      },
    );
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Ro\'yxatdan o\'tilmoqda...'));

    final result = await signUpWithEmailUseCase(
      SignUpWithEmailParams(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
      ),
    );

    await result.fold(
      (failure) async {
        // EMAIL TASDIQLASH — XATO EMAS, KO'RSATMA.
        //
        // Datasource `session == null` bo'lganda
        // `EmailConfirmationRequiredException` tashlaydi va `ErrorHandler`
        // uni shu kodga o'giradi. Qizil `AuthFailure` ko'rsatilsa
        // foydalanuvchi hisobi YARATILGANINI bilmay, qayta-qayta ro'yxatdan
        // o'tishga urinardi ("bu email allaqachon band" xatosini olib).
        if (failure.code == FailureCode.emailConfirmationRequired) {
          emit(EmailConfirmationRequired(email: event.email.trim()));
          return;
        }
        emit(AuthFailure(failure.message, code: failure.code));
      },
      (user) async {
        final profileResult = await getUserProfileUseCase(user.id);
        profileResult.fold(
          (_) => emit(Authenticated(user: user)),
          (profile) => emit(Authenticated(user: user, profile: profile)),
        );
      },
    );
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Tizimdan chiqilmoqda...'));
    final result = await signOutUseCase(const NoParams());

    result.fold(
      (failure) => emit(AuthFailure(failure.message, code: failure.code)),
      (_) => emit(const Unauthenticated()),
    );
  }

  Future<void> _onLoadUserProfile(
    LoadUserProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (state is Authenticated) {
      final current = state as Authenticated;
      final profileResult = await getUserProfileUseCase(event.userId);
      profileResult.fold(
        (_) => null,
        (profile) => emit(current.copyWith(profile: profile)),
      );
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (state is Authenticated) {
      final current = state as Authenticated;
      final result = await updateUserProfileUseCase(event.profile);
      result.fold(
        (failure) => emit(AuthFailure(failure.message, code: failure.code)),
        (updated) => emit(current.copyWith(profile: updated)),
      );
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
