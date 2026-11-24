import 'auth_config.dart';
import 'country.dart';

/// Each method returns an error message, or null when the value is valid.
class AuthValidators {
  AuthValidators._();

  static String? phone(String value, Country country) {
    final v = value.trim();

    if (country.iso == 'IN') {
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
        return 'Enter a valid 10-digit mobile number';
      }
      return null;
    }

    // Other countries: a generic length check (6 to 15 digits).
    if (v.length < 6 || v.length > country.maxPhoneDigits) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  static String? pin(String value) {
    if (value.length != AuthConfig.pinLength) {
      return 'Enter your ${AuthConfig.pinLength}-digit PIN';
    }
    return null;
  }

  static String? confirmPin(String pin, String confirm) {
    if (confirm.length != AuthConfig.pinLength) {
      return 'Confirm your ${AuthConfig.pinLength}-digit PIN';
    }
    if (pin != confirm) return 'PINs do not match';
    return null;
  }
}
