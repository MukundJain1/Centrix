import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../summary_calc.dart';

/// Daily / Weekly / Monthly pill switcher.
class GranularitySelector extends StatelessWidget {
  const GranularitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Granularity value;
  final ValueChanged<Granularity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (final g in Granularity.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(g),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: g == value
                        ? AppColors.primaryAccent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: g == value
                          ? AppColors.primaryAccent
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      g.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: g == value
                            ? AppColors.primaryAccent
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
