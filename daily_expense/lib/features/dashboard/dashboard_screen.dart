import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../vault/vault_screen.dart';
import '../../core/theme/colors.dart';
import '../auth/auth_screen.dart';
import '../expenses/expense.dart';
import '../expenses/expense_repository.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/app_settings.dart';
import '../settings/settings_screen.dart';
import '../summary/summary_screen.dart';
import '../auth/data/auth_models.dart';
import '../auth/data/auth_repository.dart';
import '../profile/edit_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final double dailyBudgetLimit;

  const DashboardScreen({super.key, required this.dailyBudgetLimit});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _settings = AppSettings.instance;
  final _repo = ExpenseRepository.instance;
  bool _revealBalance = false;

  /// Starts as the value from onboarding; changes after Edit Baseline.
  late double _dailyLimit = widget.dailyBudgetLimit;

  int _currentIndex = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    if (AuthRepository.instance.currentUser.value == null) {
      AuthRepository.instance.me().then((_) {}, onError: (_) {});
    }
    _settings.ensureLoaded().then((_) async {
      await _settings.syncFromServer();
      if (!mounted) return;
      setState(() {
        _calendarFormat = _settings.defaultCalendarView == CalendarView.month
            ? CalendarFormat.month
            : CalendarFormat.week;
      });
    });
  }

  // ------------------------------------------------------------- helpers

  bool _isToday(DateTime d) => isSameDay(d, DateTime.now());

  String _dayLabel(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  String _formatTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  StartingDayOfWeek get _startingDay {
    switch (_settings.weekStart) {
      case WeekStart.monday:
        return StartingDayOfWeek.monday;
      case WeekStart.sunday:
        return StartingDayOfWeek.sunday;
      case WeekStart.saturday:
        return StartingDayOfWeek.saturday;
    }
  }

  // ------------------------------------------------------------- actions

  void _toggleCalendar() {
    setState(() {
      _calendarFormat = _calendarFormat == CalendarFormat.week
          ? CalendarFormat.month
          : CalendarFormat.week;
      // Keep the selected day in view after switching.
      _focusedDay = _selectedDay;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = now;
      _focusedDay = now;
    });
  }

  void _openVault({bool fromModal = false}) {
    if (fromModal) Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VaultScreen(dailyLimit: _dailyLimit)),
    );
  }

  Future<void> _logout() async {
    await AuthRepository.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _openEditProfile() async {
    Navigator.pop(context); // close the profile sheet
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _openEditBaseline() async {
    Navigator.pop(context); // close the profile sheet
    final newLimit = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isEditing: true),
      ),
    );
    if (newLimit != null && mounted) {
      setState(() => _dailyLimit = newLimit);
    }
  }

  void _openSettings() {
    Navigator.pop(context); // close the profile sheet
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<MeModel?>(
                  valueListenable: AuthRepository.instance.currentUser,
                  builder: (context, user, _) {
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.inputSurface,
                          child: Text(
                            user?.initials ?? 'U',
                            style: const TextStyle(
                              color: AppColors.primaryAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user?.displayName ?? 'Complete your profile',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user != null ? 'Phone: ${user.maskedPhone}' : '',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                ListTile(
                  leading: const Icon(
                    Icons.savings_outlined,
                    color: AppColors.primaryAccent,
                  ),
                  title: const Text(
                    "Savings Vault",
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => _openVault(fromModal: true),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryAccent,
                  ),
                  title: const Text(
                    "Edit Profile",
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: _openEditProfile,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primaryAccent,
                  ),
                  title: const Text(
                    "Edit Baseline",
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: _openEditBaseline,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_rounded,
                    color: AppColors.primaryAccent,
                  ),
                  title: const Text(
                    "App Settings",
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: _openSettings,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: _logout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentIndex == 0 ? "Overview" : "Summary",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Savings Vault',
            onPressed: _openVault,
            icon: const Icon(
              Icons.savings_outlined,
              color: AppColors.primaryAccent,
            ),
          ),
          GestureDetector(
            onTap: _openProfileModal,
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryAccent, width: 2),
              ),
              child: ValueListenableBuilder<MeModel?>(
                valueListenable: AuthRepository.instance.currentUser,
                builder: (context, user, _) => CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.inputSurface,
                  child: Text(
                    user?.initials ?? 'U',
                    style: const TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // IndexedStack keeps each tab's state (calendar, summary filters).
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildDashboardTab(), const SummaryScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.inputSurface,
        selectedItemColor: AppColors.primaryAccent,
        unselectedItemColor: AppColors.textMuted,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: "Summary",
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return ListenableBuilder(
      listenable: Listenable.merge([_settings, _repo]),
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final hPad = width < 360 ? 16.0 : 20.0;

        final day = _selectedDay;
        final spent = _repo.totalOn(day);
        final txns = _repo.on(day);

        // The whole tab scrolls, so the month calendar never squeezes the
        // transactions list off the screen.
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: EdgeInsets.all(hPad),
                  child: _buildBudgetCard(day, spent),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: _buildCalendar(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Transactions",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _isToday(day) ? 'Today' : _dayLabel(day),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (txns.isEmpty)
                  _buildEmptyState()
                else
                  for (final e in txns)
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
                      child: _buildTransactionTile(e),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------- budget card

  // --------------------------------------------------------- budget card

  Widget _buildBudgetCard(DateTime day, double spent) {
    final limit = _dailyLimit;
    final remaining = limit - spent;
    final shown = remaining < 0 ? 0.0 : remaining;
    final progress = limit > 0
        ? (shown / limit).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final usedPct = limit > 0 ? spent / limit * 100 : 0.0;

    final over = spent > limit;
    final warn =
        _settings.budgetAlerts &&
        !over &&
        spent > 0 &&
        usedPct >= _settings.alertThreshold;

    final barColor = over || progress <= 0
        ? Colors.redAccent
        : warn
        ? Colors.amber
        : AppColors.primaryAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isToday(day)
                    ? "Remaining Today"
                    : "Remaining on ${_dayLabel(day)}",
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              if (_settings.hideBalances)
                GestureDetector(
                  onTap: () => setState(() => _revealBalance = !_revealBalance),
                  child: Icon(
                    _revealBalance
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _settings.maskedMoney(shown, reveal: _revealBalance),
              style: TextStyle(
                color: over ? Colors.redAccent : AppColors.primaryAccent,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Spent ${_settings.maskedMoney(spent, reveal: _revealBalance)} of ${_settings.maskedMoney(limit, reveal: _revealBalance)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: (over || warn)
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        Icon(
                          over
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: over ? Colors.redAccent : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            over
                                ? 'Over budget by ${_settings.maskedMoney(spent - limit, reveal: _revealBalance)}'
                                : "You've used ${usedPct.round()}% of this day's budget",
                            style: TextStyle(
                              color: over ? Colors.redAccent : Colors.amber,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ calendar

  Widget _buildCalendar() {
    final expanded = _calendarFormat == CalendarFormat.month;
    final notToday = !_isToday(_selectedDay);

    return Column(
      children: [
        TableCalendar<Expense>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          startingDayOfWeek: _startingDay,
          rowHeight: 46,
          formatAnimationDuration: const Duration(milliseconds: 250),
          formatAnimationCurve: Curves.easeInOut,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) => _repo.on(day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          // Needed so swiping to another week / month sticks.
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false, // we use our own button below
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: AppColors.textMuted,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: AppColors.textMuted),
            weekendStyle: TextStyle(color: AppColors.textMuted),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
            weekendTextStyle: const TextStyle(color: AppColors.textPrimary),
            outsideTextStyle: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            todayTextStyle: const TextStyle(color: AppColors.textPrimary),
            todayDecoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: AppColors.background,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primaryAccent,
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders<Expense>(
            // Dot under days that have spends; red when over budget.
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final over = _repo.totalOn(day) > _dailyLimit;
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: over ? Colors.redAccent : AppColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedOpacity(
                  opacity: notToday ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !notToday,
                    child: TextButton(
                      onPressed: _goToToday,
                      child: const Text(
                        'Today',
                        style: TextStyle(color: AppColors.primaryAccent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Expand / collapse button.
            Material(
              color: AppColors.inputSurface,
              shape: StadiumBorder(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _toggleCalendar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expanded ? 'Week' : 'Month',
                        style: const TextStyle(
                          color: AppColors.primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------- transactions

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.self_improvement_rounded,
            size: 48,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            "No spends yet",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Nothing logged for this day.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Expense e) {
    final meta = ExpenseCategories.of(e.category);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(meta.icon, color: meta.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.merchant,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${e.category} • ${_formatTime(e.date)}",
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "-${_settings.money(e.amount)}",
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
