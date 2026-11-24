import 'dart:convert';

/// Plain-data copy of what the user entered in the Financial Baseline, so it
/// can be saved and shown again in Edit Baseline.
///
/// TODO(backend): send this to the server instead of keeping it on the device.
class ItemSnapshot {
  const ItemSnapshot({required this.name, required this.amount});

  final String name;

  /// Kept as the text the user typed.
  final String amount;

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};

  factory ItemSnapshot.fromJson(Map<String, dynamic> json) => ItemSnapshot(
        name: (json['name'] as String?) ?? '',
        amount: (json['amount'] as String?) ?? '',
      );
}

class CategorySnapshot {
  const CategorySnapshot({
    required this.title,
    required this.isIncome,
    required this.isCustom,
    required this.items,
  });

  final String title;
  final bool isIncome;
  final bool isCustom;
  final List<ItemSnapshot> items;

  Map<String, dynamic> toJson() => {
        'title': title,
        'isIncome': isIncome,
        'isCustom': isCustom,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory CategorySnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return CategorySnapshot(
      title: (json['title'] as String?) ?? '',
      isIncome: (json['isIncome'] as bool?) ?? false,
      isCustom: (json['isCustom'] as bool?) ?? false,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ItemSnapshot.fromJson)
          .toList(),
    );
  }
}

class BaselineSnapshot {
  const BaselineSnapshot({required this.currency, required this.categories});

  final String currency;
  final List<CategorySnapshot> categories;

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  /// Returns null when [source] is missing or not valid.
  static BaselineSnapshot? decode(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      final rawCategories = (map['categories'] as List?) ?? const [];
      return BaselineSnapshot(
        currency: (map['currency'] as String?) ?? '₹',
        categories: rawCategories
            .whereType<Map<String, dynamic>>()
            .map(CategorySnapshot.fromJson)
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}
