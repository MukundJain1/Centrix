import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../core/theme/colors.dart';

/// Styled Pinput used for both the PIN (obscured) and the OTP (visible).
///
/// Box size adapts to the available width, so 4 PIN boxes or 6 OTP boxes fit
/// on narrow phones as well as larger ones.
class AuthPinput extends StatelessWidget {
  const AuthPinput({
    super.key,
    required this.controller,
    required this.length,
    this.enabled = true,
    this.obscure = false,
    this.maxBoxWidth = 60,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool obscure;
  final double maxBoxWidth;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minGap = 8.0;
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;

        final boxWidth = ((available - minGap * (length - 1)) / length)
            .clamp(36.0, maxBoxWidth)
            .toDouble();
        final boxHeight = (boxWidth * 1.1).clamp(46.0, 60.0).toDouble();

        final base = PinTheme(
          width: boxWidth,
          height: boxHeight,
          textStyle: TextStyle(
            fontSize: boxWidth < 44 ? 20 : 24,
            color: AppColors.textPrimary,
          ),
          decoration: BoxDecoration(
            color: AppColors.inputSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
        );

        return SizedBox(
          width: available,
          child: Pinput(
            controller: controller,
            length: length,
            enabled: enabled,
            obscureText: obscure,
            obscuringWidget: const Text(
              '●',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20),
            ),
            keyboardType: TextInputType.number,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            defaultPinTheme: base,
            focusedPinTheme: base.copyWith(
              decoration: base.decoration!.copyWith(
                border: Border.all(color: AppColors.primaryAccent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            submittedPinTheme: base,
            onChanged: onChanged,
            onCompleted: onCompleted,
          ),
        );
      },
    );
  }
}
