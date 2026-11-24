import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// One place for all HTTP calls.
///  - adds the access token to every request
///  - when it has expired, silently swaps the refresh token for a new pair
///    and retries the request once
///  - turns every failure into an [ApiException]
class ApiClient {
  ApiClient._() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['noAuth'] != true) {
            final token = await TokenStore.instance.access();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final canRetry = error.response?.statusCode == 401 &&
              request.extra['noAuth'] != true &&
              request.extra['retried'] != true;

          if (canRetry) {
            if (await _refreshTokens()) {
              request.extra['retried'] = true;
              final token = await TokenStore.instance.access();
              request.headers['Authorization'] = 'Bearer $token';
              try {
                return handler.resolve(await _dio.fetch<dynamic>(request));
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
            onSessionExpired?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  // A free server (Render) can need about a minute to wake up, hence the
  // long timeouts.
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 75),
      receiveTimeout: const Duration(seconds: 75),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Set this (e.g. in main.dart) to send the user back to the sign-in
  /// screen when the refresh token no longer works.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Future<bool> _refreshTokens() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refresh = await TokenStore.instance.refresh();
    if (refresh == null) return false;
    try {
      final res = await _dio.post<dynamic>(
        '/v1/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'noAuth': true}),
      );
      final body = res.data as Map<String, dynamic>;
      await TokenStore.instance.save(
        access: body['access_token'] as String,
        refresh: body['refresh_token'] as String,
      );
      return true;
    } on DioException {
      await TokenStore.instance.clear();
      return false;
    }
  }

  /// [auth] false = do not send the token (login, OTP, register).
  Future<dynamic> send(
    String method,
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method, extra: {'noAuth': !auth}),
      );
      return res.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
