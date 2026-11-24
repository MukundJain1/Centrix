import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../baseline_snapshot.dart';

class BaselineResult {
  const BaselineResult({
    required this.currency,
    required this.monthlySurplus,
    required this.dailyLimit,
  });

  final String currency;
  final double? monthlySurplus;
  final double? dailyLimit;
}

/// Financial Baseline + payday cycle, stored on the server.
class BaselineRepository {
  BaselineRepository._();
  static final BaselineRepository instance = BaselineRepository._();

  final ApiClient _api = ApiClient.instance;

  /// What the user saved. Null when nothing is saved yet.
  Future<BaselineSnapshot?> load() async {
    final body = await _api.send('GET', '/v1/baseline') as Map<String, dynamic>;
    final categories = (body['categories'] as List).cast<Map<String, dynamic>>();
    if (categories.isEmpty) return null;

    return BaselineSnapshot(
      currency: (body['currency'] as String?) ?? '₹',
      categories: [
        for (final c in categories)
          CategorySnapshot(
            title: c['title'] as String,
            isIncome: c['is_income'] as bool,
            isCustom: c['is_custom'] as bool,
            items: [
              for (final i in (c['items'] as List).cast<Map<String, dynamic>>())
                ItemSnapshot(
                  name: i['name'] as String,
                  amount: _amountText((i['amount'] as num).toDouble()),
                ),
            ],
          ),
      ],
    );
  }

  /// Saves the whole baseline. The server recalculates the monthly surplus.
  Future<BaselineResult> save(BaselineSnapshot snapshot) async {
    final body = await _api.send(
      'PUT',
      '/v1/baseline',
      data: {
        'currency': snapshot.currency,
        'categories': [
          for (final c in snapshot.categories)
            {
              'title': c.title,
              'is_income': c.isIncome,
              'is_custom': c.isCustom,
              'items': [
                for (final i in c.items)
                  {'name': i.name, 'amount': double.tryParse(i.amount) ?? 0},
              ],
            },
        ],
      },
    ) as Map<String, dynamic>;

    return BaselineResult(
      currency: body['currency'] as String,
      monthlySurplus: (body['monthly_surplus'] as num?)?.toDouble(),
      dailyLimit: (body['daily_limit'] as num?)?.toDouble(),
    );
  }

  /// Payday + money left now -> the server works out the daily budget.
  Future<MeModel> saveCycle({required int payday, required double currentBalance}) async {
    final now = DateTime.now();
    final body = await _api.send(
      'PUT',
      '/v1/cycle',
      data: {
        'payday': payday,
        'current_balance': currentBalance,
        // Our local date, so "today" is right even if the server is in UTC.
        'client_date':
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      },
    ) as Map<String, dynamic>;
    return MeModel.fromJson(body);
  }

  /// 15000.0 -> "15000", 15000.5 -> "15000.5"
  static String _amountText(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
