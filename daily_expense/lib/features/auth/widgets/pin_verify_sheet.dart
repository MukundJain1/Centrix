import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/colors.dart';
import '../auth_config.dart';
import '../data/auth_repository.dart';
import 'auth_pinput.dart';
import 'shake_widget.dart';

/// Prompts the user to verify their account PIN via POST /v1/auth/verify-pin.
/// Returns true if verified, false/null if dismissed.
Future<bool> showPinVerifySheet(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PinVerifySheet(title: title, subtitle: subtitle),
  );
  return result == true;
}

class _PinVerifySheet extends StatefulWidget {
  const _PinVerifySheet({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<_PinVerifySheet> createState() => _PinVerifySheetState();
}

class _PinVerifySheetState extends State<_PinVerifySheet> {
  final _pinCtrl = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify(String pin) async {
    if (_verifying || pin.length < AuthConfig.pinLength) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final ok = await AuthRepository.instance.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        _fail('Wrong PIN. Please try again.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'WRONG_PIN' && e.attemptsLeft != null) {
        _fail(
          e.attemptsLeft == 1
              ? 'Wrong PIN. 1 attempt left.'
              : 'Wrong PIN. ${e.attemptsLeft} attempts left.',
        );
      } else {
        _fail(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      _fail('Could not verify PIN. Check your connection.');
    }
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _verifying = false;
      _error = message;
    });
    _shakeKey.currentState?.shake();
    _pinCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.primaryAccent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ShakeWidget(
                key: _shakeKey,
                child: AuthPinput(
                  controller: _pinCtrl,
                  length: AuthConfig.pinLength,
                  enabled: !_verifying,
                  obscure: true,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onCompleted: _verify,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (_verifying) ...[
                const SizedBox(height: 16),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}