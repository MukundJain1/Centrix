import '../expenses/expense.dart';

/// How the timeline is split in the Summary charts.
enum Granularity {
  daily('Daily', 'day', 'Last 7 days', 'Today', 'yesterday'),
  weekly('Weekly', 'week', 'Last 6 weeks', 'This week', 'last week'),
  monthly('Monthly', 'month', 'Last 6 months', 'This month', 'last month');

  const Granularity(
    this.label,
    this.unit,
    this.windowLabel,
    this.currentLabel,
    this.previousLabel,
  );

  final String label;
  final String unit;
  final String windowLabel;
  final String currentLabel;
  final String previousLabel;
}

/// One bar on a chart: a day, a week or a month.
class TimeBucket {
  const TimeBucket(this.start, this.end, this.label);

  final DateTime start;

  /// Exclusive.
  final DateTime end;
  final String label;
}

/// Pure functions that turn a list of expenses into chart data.
/// TODO(backend): the server can do this grouping instead.
class SummaryCalc {
  SummaryCalc._();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static List<TimeBucket> buckets(Granularity g, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    switch (g) {
      case Granularity.daily:
        return List.generate(7, (i) {
          final start = DateTime(today.year, today.month, today.day - (6 - i));
          return TimeBucket(
            start,
            DateTime(start.year, start.month, start.day + 1),
            _weekdays[start.weekday - 1],
          );
        });

      case Granularity.weekly:
        final thisWeek =
            DateTime(today.year, today.month, today.day - (today.weekday - 1));
        return List.generate(6, (i) {
          final start = DateTime(
            thisWeek.year,
            thisWeek.month,
            thisWeek.day - 7 * (5 - i),
          );
          return TimeBucket(
            start,
            DateTime(start.year, start.month, start.day + 7),
            '${start.day} ${_months[start.month - 1]}',
          );
        });

      case Granularity.monthly:
        return List.generate(6, (i) {
          final start = DateTime(today.year, today.month - (5 - i), 1);
          return TimeBucket(
            start,
            DateTime(start.year, start.month + 1, 1),
            _months[start.month - 1],
          );
        });
    }
  }

  /// Expenses that fall inside the whole chart window.
  static List<Expense> inWindow(List<Expense> all, List<TimeBucket> buckets) {
    final start = buckets.first.start;
    final end = buckets.last.end;
    return all
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();
  }

  static double total(Iterable<Expense> list) =>
      list.fold<double>(0, (sum, e) => sum + e.amount);

  /// Totals grouped by [key], biggest first.
  static List<MapEntry<String, double>> rank(
    Iterable<Expense> list,
    String Function(Expense) key,
  ) {
    final map = <String, double>{};
    for (final e in list) {
      map[key(e)] = (map[key(e)] ?? 0) + e.amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// One total per bucket.
  static List<double> series(Iterable<Expense> list, List<TimeBucket> buckets) {
    final out = List<double>.filled(buckets.length, 0);
    for (final e in list) {
      for (var i = 0; i < buckets.length; i++) {
        if (!e.date.isBefore(buckets[i].start) &&
            e.date.isBefore(buckets[i].end)) {
          out[i] += e.amount;
          break;
        }
      }
    }
    return out;
  }
}
