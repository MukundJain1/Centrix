import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'expense.dart';

/// Single source of truth for expenses, used by the Dashboard and Summary.
///
/// For now it holds generated mock data. TODO(backend): replace the mock
/// with API calls; keep the same methods so the screens don't change.
/// The future "Add expense" screen should just call [add].
class ExpenseRepository extends ChangeNotifier {
  ExpenseRepository._() {
    _expenses = _generateMock();
  }

  static final ExpenseRepository instance = ExpenseRepository._();

  late List<Expense> _expenses;

  List<Expense> get all => List.unmodifiable(_expenses);

  void add(Expense expense) {
    _expenses.add(expense);
    notifyListeners();
  }

  void clear() {
    _expenses = [];
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Expenses on [day], oldest first.
  List<Expense> on(DateTime day) {
    final list = _expenses.where((e) => _sameDay(e.date, day)).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  double totalOn(DateTime day) =>
      on(day).fold<double>(0, (sum, e) => sum + e.amount);

  // ----------------------------------------------------------- mock data

  static const _amountRanges = <String, List<int>>{
    'Food': [120, 650],
    'Fuel': [300, 1500],
    'Shopping': [400, 3000],
    'Transport': [60, 500],
    'Bills': [200, 1800],
    'Health': [100, 1200],
  };

  static List<Expense> _generateMock() {
    final rand = math.Random(7); // fixed seed: same data every launch
    final now = DateTime.now();

    final result = <Expense>[
      Expense(
        date: DateTime(now.year, now.month, now.day, 9, 30),
        category: 'Fuel',
        merchant: 'Indian Oil',
        amount: 250,
      ),
      Expense(
        date: DateTime(now.year, now.month, now.day, 13, 15),
        category: 'Food',
        merchant: 'Zomato',
        amount: 250,
      ),
    ];

    // Food shows up more often than the rest.
    const weighted = [0, 0, 0, 0, 0, 1, 2, 2, 3, 3, 3, 4, 5];

    for (var i = 1; i < 200; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final count = rand.nextInt(4);
      for (var k = 0; k < count; k++) {
        final cat = ExpenseCategories.all[weighted[rand.nextInt(weighted.length)]];
        final merchant = cat.merchants[rand.nextInt(cat.merchants.length)];
        final range = _amountRanges[cat.name]!;
        final raw = range[0] + rand.nextInt(range[1] - range[0]);
        result.add(
          Expense(
            date: DateTime(
              day.year,
              day.month,
              day.day,
              8 + rand.nextInt(14),
              rand.nextInt(60),
            ),
            category: cat.name,
            merchant: merchant,
            amount: ((raw / 10).round() * 10).toDouble(),
          ),
        );
      }
    }
    return result;
  }
}
