import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/colors.dart';
import 'auth_config.dart';
import 'auth_storage.dart';
import 'auth_validators.dart';
import 'country.dart';
import 'data/auth_models.dart';
import 'data/auth_repository.dart';
import 'widgets/auth_3d_snackbar.dart';
import 'widgets/auth_button.dart';
import 'widgets/auth_error_text.dart';
import 'widgets/auth_label.dart';
import 'widgets/auth_phone_field.dart';
import 'widgets/auth_pin_label.dart';
import 'widgets/auth_pinput.dart';
import 'widgets/auth_scale.dart';
import 'widgets/otp_verification.dart';

/// Register steps: phone -> OTP -> set PIN.
enum RegisterStep { phone, otp, setPin }

/// Lets the parent screen ask the flow to go back one step
/// (used by the back arrow and the phone's back button).
class RegisterFlowController {
  bool Function()? _handler;

  /// Goes back one step. Returns false when already on the first step.
  bool goBack() => _handler?.call() ?? false;
}

class RegisterFlow extends StatefulWidget {
  const RegisterFlow({
    super.key,
    required this.controller,
    required this.onStepChanged,
    required this.onRegistered,
    this.onSwitchToLogin,
  });

  final RegisterFlowController controller;

  /// Lets the parent update its header / toggle for the current step.
  final ValueChanged<RegisterStep> onStepChanged;

  /// Called with the new user's profile once the account exists.
  final ValueChanged<MeModel> onRegistered;

  /// Automatically switches the parent AuthScreen toggle to Sign In.
  final VoidCallback? onSwitchToLogin;

  @override
  State<RegisterFlow> createState() => _RegisterFlowState();
}

class _RegisterFlowState extends State<RegisterFlow> {
  final _auth = AuthRepository.instance;

  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  Country _country = Country.india;
  RegisterStep _step = RegisterStep.phone;
  bool _showPin = false;
  bool _loading = false;
  String? _error;

  /// Proof from the server that this number's OTP was verified.
  String? _registrationToken;

  @override
  void initState() {
    super.initState();
    widget.controller._handler = _goBack;
  }

