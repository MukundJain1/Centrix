import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_snackbar.dart';
import 'auth_config.dart';
import 'auth_storage.dart';
import 'auth_validators.dart';
import 'country.dart';
import 'data/auth_models.dart';
import 'data/auth_repository.dart';
import 'widgets/auth_button.dart';
import 'widgets/auth_error_text.dart';
import 'widgets/auth_label.dart';
import 'widgets/auth_phone_field.dart';
import 'widgets/auth_pin_label.dart';
import 'widgets/auth_pinput.dart';
import 'widgets/auth_scale.dart';
import 'widgets/shake_widget.dart';

/// Phone number + PIN. The SERVER checks the PIN; a wrong PIN shows a custom
/// snackbar, wiggles the boxes and clears them.
/// The country and number used last time are filled in automatically.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.onSuccess});

  /// Called with the user's profile once the server accepts the PIN.
  final ValueChanged<MeModel> onSuccess;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  Country _country = Country.india;
  bool _showPin = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    final country = await AuthStorage.loadCountry();
    final phone = await AuthStorage.loadLastPhone();
    if (!mounted) return;
    setState(() {
      _country = country;
      if (phone != null && _phoneCtrl.text.isEmpty) _phoneCtrl.text = phone;
    });
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final error = AuthValidators.phone(_phoneCtrl.text, _country) ??
        AuthValidators.pin(_pinCtrl.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final phone = _phoneCtrl.text.trim();
      final me = await AuthRepository.instance.login(_country, phone, _pinCtrl.text);
      await AuthStorage.saveCountry(_country);
      await AuthStorage.saveLastPhone(phone);
      if (!mounted) return;
      widget.onSuccess(me);
    } on ApiException catch (e) {
      if (!mounted) return;
      _handleLoginError(e);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleLoginError(ApiException e) {
    switch (e.code) {
      case 'WRONG_PIN':
        final left = e.attemptsLeft;
        AppSnackbar.error(
          context,
          left == null
              ? 'Wrong PIN. Please try again.'
              : left == 1
                  ? 'Wrong PIN. 1 attempt left.'
                  : 'Wrong PIN. $left attempts left.',
          icon: Icons.lock_outline_rounded,
        );
        HapticFeedback.heavyImpact();
        _shakeKey.currentState?.shake();
        _pinCtrl.clear();
      case 'PIN_LOCKED':
        AppSnackbar.warning(context, e.message, icon: Icons.lock_clock_rounded);
        HapticFeedback.heavyImpact();
        _pinCtrl.clear();
      case 'NETWORK':
        AppSnackbar.error(context, e.message, icon: Icons.wifi_off_rounded);
      case 'INVALID_PHONE' || 'VALIDATION_ERROR':
        setState(() => _error = e.message);
      default:
        AppSnackbar.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthLabel('Mobile number'),
        const SizedBox(height: 10),
        AuthPhoneField(
          controller: _phoneCtrl,
          country: _country,
          onCountryChanged: (c) {
            if (mounted) setState(() => _country = c);
          },
          enabled: !_loading,
          onChanged: (_) => _clearError(),
        ),
        SizedBox(height: sc.gap(22)),
        AuthPinLabel(
          label: '${AuthConfig.pinLength}-digit PIN',
          visible: _showPin,
          onToggle: () => setState(() => _showPin = !_showPin),
        ),
        const SizedBox(height: 10),
        ShakeWidget(
          key: _shakeKey,
          child: AuthPinput(
            controller: _pinCtrl,
            length: AuthConfig.pinLength,
            enabled: !_loading,
            obscure: !_showPin,
            onChanged: (_) => _clearError(),
            // Sign in as soon as the last digit is typed.
            onCompleted: (_) {
              if (AuthValidators.phone(_phoneCtrl.text, _country) == null) {
                _submit();
              }
            },
          ),
        ),
        AuthErrorText(message: _error),
        SizedBox(height: sc.gap(28)),
        AuthButton(label: 'Unlock', loading: _loading, onPressed: _submit),
        SizedBox(height: sc.gap(12)),
        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () {
                    // TODO: Forgot PIN -> OTP (reuse OtpVerification), then set a new PIN.
                  },
            child: const Text(
              'Forgot PIN?',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
