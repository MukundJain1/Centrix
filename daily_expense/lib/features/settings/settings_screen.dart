import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../expenses/expense_repository.dart';
import 'app_settings.dart';
import 'widgets/settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          'This removes every logged expense. Your Financial Baseline stays.',
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
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ExpenseRepository.instance.clear();
      if (context.mounted) _snack(context, 'All expenses deleted');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _timeLabel(BuildContext context, TimeOfDay t) =>
      t.format(context);

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
                      title: 'Display',
                      children: [
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
                      title: 'Calendar',
                      children: [
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
                          subtitle:
                              'Shows a warning on the dashboard card',
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
                          subtitle:
                              'A nudge to log your expenses. Notifications start working once they are set up.',
                          value: settings.dailyReminder,
                          onChanged: settings.setDailyReminder,
                        ),
                        SettingsActionTile(
                          title: 'Reminder time',
                          value: _timeLabel(context, settings.reminderTime),
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
                              'Ask for your PIN when the app opens. Takes effect once the backend is connected.',
                          value: settings.appLock,
                          onChanged: settings.setAppLock,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Data',
                      children: [
                        SettingsActionTile(
                          title: 'Export my data',
                          subtitle: 'Download your expenses as a CSV file',
                          onTap: () => _snack(
                            context,
                            'Export will be available once the backend is connected.',
                          ),
                        ),
                        SettingsActionTile(
                          title: 'Delete all expenses',
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
