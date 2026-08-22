import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';

/// Base Failure class for Clean Architecture error handling
///
/// P2: `message` — TEXNIK matn (o'zbekcha, log/debug uchun). Foydalanuvchiga
/// ko'rsatish uchun `code` ishlatiladi: presentation qatlami
/// `failureText(l10n, failure)` orqali tanlangan tildagi matnni oladi.
/// Shuning uchun yangi datasource xatolari uchun `message` ni ARB'ga
/// ko'chirish SHART EMAS — yetarli `code` berish.
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;
  final dynamic details;
  final FailureCode code;

  const Failure({
    required this.message,
    this.statusCode,
    this.details,
    this.code = FailureCode.unknown,
  });

  @override
  List<Object?> get props => [message, statusCode, details, code];
}

/// Server/API related failures
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.statusCode,
    super.details,
    super.code = FailureCode.server,
  });
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = "Internet aloqasi mavjud emas. Iltimos, tarmoqni tekshiring.",
    super.statusCode,
    super.details,
    super.code = FailureCode.network,
  });
}

/// Local Cache/Storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.statusCode,
    super.details,
    super.code = FailureCode.cache,
  });
}

/// Validation/User input failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.statusCode,
    super.details,
    super.code = FailureCode.validation,
  });
}

/// Authentication/Authorization failures
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.statusCode,
    super.details,
    super.code = FailureCode.unauthorized,
  });
}

/// Legal consultation parsing or data integrity failure
class LegalDataFailure extends Failure {
  const LegalDataFailure({
    required super.message,
    super.statusCode,
    super.details,
    super.code = FailureCode.unknown,
  });
}
