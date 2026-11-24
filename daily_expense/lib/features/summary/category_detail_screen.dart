import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../expenses/expense.dart';
import '../expenses/expense_repository.dart';
import '../settings/app_settings.dart';
import 'summary_calc.dart';
import 'widgets/granularity_selector.dart';
import 'widgets/ranked_bars.dart';
import 'widgets/summary_card.dart';
import 'widgets/trend_bar_chart.dart';

/// One category (e.g. Food): which merchants you use, how much you spend on
/// each over time, and a side-by-side comparison (Swiggy vs Zomato).
///
/// No merchant selected  -> one chart for the whole category.
/// One merchant selected -> that merchant's spending.
/// Two or more selected  -> grouped bars to compare them.
class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.initialGranularity,
  });

  final String category;
  final Granularity initialGranularity;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  static const int _maxCompare = 4;
  static const _palette = [
    Color(0xFF4DD0E1),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF81C784),
  ];

  late Granularity _granularity = widget.initialGranularity;
  final Set<String> _selected = {};

  void _toggle(String merchant) {
    setState(() {
      if (_selected.contains(merchant)) {
        _selected.remove(merchant);
      } else if (_selected.length >= _maxCompare) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('You can compare up to 4 at a time.')),
          );
      } else {
        _selected.add(merchant);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final meta = ExpenseCategories.of(widget.category);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryAccent),
        title: Row(
          children: [
            Icon(meta.icon, color: meta.color, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.category,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            ExpenseRepository.instance,
            AppSettings.instance,
          ]),
          builder: (context, _) => _content(context, meta),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CategoryMeta meta) {
    final s = AppSettings.instance;
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;

    final everything = ExpenseRepository.instance.all;
    final buckets = SummaryCalc.buckets(_granularity, DateTime.now());
    final overall = SummaryCalc.total(SummaryCalc.inWindow(everything, buckets));

    final ofCategory =
        everything.where((e) => e.category == widget.category).toList();
    final window = SummaryCalc.inWindow(ofCategory, buckets);
    final total = SummaryCalc.total(window);

    // Merchants: biggest first, then the ones with no spend in this window.
    final ranked = SummaryCalc.rank(window, (e) => e.merchant);
    final allNames = ofCategory.map((e) => e.merchant).toSet().toList()..sort();
    final names = [
      for (final e in ranked) e.key,
      for (final n in allNames)
        if (!ranked.any((e) => e.key == n)) n,
    ];
    Color colorFor(String m) => _palette[allNames.indexOf(m) % _palette.length];

    // What the chart shows.
    final picked = names.where(_selected.contains).toList();
    final List<ChartSeries> series = picked.isEmpty
        ? [
            ChartSeries(
              name: widget.category,
              color: meta.color,
              values: SummaryCalc.series(window, buckets),
            ),
          ]
        : [
            for (final m in picked)
              ChartSeries(
                name: m,
                color: colorFor(m),
                values: SummaryCalc.series(
                  window.where((e) => e.merchant == m),
                  buckets,
                ),
              ),
          ];

    final chartTitle = picked.isEmpty
        ? '${widget.category} spending'
        : picked.length == 1
            ? '${picked.first} spending'
            : 'Comparing ${picked.join(' vs ')}';

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
            SummaryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent on ${widget.category} · ${_granularity.windowLabel}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      s.money(total),
                      style: TextStyle(
                        color: meta.color,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overall > 0
                        ? '${(total / overall * 100).round()}% of all your spending'
                        : 'No spending in this period yet',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (total > 0)
              SummaryCard(
                title: 'Where you spend',
                child: RankedBars(
                  total: total,
                  format: s.money,
                  items: [
                    for (final e in ranked)
                      RankedItem(
                        label: e.key,
                        value: e.value,
                        color: colorFor(e.key),
                      ),
                  ],
                ),
              ),
            if (names.length > 1)
              SummaryCard(
                title: 'Compare',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          label: 'All',
                          selected: picked.isEmpty,
                          color: meta.color,
                          onTap: () => setState(_selected.clear),
                        ),
                        for (final m in names)
                          _chip(
                            label: m,
                            selected: _selected.contains(m),
                            color: colorFor(m),
                            onTap: () => _toggle(m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pick one to focus on it, or two or more to compare.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            SummaryCard(
              title: chartTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrendBarChart(
                    key: ValueKey('${_granularity.name}-${picked.join(',')}'),
                    labels: [for (final b in buckets) b.label],
                    series: series,
                    format: s.money,
                    compact: s.compact,
                  ),
                  if (series.length > 1) ...[
                    const SizedBox(height: 16),
                    _comparisonSummary(s, series, buckets.length),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.background,
      selectedColor: color.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected ? color : Colors.white.withValues(alpha: 0.1),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? color : AppColors.textMuted,
      ),
    );
  }

  /// Legend with totals, plus a one-line verdict when comparing two.
  Widget _comparisonSummary(
    AppSettings s,
    List<ChartSeries> series,
    int bucketCount,
  ) {
    final totals = [
      for (final x in series) x.values.fold<double>(0, (a, b) => a + b),
    ];

    String? verdict;
    if (series.length == 2) {
      final diff = (totals[0] - totals[1]).abs();
      if (diff == 0) {
        verdict = 'You spent the same on ${series[0].name} and ${series[1].name}.';
      } else {
        final more = totals[0] > totals[1] ? 0 : 1;
        final less = 1 - more;
        verdict =
            'You spent ${s.money(diff)} more on ${series[more].name} than on ${series[less].name}.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < series.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: series[i].color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    series[i].name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${s.money(totals[i])}  ·  avg ${s.money(totals[i] / bucketCount)}/${_granularity.unit}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (verdict != null) ...[
          const SizedBox(height: 8),
          Text(
            verdict,
            style: const TextStyle(
              color: AppColors.primaryAccent,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
