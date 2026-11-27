import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../auth/widgets/pin_verify_sheet.dart';
import '../expenses/expense_repository.dart';
import 'app_settings.dart';
import 'widgets/settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleHideBalances(
    BuildContext context,
    AppSettings s,
    bool nextValue,
  ) async {
    if (!nextValue) {
      s.setHideBalances(false);
      return;
    }
    final verified = await showPinVerifySheet(
      context,
      title: 'Verify PIN to Hide Balances',
      subtitle: 'Enter your account PIN to enable balance privacy.',
    );
    if (verified) {
      s.setHideBalances(true);
    }
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    AppSettings s,
    bool nextValue,
  ) async {
    if (!nextValue) {
      s.setAppLock(false);
      return;
    }
    final verified = await showPinVerifySheet(
      context,
      title: 'Verify PIN for App Lock',
      subtitle: 'Confirm your account PIN before turning on App Lock.',
    );
    if (verified) {
      s.setAppLock(true);
    }
  }

  Future<void> _pickPayday(BuildContext context, AppSettings s) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Select Payday Date',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Day of the month your salary is credited.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  itemCount: 31,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final selected = day == s.payday;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, day),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryAccent
                              : AppColors.inputSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryAccent
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: selected
                                ? AppColors.background
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      s.setPayday(picked);
    }
  }

  Future<void> _pickReminderTime(BuildContext context, AppSettings s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: s.reminderTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryAccent,
              surface: AppColors.inputSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) s.setReminderTime(picked);
  }

  Future<void> _confirmResetSettings(
    BuildContext context,
    AppSettings s,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputSurface,
        title: const Text(
          'Reset settings to defaults?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'All display, calendar, alert, and privacy settings will return to their default values.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
                style: TextStyle(color: AppColors.primaryAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await s.resetToDefaults();
      if (context.mounted) {
        AppSnackbar.success(context, 'Settings reset to defaults.');
      }
    } on ApiException catch (e) {
      if (context.mounted) AppSnackbar.error(context, e.message);
    }
  }

  Future<void> _confirmDeleteExpenses(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputSurface,
        title: const Text(
          'Delete all expenses?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This permanently removes every logged expense. Your Financial Baseline stays intact.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Continue', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final verified = await showPinVerifySheet(
      context,
      title: 'Confirm Deletion with PIN',
      subtitle: 'Enter your account PIN to permanently delete all expenses.',
    );
    if (!verified || !context.mounted) return;

    ExpenseRepository.instance.clear();
    AppSnackbar.success(context, 'All expenses deleted.');
  }

  String _ordinalDay(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryAccent),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
                  children: [
                    SettingsSection(
                      title: 'Display & Privacy',
                      children: [
                        SettingsSwitchTile(
                          title: 'Hide balances by default',
                          subtitle:
                              'Masks dashboard amounts until tapped (PIN required to enable)',
                          value: settings.hideBalances,
                          onChanged: (v) =>
                              _toggleHideBalances(context, settings, v),
                        ),
                        SettingsChoiceTile<GroupingStyle>(
                          title: 'Number format',
                          subtitle: 'Example: ${settings.money(1234567)}',
                          value: settings.grouping,
                          options: const {
                            GroupingStyle.auto: 'Auto',
                            GroupingStyle.indian: 'Indian (12,34,567)',
                            GroupingStyle.international:
                                'International (1,234,567)',
                          },
                          onChanged: settings.setGrouping,
                        ),
                        SettingsActionTile(
                          title: 'Currency',
                          subtitle: 'Change it in Edit Baseline',
                          value: settings.currency,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Salary Cycle & Calendar',
                      children: [
                        SettingsActionTile(
                          title: 'Payday date',
                          subtitle: 'Monthly salary credit day',
                          value: '${_ordinalDay(settings.payday)} of month',
                          onTap: () => _pickPayday(context, settings),
                        ),
                        SettingsChoiceTile<WeekStart>(
                          title: 'Week starts on',
                          value: settings.weekStart,
                          options: const {
                            WeekStart.monday: 'Monday',
                            WeekStart.sunday: 'Sunday',
                            WeekStart.saturday: 'Saturday',
                          },
                          onChanged: settings.setWeekStart,
                        ),
                        SettingsChoiceTile<CalendarView>(
                          title: 'Default view',
                          subtitle: 'How the dashboard calendar opens',
                          value: settings.defaultCalendarView,
                          options: const {
                            CalendarView.week: 'Week',
                            CalendarView.month: 'Month',
                          },
                          onChanged: settings.setDefaultCalendarView,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Budget alerts',
                      children: [
                        SettingsSwitchTile(
                          title: 'Warn me near my daily budget',
                          subtitle: 'Shows a warning on the dashboard card',
                          value: settings.budgetAlerts,
                          onChanged: settings.setBudgetAlerts,
                        ),
                        SettingsSliderTile(
                          title: 'Warn me at',
                          valueLabel: '${settings.alertThreshold}% used',
                          value: settings.alertThreshold.toDouble(),
                          min: 50,
                          max: 100,
                          divisions: 10,
                          enabled: settings.budgetAlerts,
                          onChanged: (v) =>
                              settings.setAlertThreshold(v.round()),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Reminders',
                      children: [
                        SettingsSwitchTile(
                          title: 'Daily reminder',
                          subtitle: 'A daily nudge to review your spends',
                          value: settings.dailyReminder,
                          onChanged: settings.setDailyReminder,
                        ),
                        SettingsActionTile(
                          title: 'Reminder time',
                          value: settings.reminderTime.format(context),
                          enabled: settings.dailyReminder,
                          onTap: () => _pickReminderTime(context, settings),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Security',
                      children: [
                        SettingsSwitchTile(
                          title: 'App lock',
                          subtitle:
                              'Require your account PIN when opening the app',
                          value: settings.appLock,
                          onChanged: (v) =>
                              _toggleAppLock(context, settings, v),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Data & Reset',
                      children: [
                        SettingsActionTile(
                          title: 'Reset settings to defaults',
                          subtitle: 'Restore all preferences to initial values',
                          onTap: () => _confirmResetSettings(context, settings),
                        ),
                        SettingsActionTile(
                          title: 'Delete all expenses',
                          subtitle: 'Requires confirmation and your account PIN',
                          danger: true,
                          onTap: () => _confirmDeleteExpenses(context),
                        ),
                      ],
                    ),
                    const SettingsSection(
                      title: 'About',
                      children: [
                        SettingsActionTile(title: 'Version', value: '1.0.0'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}