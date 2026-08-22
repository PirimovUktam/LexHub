import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lexhub/core/constants/api_endpoints.dart';
import 'package:lexhub/core/network/api_interceptor.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Centralized API Client managing HTTP requests
class ApiClient {
  late final Dio dio;

  ApiClient({Dio? customDio}) {
    dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.baseUrl,
            connectTimeout: ApiEndpoints.connectTimeout,
            receiveTimeout: ApiEndpoints.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    dio.interceptors.add(ApiInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
      );
    }
  }

  /// Backend manzili haqiqatan sozlanganmi.
  ///
  /// P0 gate: `ApiEndpoints.baseUrl` endi `--dart-define`dan keladi va
  /// sozlanmasa BO'SH bo'ladi. Bo'sh `baseUrl` bilan `post()` chaqirilsa Dio
  /// nisbiy yo'lni o'zi hal qila olmaydi — lekin bundan ham muhimi, ilgari
  /// kodga yozilgan `api.lexhub.uz` DNS'da yo'q edi va so'rov begona (kelajakda
  /// kimdir ro'yxatdan o'tkazishi mumkin bo'lgan) hostga ketardi. Shuning uchun
  /// chaqiruvchi qatlam HTTP'ga chiqishdan oldin shu getter'ni tekshiradi.
  ///
  /// Tekshiruv `const` emas, balki INSTANCE holatiga tayanadi — shu sababli
  /// testda `customDio` orqali sozlangan client bilan haqiqiy yo'lni ham,
  /// sozlanmagan client bilan gate'ning o'zini ham tekshirish mumkin.
  bool get hasBaseUrl => dio.options.baseUrl.isNotEmpty;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
