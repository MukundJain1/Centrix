import 'package:shared_preferences/shared_preferences.dart';

import 'country.dart';

/// Small convenience memory on the phone: which country and number were used
/// last, so Sign In can open with them filled in and the user only types
/// the PIN. (No PIN or token is stored here.)
class AuthStorage {
  AuthStorage._();

  static const _countryKey = 'auth_country_iso';
  static const _phoneKey = 'auth_last_phone';

  static Future<void> saveCountry(Country country) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_countryKey, country.iso);
    } catch (_) {}
  }

  static Future<Country> loadCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Country.byIso(prefs.getString(_countryKey)) ?? Country.india;
    } catch (_) {
      return Country.india;
    }
  }

  /// National number without the country code, e.g. "9876543210".
  static Future<void> saveLastPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, phone);
    } catch (_) {}
  }

  static Future<String?> loadLastPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneKey);
    } catch (_) {
      return null;
    }
  }
}
