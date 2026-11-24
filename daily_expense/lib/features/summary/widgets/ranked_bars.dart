import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class RankedItem {
  const RankedItem({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.onTap,
  });

  final String label;
  final double value;
  final Color color;
  final IconData? icon;

  /// When set, the row shows a chevron and can be tapped.
  final VoidCallback? onTap;
}

/// Biggest first: name, amount, share of the total and a bar.
class RankedBars extends StatelessWidget {
  const RankedBars({
    super.key,
    required this.items,
    required this.total,
    required this.format,
  });

  final List<RankedItem> items;
  final double total;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(0, (m, i) => i.value > m ? i.value : m);

    return Column(
      children: [
        for (final item in items)
          InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (item.icon != null) ...[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 18, color: item.color),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        format(item.value),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.onTap != null)
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxValue > 0 ? item.value / maxValue : 0,
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation(item.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 40,
                        child: Text(
                          total > 0
                              ? '${(item.value / total * 100).round()}%'
                              : '0%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
