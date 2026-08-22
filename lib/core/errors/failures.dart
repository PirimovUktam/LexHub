import 'package:equatable/equatable.dart';

/// Base Failure class for Clean Architecture error handling
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;
  final dynamic details;

  const Failure({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  List<Object?> get props => [message, statusCode, details];
}

/// Server/API related failures
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = "Internet aloqasi mavjud emas. Iltimos, tarmoqni tekshiring.",
    super.statusCode,
    super.details,
  });
}

/// Local Cache/Storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Validation/User input failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Authentication/Authorization failures
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Legal consultation parsing or data integrity failure
class LegalDataFailure extends Failure {
  const LegalDataFailure({
    required super.message,
    super.statusCode,
    super.details,
  });
}
