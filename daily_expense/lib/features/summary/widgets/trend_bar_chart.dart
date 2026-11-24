import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.color,
    required this.values,
  });

  final String name;
  final Color color;

  /// One value per label.
  final List<double> values;
}

/// Vertical bars over time. One series = simple bars with values on top;
/// several series = grouped bars for comparing. Tap a group for the exact
/// numbers.
class TrendBarChart extends StatefulWidget {
  const TrendBarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.format,
    required this.compact,
    this.height = 200,
  });

  final List<String> labels;
  final List<ChartSeries> series;

  /// Full amount, e.g. "₹1,226".
  final String Function(double) format;

  /// Short amount for bar tops, e.g. "1.2k".
  final String Function(double) compact;
  final double height;

  @override
  State<TrendBarChart> createState() => _TrendBarChartState();
}

class _TrendBarChartState extends State<TrendBarChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant TrendBarChart old) {
    super.didUpdateWidget(old);
    if (old.labels.length != widget.labels.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = widget.series
        .expand((s) => s.values)
        .fold<double>(0, (m, v) => v > m ? v : m);

    if (maxValue <= 0) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No spending in this period',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final showValues = widget.series.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const labelHeight = 22.0;
              const valueHeight = 16.0;
              final areaHeight = constraints.maxHeight - labelHeight;
              final barMax = areaHeight - (showValues ? valueHeight + 2 : 4);

              return Stack(
                children: [
                  // Faint guide lines.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: areaHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.labels.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(
                              () => _selected = _selected == i ? null : i,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: areaHeight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final s in widget.series)
                                        Flexible(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 1.5,
                                            ),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 28,
                                              ),
                                              child: _bar(
                                                s,
                                                s.values[i],
                                                maxValue,
                                                barMax,
                                                showValues,
                                                i,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: labelHeight,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        widget.labels[i],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: _selected == i
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _selected == i
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _details(),
      ],
    );
  }

  Widget _bar(
    ChartSeries s,
    double value,
    double maxValue,
    double barMax,
    bool showValue,
    int index,
  ) {
    final dimmed = _selected != null && _selected != index;
    final color = dimmed ? s.color.withValues(alpha: 0.3) : s.color;
    final height = value <= 0 ? 0.0 : (value / maxValue * barMax).clamp(3.0, barMax).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showValue && value > 0)
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.compact(value),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        if (showValue && value > 0) const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
      ],
    );
  }

  /// Line under the chart: hint, or the exact numbers of the tapped group.
  Widget _details() {
    final i = _selected;
    if (i == null || i >= widget.labels.length) {
      return const Text(
        'Tap a bar for exact amounts',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          widget.labels[i],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        for (final s in widget.series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                widget.series.length == 1
                    ? widget.format(s.values[i])
                    : '${s.name} ${widget.format(s.values[i])}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
