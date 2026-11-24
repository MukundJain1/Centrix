import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/token_store.dart';
import '../country.dart';
import 'auth_models.dart';

/// Everything the auth screens need from the server.
/// Throws ApiException on failure (see core/network/api_exception.dart).
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final ApiClient _api = ApiClient.instance;

  String get _deviceLabel => defaultTargetPlatform.name; // "android", "iOS" ...

  Map<String, dynamic> _phoneBody(Country country, String phone) => {
        'dial_code': country.dialCode,
        'phone': phone,
        'country_iso': country.iso,
      };

  /// Register step 1: text a code to the number.
  Future<void> sendOtp(Country country, String phone) async {
    await _api.send(
      'POST',
      '/v1/auth/otp/send',
      data: _phoneBody(country, phone),
      auth: false,
    );
  }

  /// Register step 2: check the code. Returns the registration token that
  /// step 3 needs.
  Future<String> verifyOtp(Country country, String phone, String code) async {
    final body = await _api.send(
      'POST',
      '/v1/auth/otp/verify',
      data: {..._phoneBody(country, phone), 'code': code},
      auth: false,
    ) as Map<String, dynamic>;
    return body['registration_token'] as String;
  }

  /// Register step 3: choose a PIN. Creates the account and signs in.
  Future<MeModel> register(String registrationToken, String pin) async {
    final body = await _api.send(
      'POST',
      '/v1/auth/register',
      data: {
        'registration_token': registrationToken,
        'pin': pin,
        'device_label': _deviceLabel,
      },
      auth: false,
    ) as Map<String, dynamic>;
    return _saveSession(body);
  }

  /// Phone + PIN. The server decides if the PIN is right.
  /// Wrong PIN -> ApiException(code: WRONG_PIN, attemptsLeft: n)
  /// Locked    -> ApiException(code: PIN_LOCKED, retryAfter: seconds)
  Future<MeModel> login(Country country, String phone, String pin) async {
    final body = await _api.send(
      'POST',
      '/v1/auth/login',
      data: {..._phoneBody(country, phone), 'pin': pin, 'device_label': _deviceLabel},
      auth: false,
    ) as Map<String, dynamic>;
    return _saveSession(body);
  }

  Future<MeModel> me() async {
    final body = await _api.send('GET', '/v1/auth/me') as Map<String, dynamic>;
    return MeModel.fromJson(body);
  }

  Future<void> logout() async {
    final refresh = await TokenStore.instance.refresh();
    if (refresh != null) {
      try {
        await _api.send('POST', '/v1/auth/logout', data: {'refresh_token': refresh}, auth: false);
      } catch (_) {
        // Offline? Still sign out on this phone.
      }
    }
    await TokenStore.instance.clear();
  }

  Future<MeModel> _saveSession(Map<String, dynamic> body) async {
    await TokenStore.instance.save(
      access: body['access_token'] as String,
      refresh: body['refresh_token'] as String,
    );
    return MeModel.fromJson(body['user'] as Map<String, dynamic>);
  }
}
