import 'dart:async';

import 'package:dio/dio.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';

/// Centralized Error Handler to map Exceptions into standard Clean Architecture Failures
///
/// P2 O'ZGARISHI — IKKI QAT'IY QOIDA:
///   1) `Failure.message` ga TEXNIK matn (PostgrestException, SocketException,
///      server `data['message']`, stack trace bo'lagi) TUSHMAYDI. To'liq
///      texnik matn `details` ga boradi — log/debug uchun saqlanadi.
///   2) Har bir `Failure` ga til'dan mustaqil `code` beriladi. Presentation
///      qatlami `failureText(l10n, failure)` orqali tanlangan tildagi matnni
///      oladi (`lib/core/localization/failure_text.dart`).
class ErrorHandler {
  ErrorHandler._();

  /// Texnik detal boshlanishini ko'rsatuvchi markerlar.
  ///
  /// Datasource'lar ko'p joyda `'Savol yaratilmadi: $e'` ko'rinishida yozadi —
  /// ya'ni o'zbekcha prefiks + XOM exception matni. Prefiks foydalanuvchi
  /// uchun yozilgan va xavfsiz; `$e` esa DB/tarmoq detali. Shuning uchun matn
  /// birinchi marker joyida KESILADI.
  static const List<String> _technicalMarkers = [
    'PostgrestException',
    'AuthException',
    'AuthApiException',
    'AuthRetryableFetchException',
    'StorageException',
    'FunctionException',
    'SocketException',
    'HandshakeException',
    'TimeoutException',
    'HiveError',
    'DioException',
    'FormatException',
    'TypeError',
    'NoSuchMethodError',
    'Exception:',
    'Error:',
    'code: ',
    'statusCode: ',
    'details: ',
    'hint: ',
    '#0 ',
  ];

  /// Foydalanuvchiga ko'rsatiladigan matnni texnik detaldan tozalaydi.
  ///
  /// Qaytadi: tozalangan matn, yoki marker matnning BOSHIDA bo'lsa `null`
  /// (ya'ni ko'rsatishga arziydigan hech narsa qolmadi — UI kod bo'yicha
  /// umumiy xabar ishlatadi).
  static String? sanitizeUserMessage(String raw) {
    var cut = raw.length;
    for (final marker in _technicalMarkers) {
      final idx = raw.indexOf(marker);
      if (idx >= 0 && idx < cut) cut = idx;
    }

    var text = raw.substring(0, cut).trim();
    // Kesilgandan keyin qolgan ergash belgilar: "Savol yaratilmadi:" -> "Savol yaratilmadi"
    while (text.isNotEmpty && ':-–—('.contains(text[text.length - 1])) {
      text = text.substring(0, text.length - 1).trimRight();
    }
    return text.isEmpty ? null : text;
  }

  static Failure handle(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is TimeoutException) {
      // `withTimeout(...)` (lib/core/network/request_timeout.dart) tashlaydi.
      // ILGARI bu `else` shoxiga tushib `FailureCode.unknown` + "Kutilmagan
      // xatolik" bo'lardi — foydalanuvchi sababni bilmasdi va "Qaytadan
      // urinish" mantiqiy ko'rinmasdi.
      return NetworkFailure(
        message: 'Server javob bermadi.',
        statusCode: 408,
        details: error.message ?? error.toString(),
        code: FailureCode.timeout,
      );
    } else if (error is ServerException) {
      return ServerFailure(
        message: sanitizeUserMessage(error.message) ?? error.message,
        statusCode: error.statusCode,
        details: error.details ?? error.message,
        code: _codeForStatus(error.statusCode, FailureCode.server),
      );
    } else if (error is NetworkException) {
      return NetworkFailure(
        message: sanitizeUserMessage(error.message) ??
            'Internet aloqasi mavjud emas.',
        statusCode: error.statusCode,
        details: error.message,
        code: FailureCode.network,
      );
    } else if (error is CacheException) {
      return CacheFailure(
        message: sanitizeUserMessage(error.message) ??
            'Saqlangan ma\'lumotni o\'qib bo\'lmadi.',
        statusCode: error.statusCode,
        details: error.message,
        code: FailureCode.cache,
      );
    } else if (error is ValidationException) {
      return ValidationFailure(
        message: sanitizeUserMessage(error.message) ??
            'Kiritilgan ma\'lumot to\'g\'ri emas.',
        statusCode: error.statusCode,
        details: error.message,
        code: FailureCode.validation,
      );
    } else if (error is AppException) {
      return ServerFailure(
        message:
            sanitizeUserMessage(error.message) ?? 'Xatolik yuz berdi.',
        statusCode: error.statusCode,
        details: error.message,
        code: _codeForStatus(error.statusCode, FailureCode.server),
      );
    } else {
      // XOM `error.toString()` ILGARI `message` GA QO'SHILARDI — endi faqat
      // `details` da (log/debug). Foydalanuvchi umumiy xabar ko'radi.
      return ServerFailure(
        message: 'Kutilmagan xatolik yuz berdi.',
        details: error.toString(),
        code: FailureCode.unknown,
      );
    }
  }

  static FailureCode _codeForStatus(int? statusCode, FailureCode fallback) {
    switch (statusCode) {
      case 401:
        return FailureCode.unauthorized;
      case 403:
        return FailureCode.forbidden;
      case 404:
        return FailureCode.notFound;
      case 408:
        return FailureCode.timeout;
      case 422:
        return FailureCode.validation;
      case 429:
        return FailureCode.rateLimited;
      default:
        return fallback;
    }
  }

  static Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure(
          message: "Server javob bermadi.",
          details: error.message,
          code: FailureCode.timeout,
        );
      case DioExceptionType.connectionError:
        return NetworkFailure(
          message:
              "Server bilan aloqa o'rnatib bo'lmadi. Internet aloqangizni tekshiring.",
          details: error.message,
          code: FailureCode.network,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        if (statusCode == 401 || statusCode == 403) {
          return AuthFailure(
            message: "Avtorizatsiya xatoligi. Iltimos, qaytadan kiring.",
            statusCode: statusCode,
            details: data,
            code: statusCode == 403
                ? FailureCode.forbidden
                : FailureCode.unauthorized,
          );
        }

        // SERVER MATNI UI'GA CHIQMAYDI: ilgari `data['message']` /
        // `data['error']` to'g'ridan-to'g'ri `message` ga ko'chirilardi —
        // bu DB/backend detalini foydalanuvchiga oshkor qilardi. Endi u
        // faqat `details` ichida (log/debug).
        return ServerFailure(
          message: "Serverda xatolik yuz berdi.",
          statusCode: statusCode,
          details: data,
          code: _codeForStatus(statusCode, FailureCode.server),
        );
      case DioExceptionType.cancel:
        return const ServerFailure(
          message: "So'rov bekor qilindi.",
          code: FailureCode.cancelled,
        );
      case DioExceptionType.badCertificate:
        return NetworkFailure(
          message: "Xavfsiz ulanish tasdiqlanmadi.",
          details: error.message,
          code: FailureCode.network,
        );
      case DioExceptionType.unknown:
      default:
        return NetworkFailure(
          message: "Tarmoqda xatolik yuz berdi.",
          details: error.message,
          code: FailureCode.network,
        );
    }
  }
}
