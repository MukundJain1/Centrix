import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import 'auth_label.dart';

/// Label on the left, Show/Hide PIN toggle on the right.
class AuthPinLabel extends StatelessWidget {
  const AuthPinLabel({
    super.key,
    required this.label,
    required this.visible,
    required this.onToggle,
  });

  final String label;
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AuthLabel(label),
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                visible ? Icons.visibility_off : Icons.visibility,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                visible ? 'Hide' : 'Show',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
