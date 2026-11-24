/// Formats money for display, e.g. 1226.4 -> "₹1,226".
///
/// Indian grouping (38,00,000) is used for ₹ by default, standard grouping
/// (3,800,000) for other currencies. Pass [indian] to force either style.
class CurrencyFormat {
  CurrencyFormat._();

  static String format(double value, String symbol, {bool? indian}) {
    final safe = value.isFinite ? value : 0.0;
    final rounded = safe.round();
    final negative = rounded < 0;
    final digits = rounded.abs().toString();
    final useIndian = indian ?? symbol == '₹';
    final grouped = useIndian ? _indian(digits) : _western(digits);
    return '${negative ? '-' : ''}$symbol$grouped';
  }

  /// Short form for chart labels: 1200 -> "1.2k", 150000 -> "1.5L" (Indian)
  /// or "150k" (international). No currency symbol.
  static String compact(double value, {bool indian = true}) {
    final v = value.isFinite ? value.abs() : 0.0;
    if (indian) {
      if (v >= 10000000) return '${_trim(v / 10000000)}Cr';
      if (v >= 100000) return '${_trim(v / 100000)}L';
      if (v >= 1000) return '${_trim(v / 1000)}k';
    } else {
      if (v >= 1000000000) return '${_trim(v / 1000000000)}B';
      if (v >= 1000000) return '${_trim(v / 1000000)}M';
      if (v >= 1000) return '${_trim(v / 1000)}k';
    }
    return v.round().toString();
  }

  static String _trim(double x) {
    final t = x.toStringAsFixed(1);
    return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
  }

  static String _western(String digits) {
    return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  static String _indian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }
}