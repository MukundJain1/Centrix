import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import 'auth_scale.dart';

/// Primary outlined button with a loading spinner.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);

    return SizedBox(
      height: sc.size(54, min: 46),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.12),
          disabledBackgroundColor:
              AppColors.primaryAccent.withValues(alpha: 0.06),
          foregroundColor: AppColors.primaryAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primaryAccent,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }
}
