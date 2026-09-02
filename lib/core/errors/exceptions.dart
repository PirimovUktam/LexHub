/// Base Exception for application level errors
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const AppException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'AppException: $message (code: $statusCode)';
}

/// Server API exception
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// No Internet / Socket exception
class NetworkException extends AppException {
  const NetworkException({
    super.message = "Internet tarmog'iga ulanishda xatolik yuz berdi.",
    super.statusCode,
    super.details,
  });
}

/// Local database / Cache exception
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Validation exception
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// `signUp` MUVAFFAQIYATLI, LEKIN SESSIYA BERILMAGAN.
///
/// Supabase Auth'da "Confirm email" yoqilgan bo'lsa `signUp` javobi
/// `user != null`, `session == null` bo'ladi: hisob YARATILGAN, biroq
/// foydalanuvchi TIZIMGA KIRMAGAN. Bu holat xato EMAS, lekin MUVAFFAQIYAT
/// deb ko'rsatilsa (§20 jim yolg'on) ilova o'zini kirgan deb hisoblaydi,
/// keyin har bir so'rov anon huquqi bilan ketadi va foydalanuvchi sababini
/// bilmaydigan bo'sh/RLS xatolarini ko'radi.
///
/// Shu sababli alohida sinf: `ErrorHandler` uni
/// `FailureCode.emailConfirmationRequired` ga o'giradi va `AuthBloc`
/// `EmailConfirmationRequired` holatini chiqaradi (qizil xato SnackBar EMAS).
class EmailConfirmationRequiredException extends AppException {
  const EmailConfirmationRequiredException({
    super.message =
        "Hisob yaratildi. Davom etish uchun email manzilingizni tasdiqlang.",
    super.details,
  });
}

/// Unauthorized exception
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = "Avtorizatsiyadan o'tilmagan yoki sessiya muddati tugagan.",
    super.statusCode = 401,
    super.details,
  });
}
