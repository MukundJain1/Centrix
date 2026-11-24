import 'package:shared_preferences/shared_preferences.dart';

import 'baseline_snapshot.dart';

class SavedBudget {
  const SavedBudget({
    required this.dailyLimit,
    required this.currency,
    this.payday,
    this.monthlySurplus,
  });

  final double dailyLimit;
  final String currency;

  /// Day of the month the user gets paid (1-31). Null if not set yet.
  final int? payday;

  /// Income minus fixed expenses from the Financial Baseline.
  final double? monthlySurplus;
}

/// Remembers the Financial Baseline step, so Sign In can go straight to the
/// dashboard and Edit Baseline can show what the user entered.
///
/// TODO(backend): this is stored on the device only. Once you have a server,
/// save the baseline against the user's account and ask the server instead.
/// (Until then, two different accounts on one phone share this value.)
class BudgetStorage {
  BudgetStorage._();

  static const _dailyKey = 'budget_daily_limit';
  static const _currencyKey = 'budget_currency';
  static const _baselineKey = 'budget_baseline_json';
  static const _paydayKey = 'budget_payday';
  static const _surplusKey = 'budget_monthly_surplus';

  /// Only the values you pass are written, so saving the payday later does
  /// not erase the baseline saved earlier (and the other way round).
  static Future<void> save({
    required double dailyLimit,
    required String currency,
    BaselineSnapshot? baseline,
    int? payday,
    double? monthlySurplus,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_dailyKey, dailyLimit);
      await prefs.setString(_currencyKey, currency);
      if (baseline != null) {
        await prefs.setString(_baselineKey, baseline.encode());
      }
      if (payday != null) {
        await prefs.setInt(_paydayKey, payday);
      }
      if (monthlySurplus != null) {
        await prefs.setDouble(_surplusKey, monthlySurplus);
      }
    } catch (_) {
      // Not critical: the user will just see the setup screen again.
    }
  }

  /// Returns null when no baseline has been saved yet.
  static Future<SavedBudget?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final daily = prefs.getDouble(_dailyKey);
      if (daily == null) return null;
      return SavedBudget(
        dailyLimit: daily,
        currency: prefs.getString(_currencyKey) ?? '₹',
        payday: prefs.getInt(_paydayKey),
        monthlySurplus: prefs.getDouble(_surplusKey),
      );
    } catch (_) {
      return null;
    }
  }

  /// The categories and amounts the user entered. Null if none saved.
  static Future<BaselineSnapshot?> loadBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return BaselineSnapshot.decode(prefs.getString(_baselineKey));
    } catch (_) {
      return null;
    }
  }
}