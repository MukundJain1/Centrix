import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_format.dart';

/// Sticky bottom bar: live Daily budget + Monthly surplus and the
/// "Save & continue" button. Numbers animate as the user types.
class BudgetSummaryBar extends StatelessWidget {
  const BudgetSummaryBar({
    super.key,
    required this.dailyBudget,
    required this.surplus,
    required this.currency,
    required this.onSave,
    this.message,
    this.showButton = true,
    this.loading = false,
    this.buttonLabel = 'Save & continue',
  });

  final double dailyBudget;
  final double surplus;
  final String currency;
  final VoidCallback onSave;

  /// Red hint shown under the numbers (e.g. expenses higher than income).
  final String? message;

  /// Hide the button while the keyboard is open to leave room for the form.
  final bool showButton;
  final bool loading;

  /// "Save & continue" while setting up, "Save changes" when editing.
  final String buttonLabel;

  static const _positive = Color(0xFF5BAA77);

  @override
  Widget build(BuildContext context) {
    final surplusColor = surplus < 0 ? Colors.redAccent : _positive;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daily budget',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _AnimatedMoney(
                              value: dailyBudget,
                              currency: currency,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Monthly surplus',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _AnimatedMoney(
                              value: surplus,
                              currency: currency,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: surplusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: message == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              message!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: showButton
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: loading ? null : onSave,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor:
                                      Colors.white.withValues(alpha: 0.5),
                                  shape: const StadiumBorder(),
                                ),
                                child: loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        buttonLabel,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Counts smoothly from the old value to the new one, and shrinks to fit
/// when the number is very large.
class _AnimatedMoney extends StatelessWidget {
  const _AnimatedMoney({
    required this.value,
    required this.currency,
    required this.style,
  });

  final double value;
  final String currency;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 250),
      builder: (context, v, _) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyFormat.format(v, currency),
            maxLines: 1,
            style: style,
          ),
        );
      },
    );
  }
}
