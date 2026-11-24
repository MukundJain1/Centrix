import 'package:dio/dio.dart';

/// Every failed API call becomes one of these.
/// Switch on [code] (stable) and show [message] (friendly).
///
/// Codes the server sends: WRONG_PIN, PIN_LOCKED, WRONG_OTP, OTP_EXPIRED,
/// OTP_LOCKED, OTP_COOLDOWN, OTP_LIMIT, PHONE_EXISTS, INVALID_PHONE,
/// WEAK_PIN, INVALID_REGISTRATION, VALIDATION_ERROR, UNAUTHORIZED ...
/// Codes made on the phone: NETWORK, UNKNOWN.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.extra = const {},
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> extra;

  int? get attemptsLeft => (extra['attempts_left'] as num?)?.toInt();
  int? get retryAfter => (extra['retry_after'] as num?)?.toInt();
  bool get isNetwork => code == 'NETWORK';

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    
    if (data is Map && data['error'] is Map) {
      final error = Map<String, dynamic>.from(data['error'] as Map);
      final code = (error.remove('code') as String?) ?? 'UNKNOWN';
      final message = (error.remove('message') as String?) ?? 'Something went wrong.';
      return ApiException(
        code: code,
        message: message,
        statusCode: e.response?.statusCode,
        extra: error,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          code: 'NETWORK',
          message: "Can't reach the server. Check your internet and try again.",
        );
      default:
        return ApiException(
          code: 'UNKNOWN',
          message: 'Something went wrong. Please try again.',
          statusCode: e.response?.statusCode,
        );
    }
  }

  @override
  String toString() => 'ApiException($code, $message)';
}
