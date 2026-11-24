import 'package:flutter/material.dart';

class Expense {
  const Expense({
    required this.date,
    required this.category,
    required this.merchant,
    required this.amount,
  });

  /// Date and time of the spend.
  final DateTime date;
  final String category;
  final String merchant;
  final double amount;
}

class CategoryMeta {
  const CategoryMeta(this.name, this.icon, this.color, this.merchants);

  final String name;
  final IconData icon;
  final Color color;
  final List<String> merchants;
}

/// Categories and their usual merchants (used for the Add Expense screen and
/// for the mock data). TODO(backend): load from the server / user settings.
class ExpenseCategories {
  ExpenseCategories._();

  static const List<CategoryMeta> all = [
    CategoryMeta('Food', Icons.restaurant_rounded, Color(0xFFE2725B),
        ['Swiggy', 'Zomato', 'Restaurant', 'Cafe']),
    CategoryMeta('Fuel', Icons.local_gas_station_rounded, Color(0xFFF2A65A),
        ['Indian Oil', 'HP', 'Bharat Petroleum']),
    CategoryMeta('Shopping', Icons.shopping_bag_rounded, Color(0xFF9B7EDE),
        ['Amazon', 'Flipkart', 'Myntra']),
    CategoryMeta('Transport', Icons.directions_car_rounded, Color(0xFF4FC3F7),
        ['Uber', 'Ola', 'Metro']),
    CategoryMeta('Bills', Icons.receipt_long_rounded, Color(0xFF66BB6A),
        ['Electricity', 'Mobile', 'Netflix']),
    CategoryMeta('Health', Icons.favorite_rounded, Color(0xFFEF5350),
        ['Pharmacy', 'Clinic']),
  ];

  static const CategoryMeta other =
      CategoryMeta('Other', Icons.category_rounded, Color(0xFF90A4AE), []);

  static CategoryMeta of(String name) {
    for (final c in all) {
      if (c.name == name) return c;
    }
    return other;
  }
}
