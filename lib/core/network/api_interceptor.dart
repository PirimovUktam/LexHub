import 'package:dio/dio.dart';

/// App-wide Dio interceptor for request headers, logging, and token management
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'application/json';
    options.headers['Accept-Language'] = 'uz';

    super.onRequest(options, handler);
  }
}
