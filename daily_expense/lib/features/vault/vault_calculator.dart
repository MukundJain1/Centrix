import '../expenses/expense_repository.dart';

class MonthlyVaultEntry {
  const MonthlyVaultEntry({
    required this.year,
    required this.month,
    required this.netSaved,
    required this.daysCounted,
  });

  final int year;
  final int month;
  final double netSaved;
  final int daysCounted;
}

class VaultSummary {
  const VaultSummary({
    required this.totalSavedAllTime,
    required this.savedThisMonth,
    required this.todayPending,
    required this.todayOverspendCut,
    required this.monthlyHistory,
    required this.memberSince,
  });

  final double totalSavedAllTime;
  final double savedThisMonth;
  final double todayPending;
  final double todayOverspendCut;
  final List<MonthlyVaultEntry> monthlyHistory;
  final DateTime memberSince;
}

class VaultCalculator {
  VaultCalculator._();

  /// Computes automatic Vault savings from [memberSince] up to today:
  /// - Completed days before today: (dailyLimit - spent) adds if positive,
  ///   or cuts from the Vault if negative.
  /// - Today: any overspend (spent > dailyLimit) is cut immediately; unspent
  ///   remaining today is shown as pending until midnight.
  static VaultSummary compute({
    required double dailyLimit,
    required DateTime memberSince,
    required ExpenseRepository repo,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startRaw = DateTime(
      memberSince.year,
      memberSince.month,
      memberSince.day,
    );
    final start = startRaw.isAfter(today) ? today : startRaw;

    final monthTotals = <String, double>{};
    final monthDays = <String, int>{};

    double totalAllTime = 0;

    // 1. Completed days from sign-up date through yesterday.
    var cursor = start;
    while (cursor.isBefore(today)) {
      final spent = repo.totalOn(cursor);
      final net = dailyLimit - spent;
      totalAllTime += net;

      final key = '${cursor.year}-${cursor.month}';
      monthTotals[key] = (monthTotals[key] ?? 0) + net;
      monthDays[key] = (monthDays[key] ?? 0) + 1;

      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    // 2. Today: overspend cuts immediately; unspent is pending until midnight.
    final todaySpent = repo.totalOn(today);
    final todayDiff = dailyLimit - todaySpent;
    final todayPending = todayDiff > 0 ? todayDiff : 0.0;
    final todayOverspendCut = todayDiff < 0 ? todayDiff : 0.0;

    final currentKey = '${today.year}-${today.month}';
    monthTotals[currentKey] =
        (monthTotals[currentKey] ?? 0) + todayOverspendCut;
    totalAllTime += todayOverspendCut;

    final savedThisMonth = monthTotals[currentKey] ?? 0.0;

    // Build chronological month list (newest first) from sign-up month to now.
    final history = <MonthlyVaultEntry>[];
    var mCursor = DateTime(today.year, today.month);
    final firstMonth = DateTime(start.year, start.month);
    while (!mCursor.isBefore(firstMonth)) {
      final key = '${mCursor.year}-${mCursor.month}';
      history.add(
        MonthlyVaultEntry(
          year: mCursor.year,
          month: mCursor.month,
          netSaved: monthTotals[key] ?? 0.0,
          daysCounted: monthDays[key] ?? 0,
        ),
      );
      mCursor = DateTime(mCursor.year, mCursor.month - 1);
    }

    return VaultSummary(
      totalSavedAllTime: totalAllTime,
      savedThisMonth: savedThisMonth,
      todayPending: todayPending,
      todayOverspendCut: todayOverspendCut,
      monthlyHistory: history,
      memberSince: start,
    );
  }
}