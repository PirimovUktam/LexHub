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

/// Unauthorized exception
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = "Avtorizatsiyadan o'tilmagan yoki sessiya muddati tugagan.",
    super.statusCode = 401,
    super.details,
  });
}