  @override
  void dispose() {
    // Only detach if a newer RegisterFlow has not taken over already.
    if (widget.controller._handler == _goBack) {
      widget.controller._handler = null;
    }
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _goTo(RegisterStep step) {
    setState(() {
      _step = step;
      _error = null;
      _loading = false;
    });
    widget.onStepChanged(step);
  }

  Future<void> _handlePhoneExists(String message) async {
    showAuth3dSnackBar(
      context,
      message: message,
      isError: true,
      icon: Icons.person_search_rounded,
    );
    await AuthStorage.saveCountry(_country);
    await AuthStorage.saveLastPhone(_phoneCtrl.text.trim());
    if (!mounted) return;
    widget.onSwitchToLogin?.call();
  }

  /// Network / server problems -> 3D red snackbar. Field errors -> inline text.
  void _showApiError(ApiException e) {
    final serverTrouble =
        e.isNetwork || e.code == 'UNKNOWN' || (e.statusCode ?? 0) >= 500;
    if (serverTrouble) {
      showAuth3dSnackBar(
        context,
        message: e.message,
        isError: true,
        icon: e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      );
    } else {
      setState(() => _error = e.message);
      showAuth3dSnackBar(
        context,
        message: e.message,
        isError: true,
      );
    }
  }

  /// Back from OTP returns to the phone step. Back from Set PIN also returns
  /// to the phone step (the number is already verified, so going back to the
  /// OTP screen would make no sense); the user verifies again if they change
  /// the number.
  bool _goBack() {
    if (_step == RegisterStep.phone) return false;
    if (_loading) return true; // ignore while a request is running

    if (_step == RegisterStep.setPin) {
      _registrationToken = null;
      _pinCtrl.clear();
      _confirmCtrl.clear();
      _showPin = false;
    }
    _goTo(RegisterStep.phone);
    return true;
  }

  // ------------------------------------------------------------ step 1

  Future<void> _sendOtp() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final error = AuthValidators.phone(_phoneCtrl.text, _country);
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
      await _auth.sendOtp(_country, phone);
      if (!mounted) return;
      showAuth3dSnackBar(
        context,
        message: 'OTP sent to ${_country.dialCode} $phone',
        isError: false,
        icon: Icons.mark_email_read_rounded,
      );
      _goTo(RegisterStep.otp);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PHONE_EXISTS') {
        await _handlePhoneExists(e.message);
        return;
      }
      _showApiError(e);
    } catch (_) {
      if (!mounted) return;
      showAuth3dSnackBar(
        context,
        message: 'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------ step 2

  /// Returns an error message to show under the code boxes, or null on success.
  Future<String?> _verifyOtp(String otp) async {
    try {
      final token = await _auth.verifyOtp(_country, _phoneCtrl.text.trim(), otp);
      // The user may have pressed back while the code was being checked.
      if (!mounted || _step != RegisterStep.otp) return null;

      showAuth3dSnackBar(
        context,
        message: 'Mobile number verified successfully!',
        isError: false,
        icon: Icons.verified_rounded,
      );
      _registrationToken = token;
      _goTo(RegisterStep.setPin);
      return null;
    } on ApiException catch (e) {
      final left = e.attemptsLeft;
      final msg = (e.code == 'WRONG_OTP' && left != null)
          ? '${e.message} $left ${left == 1 ? 'attempt' : 'attempts'} left.'
          : e.message;
      if (mounted) {
        showAuth3dSnackBar(
          context,
          message: msg,
          isError: true,
          icon: Icons.gpp_bad_rounded,
        );
      }
      return msg;
    } catch (_) {
      const msg = 'Could not verify the code. Please try again.';
      if (mounted) {
        showAuth3dSnackBar(context, message: msg, isError: true);
      }
      return msg;
    }
  }

  Future<String?> _resendOtp() async {
    try {
      final phone = _phoneCtrl.text.trim();
      await _auth.sendOtp(_country, phone);
      if (mounted) {
        showAuth3dSnackBar(
          context,
          message: 'New OTP sent to ${_country.dialCode} $phone',
          isError: false,
          icon: Icons.mark_email_read_rounded,
        );
      }
      return null;
    } on ApiException catch (e) {
      if (mounted) {
        showAuth3dSnackBar(context, message: e.message, isError: true);
      }
      return e.message;
    } catch (_) {
      const msg = 'Could not resend the code. Please try again.';
      if (mounted) {
        showAuth3dSnackBar(context, message: msg, isError: true);
      }
      return msg;
    }
  }

  void _changeNumber() => _goTo(RegisterStep.phone);

  // ------------------------------------------------------------ step 3

  Future<void> _createAccount() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final error = AuthValidators.pin(_pinCtrl.text) ??
        AuthValidators.confirmPin(_pinCtrl.text, _confirmCtrl.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final token = _registrationToken;
    if (token == null) {
      _goTo(RegisterStep.phone);
      showAuth3dSnackBar(
        context,
        message: 'Please verify your number again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final me = await _auth.register(token, _pinCtrl.text);
      // Remember the country and number so Sign In opens with them filled in.
      await AuthStorage.saveCountry(_country);
      await AuthStorage.saveLastPhone(_phoneCtrl.text.trim());
      if (!mounted) return;
      widget.onRegistered(me);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'INVALID_REGISTRATION') {
        _goTo(RegisterStep.phone);
        showAuth3dSnackBar(
          context,
          message: 'Please verify your number again.',
          isError: true,
        );
      } else if (e.code == 'PHONE_EXISTS') {
        await _handlePhoneExists(e.message);
      } else {
        _showApiError(e); // includes WEAK_PIN
      }
    } catch (_) {
      if (!mounted) return;
      showAuth3dSnackBar(
        context,
        message: 'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          RegisterStep.phone => _phoneStep(),
          RegisterStep.otp => _otpStep(),
          RegisterStep.setPin => _pinStep(),
        },
      ),
    );
  }

  Widget _phoneStep() {
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
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearError(),
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 10),
        const Text(
          'We will send a one-time code to verify this number.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        AuthErrorText(message: _error),
        SizedBox(height: sc.gap(28)),
        AuthButton(label: 'Send OTP', loading: _loading, onPressed: _sendOtp),
      ],
    );
  }

  Widget _otpStep() {
    return OtpVerification(
      dialCode: _country.dialCode,
      phone: _phoneCtrl.text.trim(),
      onVerify: _verifyOtp,
      onResend: _resendOtp,
      onChangeNumber: _changeNumber,
    );
  }

  Widget _pinStep() {
    final sc = AuthScale.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _verifiedChip(sc),
        SizedBox(height: sc.gap(24)),
        AuthPinLabel(
          label: 'Create a ${AuthConfig.pinLength}-digit PIN',
          visible: _showPin,
          onToggle: () => setState(() => _showPin = !_showPin),
        ),
        const SizedBox(height: 10),
        AuthPinput(
          controller: _pinCtrl,
          length: AuthConfig.pinLength,
          enabled: !_loading,
          obscure: !_showPin,
          onChanged: (_) => _clearError(),
        ),
        SizedBox(height: sc.gap(22)),
        const AuthLabel('Confirm PIN'),
        const SizedBox(height: 10),
        AuthPinput(
          controller: _confirmCtrl,
          length: AuthConfig.pinLength,
          enabled: !_loading,
          obscure: !_showPin,
          onChanged: (_) => _clearError(),
        ),
        AuthErrorText(message: _error),
        SizedBox(height: sc.gap(28)),
        AuthButton(
          label: 'Create Account',
          loading: _loading,
          onPressed: _createAccount,
        ),
      ],
    );
  }

  Widget _verifiedChip(AuthScale sc) {
    final phone = _phoneCtrl.text.trim();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: sc.size(12, min: 8),
      ),
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_country.dialCode} $phone verified',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}