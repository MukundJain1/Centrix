import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the login tokens in the phone's encrypted storage
/// (Android Keystore), not in plain SharedPreferences.
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> access() => _storage.read(key: _accessKey);
  Future<String?> refresh() => _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
