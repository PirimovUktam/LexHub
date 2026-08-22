import 'package:dio/dio.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failures.dart';

/// Centralized Error Handler to map Exceptions into standard Clean Architecture Failures
class ErrorHandler {
  ErrorHandler._();

  static Failure handle(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is ServerException) {
      return ServerFailure(
        message: error.message,
        statusCode: error.statusCode,
        details: error.details,
      );
    } else if (error is NetworkException) {
      return NetworkFailure(
        message: error.message,
        statusCode: error.statusCode,
      );
    } else if (error is CacheException) {
      return CacheFailure(
        message: error.message,
        statusCode: error.statusCode,
      );
    } else if (error is ValidationException) {
      return ValidationFailure(
        message: error.message,
        statusCode: error.statusCode,
      );
    } else if (error is AppException) {
      return ServerFailure(
        message: error.message,
        statusCode: error.statusCode,
      );
    } else {
      return ServerFailure(
        message: "Kutilmagan xatolik yuz berdi: ${error.toString()}",
      );
    }
  }

  static Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          message: "Server bilan aloqa o'rnatib bo'lmadi. Internet aloqangizni tekshiring.",
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String message = "Serverda xatolik yuz berdi ($statusCode).";

        if (data is Map<String, dynamic> && data.containsKey('message')) {
          message = data['message'].toString();
        } else if (data is Map<String, dynamic> && data.containsKey('error')) {
          message = data['error'].toString();
        }

        if (statusCode == 401 || statusCode == 403) {
          return AuthFailure(
            message: "Avtorizatsiya xatoligi. Iltimos, qaytadan kiring.",
            statusCode: statusCode,
          );
        }

        return ServerFailure(
          message: message,
          statusCode: statusCode,
          details: data,
        );
      case DioExceptionType.cancel:
        return const ServerFailure(message: "So'rov bekor qilindi.");
      case DioExceptionType.unknown:
      default:
        return NetworkFailure(
          message: error.message ?? "Tarmoqda xatolik yuz berdi.",
        );
    }
  }
}
