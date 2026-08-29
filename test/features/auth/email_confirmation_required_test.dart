/// EMAIL TASDIQLASH HOLATI — JIM YOLG'ON MUVAFFAQIYAT QULFI (§20).
///
/// MUAMMO: Supabase'da "Confirm email" yoqilsa `signUp` javobi
/// `user != null`, `session == null` bo'ladi. Ilgari `auth_remote_datasource`
/// javobning FAQAT `user` maydonini ko'rardi va `AuthBloc` darhol
/// `Authenticated` chiqarardi — ya'ni ilova o'zini kirgan deb hisoblardi,
/// keyin har bir so'rov ANON huquqi bilan ketardi.
///
/// ISBOT DARAJASI (CLAIM != EVIDENCE): bu fayl KLIENT mantiqini tekshiradi
/// (`ErrorHandler` moslashi, bloc holati, datasource manbasi). U serverda
/// `mailer_autoconfirm` o'chirilganini ISBOTLAMAYDI — o'lchov bo'yicha
/// (2026-08-29, `GET /auth/v1/settings`) hozir `mailer_autoconfirm: true`,
/// ya'ni bu yo'l runtime'da HOZIRCHA ishga tushmaydi.
library;

import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart' as f;
import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:lexhub/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/get_user_profile_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:lexhub/features/auth/domain/usecases/update_user_profile_usecase.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';

import 'domain/usecases/auth_usecases_test.dart';

/// `signUp` hisob yaratdi, LEKIN sessiya bermadi.
class _ConfirmRequiredRepository extends MockAuthRepository {
  @override
  Future<Either<f.Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return Left(
      ErrorHandler.handle(const EmailConfirmationRequiredException()),
    );
  }
}

void main() {
  group('1. `ErrorHandler` — email tasdiqlash XATO deb ko\'rsatilmaydi', () {
    test('kod `emailConfirmationRequired`, `server` EMAS', () {
      final failure =
          ErrorHandler.handle(const EmailConfirmationRequiredException());
      expect(failure.code, FailureCode.emailConfirmationRequired);
      // `EmailConfirmationRequiredException` ham `AppException` avlodi —
      // umumiy shox uni yutib `FailureCode.server` berardi.
      expect(failure.code, isNot(FailureCode.server));
      expect(failure, isA<f.AuthFailure>());
    });

    test('soxta HTTP status QO\'YILMAYDI (javob 200 edi)', () {
      final failure =
          ErrorHandler.handle(const EmailConfirmationRequiredException());
      expect(failure.statusCode, isNull);
    });
  });

  group('2. `AuthBloc` — `Authenticated` EMAS', () {
    test('`EmailConfirmationRequired` chiqadi va email SAQLANADI', () async {
      final bloc = AuthBloc(
        authRepository: _ConfirmRequiredRepository(),
        getCurrentUserUseCase: GetCurrentUserUseCase(MockAuthRepository()),
        signInWithEmailUseCase: SignInWithEmailUseCase(MockAuthRepository()),
        signUpWithEmailUseCase:
            SignUpWithEmailUseCase(_ConfirmRequiredRepository()),
        signOutUseCase: SignOutUseCase(MockAuthRepository()),
        getUserProfileUseCase: GetUserProfileUseCase(MockAuthRepository()),
        updateUserProfileUseCase:
            UpdateUserProfileUseCase(MockAuthRepository()),
      );
      addTearDown(bloc.close);

      final states = expectLater(
        bloc.stream,
        emitsInOrder(<Object>[
          const AuthLoading(message: 'Ro\'yxatdan o\'tilmoqda...'),
          const EmailConfirmationRequired(email: 'yangi@lexhub.uz'),
        ]),
      );

      bloc.add(const SignUpWithEmailEvent(
        fullName: 'Test Foydalanuvchi',
        email: '  yangi@lexhub.uz  ',
        password: 'parol123',
      ));

      await states;
    });
  });

  group('3. MANBA QULFI — sessiya tekshiruvi joyida turadi', () {
    test('datasource `session == null` holatini ushlaydi', () {
      final src = File('lib/features/auth/data/datasources/'
              'auth_remote_datasource.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(src.contains('if (response.session == null)'), isTrue,
          reason: 'sessiya tekshiruvi olib tashlansa `signUp` yana JIM '
              '`Authenticated` beradi');
      expect(src.contains('throw EmailConfirmationRequiredException('), isTrue);
      // Umumiy `catch` `AppException` ni O'RAMASLIGI shart, aks holda signal
      // `ServerException` ichida yo'qoladi va qizil xato ko'rinadi.
      expect(src.contains('if (e is AppException) rethrow;'), isTrue);
    });

    test('bloc bu kodni ALOHIDA holatga o\'giradi', () {
      final src =
          File('lib/features/auth/presentation/bloc/auth_bloc.dart')
              .readAsStringSync()
              .replaceAll(RegExp(r'\s+'), ' ');
      expect(
          src.contains(
              'failure.code == FailureCode.emailConfirmationRequired'),
          isTrue);
      expect(src.contains('emit(EmailConfirmationRequired('), isTrue);
    });
  });
}
