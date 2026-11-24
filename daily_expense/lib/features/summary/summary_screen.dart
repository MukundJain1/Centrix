import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../expenses/expense.dart';
import '../expenses/expense_repository.dart';
import '../settings/app_settings.dart';
import 'category_detail_screen.dart';
import 'summary_calc.dart';
import 'widgets/donut_chart.dart';
import 'widgets/granularity_selector.dart';
import 'widgets/ranked_bars.dart';
import 'widgets/summary_card.dart';
import 'widgets/trend_bar_chart.dart';

/// Summary tab: where the money goes, by category, over time.
/// Tap a category to drill into its merchants (Food -> Swiggy, Zomato ...).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Granularity _granularity = Granularity.weekly;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ExpenseRepository.instance,
        AppSettings.instance,
      ]),
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final s = AppSettings.instance;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 16.0 : 20.0;
    final donutSize = (width * 0.5).clamp(150.0, 210.0).toDouble();

    final buckets = SummaryCalc.buckets(_granularity, DateTime.now());
    final window = SummaryCalc.inWindow(ExpenseRepository.instance.all, buckets);
    final total = SummaryCalc.total(window);
    final byCategory = SummaryCalc.rank(window, (e) => e.category);
    final byMerchant = SummaryCalc.rank(window, (e) => e.merchant);
    final trend = SummaryCalc.series(window, buckets);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
          children: [
            GranularitySelector(
              value: _granularity,
              onChanged: (g) => setState(() => _granularity = g),
            ),
            const SizedBox(height: 16),
            _totalCard(s, total, trend, buckets.length),
            SummaryCard(
              title: 'Where your money goes',
              child: byCategory.isEmpty
                  ? _empty()
                  : Column(
                      children: [
                        Center(
                          child: DonutChart(
                            size: donutSize,
                            centerTop: 'Total',
                            centerBottom: s.money(total),
                            slices: [
                              for (final e in byCategory)
                                DonutSlice(
                                  e.value,
                                  ExpenseCategories.of(e.key).color,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RankedBars(
                          total: total,
                          format: s.money,
                          items: [
                            for (final e in byCategory)
                              RankedItem(
                                label: e.key,
                                value: e.value,
                                color: ExpenseCategories.of(e.key).color,
                                icon: ExpenseCategories.of(e.key).icon,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryDetailScreen(
                                      category: e.key,
                                      initialGranularity: _granularity,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap a category to see where exactly you spend.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
            SummaryCard(
              title: 'Spending trend',
              trailing: Text(
                _granularity.windowLabel,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              child: TrendBarChart(
                key: ValueKey(_granularity),
                labels: [for (final b in buckets) b.label],
                series: [
                  ChartSeries(
                    name: 'Spent',
                    color: AppColors.primaryAccent,
                    values: trend,
                  ),
                ],
                format: s.money,
                compact: s.compact,
              ),
            ),
            if (total > 0)
              _insights(s, total, byCategory, byMerchant, trend, buckets),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No spending in this period yet.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _totalCard(
    AppSettings s,
    double total,
    List<double> trend,
    int bucketCount,
  ) {
    final last = trend.last;
    final previous = trend[trend.length - 2];

    Widget? change;
    if (previous > 0) {
      final pct = ((last - previous) / previous * 100).round();
      final up = pct > 0;
      change = Text(
        '${_granularity.currentLabel} ${s.money(last)} · '
        '${up ? '↑' : '↓'} ${pct.abs()}% vs ${_granularity.previousLabel}',
        style: TextStyle(
          color: up ? Colors.redAccent : const Color(0xFF5BAA77),
          fontSize: 13,
        ),
      );
    } else if (last > 0) {
      change = Text(
        '${_granularity.currentLabel} ${s.money(last)}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }

    return SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total spent · ${_granularity.windowLabel}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              s.money(total),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Average ${s.money(total / bucketCount)} per ${_granularity.unit}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          if (change != null) ...[
            const SizedBox(height: 6),
            change,
          ],
        ],
      ),
    );
  }

  Widget _insights(
    AppSettings s,
    double total,
    List<MapEntry<String, double>> byCategory,
    List<MapEntry<String, double>> byMerchant,
    List<double> trend,
    List<TimeBucket> buckets,
  ) {
    var peak = 0;
    for (var i = 1; i < trend.length; i++) {
      if (trend[i] > trend[peak]) peak = i;
    }

    final topCategory = byCategory.first;
    final topMerchant = byMerchant.first;
    final share = (topCategory.value / total * 100).round();

    final lines = <_InsightLine>[
      _InsightLine(
        Icons.pie_chart_rounded,
        '${topCategory.key} is your biggest spend: $share% of the total.',
      ),
      _InsightLine(
        Icons.storefront_rounded,
        '${topMerchant.key} is where you spend the most (${s.money(topMerchant.value)}).',
      ),
      _InsightLine(
        Icons.bar_chart_rounded,
        'Your highest ${_granularity.unit} was ${buckets[peak].label} (${s.money(trend[peak])}).',
      ),
    ];

    return SummaryCard(
      title: 'Insights',
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(line.icon, size: 18, color: AppColors.primaryAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      line.text,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightLine {
  const _InsightLine(this.icon, this.text);

  final IconData icon;
  final String text;
}
