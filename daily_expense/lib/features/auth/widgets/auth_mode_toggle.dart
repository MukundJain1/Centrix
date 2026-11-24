import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import 'auth_scale.dart';

/// Pill switcher: Sign In / Register.
class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle({
    super.key,
    required this.isLogin,
    required this.onChanged,
  });

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);
    final vPad = sc.size(12, min: 8);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _tab('Sign In', isLogin, vPad, () => onChanged(true)),
          _tab('Register', !isLogin, vPad, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _tab(String text, bool selected, double vPad, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: vPad),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryAccent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected ? AppColors.primaryAccent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    selected ? AppColors.primaryAccent : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
