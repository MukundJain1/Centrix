import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/currency_format.dart';
import '../auth/data/auth_repository.dart';
import '../onboarding/budget_storage.dart';

enum GroupingStyle { auto, indian, international }

enum WeekStart { monday, sunday, saturday }

enum CalendarView { week, month }

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  final ApiClient _api = ApiClient.instance;
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _loadLocal();

  // ---- values -----------------------------------------------------------

  String currency = '₹';
  int payday = 1;

  GroupingStyle grouping = GroupingStyle.auto;
  WeekStart weekStart = WeekStart.monday;
  CalendarView defaultCalendarView = CalendarView.week;

  bool budgetAlerts = true;
  int alertThreshold = 80;

  bool dailyReminder = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);

  bool appLock = false;
  bool hideBalances = false;

  // ---- formatting helpers -----------------------------------------------

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

  String money(double value) =>
      CurrencyFormat.format(value, currency, indian: _useIndian);

  String maskedMoney(double value, {bool reveal = false}) {
    if (!hideBalances || reveal) return money(value);
    return '$currency •••••';
  }

  String compact(double value) =>
      CurrencyFormat.compact(value, indian: _useIndian);

  // ---- setters (save locally + sync to account) -------------------------

  void setCurrency(String value) {
    currency = value;
    notifyListeners();
  }

  void setPayday(int day) => _update(() => payday = day.clamp(1, 31));
  void setGrouping(GroupingStyle v) => _update(() => grouping = v);
  void setWeekStart(WeekStart v) => _update(() => weekStart = v);
  void setDefaultCalendarView(CalendarView v) =>
      _update(() => defaultCalendarView = v);
  void setBudgetAlerts(bool v) => _update(() => budgetAlerts = v);
  void setAlertThreshold(int v) => _update(() => alertThreshold = v);
  void setDailyReminder(bool v) => _update(() => dailyReminder = v);
  void setReminderTime(TimeOfDay v) => _update(() => reminderTime = v);
  void setAppLock(bool v) => _update(() => appLock = v);
  void setHideBalances(bool v) => _update(() => hideBalances = v);

  void _update(VoidCallback change) {
    change();
    notifyListeners();
    _saveLocal();
    _pushToServer();
  }

  // ---- server sync ------------------------------------------------------

  Future<void> syncFromServer() async {
    try {
      final body = await _api.send('GET', '/v1/settings') as Map<String, dynamic>;
      _applyServerJson(body);
      notifyListeners();
      await _saveLocal();
    } catch (_) {
      // Keep cached values if offline.
    }
  }

  Future<void> resetToDefaults() async {
    final body =
        await _api.send('POST', '/v1/settings/reset') as Map<String, dynamic>;
    _applyServerJson(body);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> _pushToServer() async {
    try {
      await _api.send(
        'PUT',
        '/v1/settings',
        data: {
          'grouping': grouping.name,
          'week_start': weekStart.name,
          'default_calendar_view': defaultCalendarView.name,
          'budget_alerts': budgetAlerts,
          'alert_threshold': alertThreshold,
          'daily_reminder': dailyReminder,
          'reminder_minutes': reminderTime.hour * 60 + reminderTime.minute,
          'app_lock': appLock,
          'hide_balances': hideBalances,
          'payday': payday,
        },
      );
    } catch (_) {
      // Will retry on next settings change.
    }
  }

  void _applyServerJson(Map<String, dynamic> json) {
    grouping = _enumByName(GroupingStyle.values, json['grouping'] as String?, grouping);
    weekStart = _enumByName(WeekStart.values, json['week_start'] as String?, weekStart);
    defaultCalendarView = _enumByName(
      CalendarView.values,
      json['default_calendar_view'] as String?,
      defaultCalendarView,
    );
    budgetAlerts = (json['budget_alerts'] as bool?) ?? budgetAlerts;
    alertThreshold = (json['alert_threshold'] as num?)?.toInt() ?? alertThreshold;
    dailyReminder = (json['daily_reminder'] as bool?) ?? dailyReminder;
    final mins = (json['reminder_minutes'] as num?)?.toInt();
    if (mins != null) {
      reminderTime = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    }
    appLock = (json['app_lock'] as bool?) ?? appLock;
    hideBalances = (json['hide_balances'] as bool?) ?? hideBalances;
    final serverPayday = (json['payday'] as num?)?.toInt();
    if (serverPayday != null && serverPayday >= 1 && serverPayday <= 31) {
      payday = serverPayday;
    }
  }

  // ---- local cache ------------------------------------------------------

  static T _enumAt<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  static T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  Future<void> _loadLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      grouping = _enumAt(GroupingStyle.values, p.getInt('st_grouping'), grouping);
      weekStart = _enumAt(WeekStart.values, p.getInt('st_week_start'), weekStart);
      defaultCalendarView = _enumAt(
        CalendarView.values,
        p.getInt('st_calendar_view'),
        defaultCalendarView,
      );
      budgetAlerts = p.getBool('st_alerts') ?? budgetAlerts;
      alertThreshold = p.getInt('st_threshold') ?? alertThreshold;
      dailyReminder = p.getBool('st_reminder') ?? dailyReminder;
      final minutes = p.getInt('st_reminder_minutes');
      if (minutes != null) {
        reminderTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      }
      appLock = p.getBool('st_app_lock') ?? appLock;
      hideBalances = p.getBool('st_hide_balances') ?? hideBalances;
      payday = p.getInt('st_payday') ?? payday;
    } catch (_) {}

    final me = AuthRepository.instance.currentUser.value;
    if (me != null) {
      currency = me.currency;
      if (me.payday != null) payday = me.payday!;
    } else {
      final budget = await BudgetStorage.load();
      if (budget != null) {
        currency = budget.currency;
        if (budget.payday != null) payday = budget.payday!;
      }
    }

    notifyListeners();
  }

  Future<void> _saveLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('st_grouping', grouping.index);
      await p.setInt('st_week_start', weekStart.index);
      await p.setInt('st_calendar_view', defaultCalendarView.index);
      await p.setBool('st_alerts', budgetAlerts);
      await p.setInt('st_threshold', alertThreshold);
      await p.setBool('st_reminder', dailyReminder);
      await p.setInt(
        'st_reminder_minutes',
        reminderTime.hour * 60 + reminderTime.minute,
      );
      await p.setBool('st_app_lock', appLock);
      await p.setBool('st_hide_balances', hideBalances);
      await p.setInt('st_payday', payday);
    } catch (_) {}
  }
}