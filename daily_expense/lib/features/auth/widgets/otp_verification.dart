import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../auth_config.dart';
import 'auth_button.dart';
import 'auth_error_text.dart';
import 'auth_pinput.dart';
import 'auth_scale.dart';

/// Reusable OTP step: 6 boxes, resend timer, verify button.
/// Used by Register now, and can be reused for "Forgot PIN" later.
///
/// [onVerify] and [onResend] return an error message, or null on success.
class OtpVerification extends StatefulWidget {
  const OtpVerification({
    super.key,
    required this.dialCode,
    required this.phone,
    required this.onVerify,
    required this.onResend,
    this.onChangeNumber,
    this.verifyLabel = 'Verify',
  });

  /// e.g. "+91"
  final String dialCode;
  final String phone;
  final Future<String?> Function(String otp) onVerify;
  final Future<String?> Function() onResend;
  final VoidCallback? onChangeNumber;
  final String verifyLabel;

  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> {
  final _ctrl = TextEditingController();
  Timer? _timer;
  int _seconds = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = AuthConfig.otpResendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_loading) return;
    if (_ctrl.text.length != AuthConfig.otpLength) {
      setState(() => _error = 'Enter the ${AuthConfig.otpLength}-digit code');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    String? error;
    try {
      error = await widget.onVerify(_ctrl.text);
    } catch (_) {
      error = 'Could not verify the code. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      if (error != null) _ctrl.clear();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _ctrl.clear();
    });
    String? error;
    try {
      error = await widget.onResend();
    } catch (_) {
      error = 'Could not resend the code. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _startTimer();
    });
  }

  String get _formattedPhone {
    final p = widget.phone;
    if (widget.dialCode == '+91' && p.length == 10) {
      return '${widget.dialCode} ${p.substring(0, 5)} ${p.substring(5)}';
    }
    return '${widget.dialCode} $p';
  }

  String get _timerText {
    final s = _seconds.clamp(0, 999);
    return '0:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We sent a ${AuthConfig.otpLength}-digit code to $_formattedPhone',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        SizedBox(height: sc.gap(24)),
        AuthPinput(
          controller: _ctrl,
          length: AuthConfig.otpLength,
          maxBoxWidth: 52,
          enabled: !_loading,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onCompleted: (_) => _verify(),
        ),
        AuthErrorText(message: _error),
        SizedBox(height: sc.gap(28)),
        AuthButton(
          label: widget.verifyLabel,
          loading: _loading,
          onPressed: _verify,
        ),
        SizedBox(height: sc.gap(16)),
        Center(
          child: _seconds > 0
              ? Text(
                  'Resend code in $_timerText',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                )
              : TextButton(
                  onPressed: _loading ? null : _resend,
                  child: const Text(
                    'Resend code',
                    style: TextStyle(color: AppColors.primaryAccent),
                  ),
                ),
        ),
        if (widget.onChangeNumber != null)
          Center(
            child: TextButton(
              onPressed: _loading ? null : widget.onChangeNumber,
              child: const Text(
                'Change number',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
