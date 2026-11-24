import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/currency_format.dart';
import '../onboarding/budget_storage.dart';

enum GroupingStyle { auto, indian, international }

enum WeekStart { monday, sunday, saturday }

enum CalendarView { week, month }

/// App-wide preferences. Screens listen to it (ListenableBuilder) so changes
/// show up immediately.
///
/// TODO(backend): sync these with the user's account.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  Future<void>? _loading;

  /// Call before using the values (safe to call many times).
  Future<void> ensureLoaded() => _loading ??= _load();

  // ---- values -----------------------------------------------------------

  /// Display currency. Comes from the Financial Baseline, not saved here.
  String currency = '₹';

  GroupingStyle grouping = GroupingStyle.auto;
  WeekStart weekStart = WeekStart.monday;
  CalendarView defaultCalendarView = CalendarView.week;

  bool budgetAlerts = true;

  /// Warn when this % of the daily budget is used.
  int alertThreshold = 80;

  bool dailyReminder = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);

  bool appLock = false;

  // ---- formatting helpers -------------------------------------------------

  bool get _useIndian {
    switch (grouping) {
      case GroupingStyle.auto:
        return currency == '₹';
      case GroupingStyle.indian:
        return true;
      case GroupingStyle.international:
        return false;
    }
  }

  /// "₹1,226" (grouping follows the setting).
  String money(double value) =>
      CurrencyFormat.format(value, currency, indian: _useIndian);

  /// "1.2k" for chart labels.
  String compact(double value) =>
      CurrencyFormat.compact(value, indian: _useIndian);

  // ---- setters (each one saves and notifies) --------------------------------

  void setCurrency(String value) {
    currency = value;
    notifyListeners();
  }

  void setGrouping(GroupingStyle v) => _update(() => grouping = v);
  void setWeekStart(WeekStart v) => _update(() => weekStart = v);
  void setDefaultCalendarView(CalendarView v) =>
      _update(() => defaultCalendarView = v);
  void setBudgetAlerts(bool v) => _update(() => budgetAlerts = v);
  void setAlertThreshold(int v) => _update(() => alertThreshold = v);
  void setDailyReminder(bool v) => _update(() => dailyReminder = v);
  void setReminderTime(TimeOfDay v) => _update(() => reminderTime = v);
  void setAppLock(bool v) => _update(() => appLock = v);

  void _update(VoidCallback change) {
    change();
    notifyListeners();
    _save();
  }

  // ---- storage ------------------------------------------------------------

  static T _enumAt<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      grouping = _enumAt(GroupingStyle.values, p.getInt('st_grouping'), grouping);
      weekStart = _enumAt(WeekStart.values, p.getInt('st_week_start'), weekStart);
      defaultCalendarView = _enumAt(
          CalendarView.values, p.getInt('st_calendar_view'), defaultCalendarView);
      budgetAlerts = p.getBool('st_alerts') ?? budgetAlerts;
      alertThreshold = p.getInt('st_threshold') ?? alertThreshold;
      dailyReminder = p.getBool('st_reminder') ?? dailyReminder;
      final minutes = p.getInt('st_reminder_minutes');
      if (minutes != null) {
        reminderTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      }
      appLock = p.getBool('st_app_lock') ?? appLock;
    } catch (_) {
      // Keep the defaults.
    }

    final budget = await BudgetStorage.load();
    if (budget != null) currency = budget.currency;

    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('st_grouping', grouping.index);
      await p.setInt('st_week_start', weekStart.index);
      await p.setInt('st_calendar_view', defaultCalendarView.index);
      await p.setBool('st_alerts', budgetAlerts);
      await p.setInt('st_threshold', alertThreshold);
      await p.setBool('st_reminder', dailyReminder);
      await p.setInt(
          'st_reminder_minutes', reminderTime.hour * 60 + reminderTime.minute);
      await p.setBool('st_app_lock', appLock);
    } catch (_) {
      // Not critical.
    }
  }
}
