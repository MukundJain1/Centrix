import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import 'auth_scale.dart';

/// Logo, title and subtitle. Shrinks (and hides the subtitle) while the
/// keyboard is open to leave room for the form.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);
    final iconBox = sc.size(64, min: 40);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: iconBox,
          height: iconBox,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.inputSurface,
            border: Border.all(
              color: AppColors.primaryAccent.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAccent.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Icon(
            Icons.account_balance_wallet,
            size: iconBox * 0.47,
            color: AppColors.primaryAccent,
          ),
        ),
        SizedBox(height: sc.gap(24)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            title,
            key: ValueKey(title),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sc.size(26, min: 20),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: sc.keyboardOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
