import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../onboarding/cycle_setup_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/app_settings.dart';
import '../../core/theme/colors.dart';
import 'data/auth_models.dart';
import 'login_form.dart';
import 'register_flow.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_mode_toggle.dart';
import 'widgets/auth_scale.dart';

/// Shell for authentication: header, Sign In / Register toggle, and the
/// active form. The forms themselves live in login_form.dart and
/// register_flow.dart.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _registerController = RegisterFlowController();

  bool _isLogin = true;
  RegisterStep _step = RegisterStep.phone;

  /// The back arrow shows on the OTP and Set PIN steps.
  bool get _showBackArrow => !_isLogin && _step != RegisterStep.phone;

  void _setMode(bool login) {
    if (_isLogin == login) return;
    setState(() {
      _isLogin = login;
      _step = RegisterStep.phone;
    });
  }

  /// Used by both the back arrow and the phone's back button.
  /// Steps back inside Register; from the first Register step it returns
  /// to Sign In.
  void _handleBack() {
    if (_registerController.goBack()) return;
    _setMode(true);
  }

  /// After Sign In or Register, the server's profile says what is left:
  /// Financial Baseline -> payday cycle -> Dashboard.
  void _routeAfterAuth(MeModel me) {
    AppSettings.instance.setCurrency(me.currency);

    final Widget next;
    if (!me.baselineDone) {
      next = const OnboardingScreen();
    } else if (!me.cycleDone) {
      next = CycleSetupScreen(
        monthlySurplus: me.monthlySurplus ?? 0,
        currency: me.currency,
      );
    } else {
      next = DashboardScreen(dailyBudgetLimit: me.dailyLimit ?? 0);
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  String get _title {
    if (_isLogin) return 'Welcome back';
    switch (_step) {
      case RegisterStep.phone:
        return 'Create your account';
      case RegisterStep.otp:
        return 'Verify your number';
      case RegisterStep.setPin:
        return 'Set your PIN';
    }
  }

  String get _subtitle {
    if (_isLogin) return 'Enter your number and PIN to unlock';
    switch (_step) {
      case RegisterStep.phone:
        return 'Enter your mobile number to get started';
      case RegisterStep.otp:
        return 'Enter the code we sent you';
      case RegisterStep.setPin:
        return 'Choose a PIN you will remember';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);
    final showToggle = _isLogin || _step == RegisterStep.phone;

    // Back arrow: near the top of the screen (inside the safe area), level
    // with the left edge of the form.
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 16.0 : 24.0;
    final contentWidth = math.min(420.0, width - hPad * 2);
    final backLeft = (width - contentWidth) / 2;
    final backTop = MediaQuery.paddingOf(context).top + 8;

    return PopScope(
      // On Sign In the phone's back button leaves the app as usual.
      // On Register it steps back instead.
      canPop: _isLogin,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        // AuthBackground lifts the content above the keyboard itself.
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AuthBackground(
              // Sit a little above the middle so the space is used better.
              contentAlignment: const Alignment(0, -0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(title: _title, subtitle: _subtitle),
                  SizedBox(height: sc.gap(32)),
                  if (showToggle) ...[
                    AuthModeToggle(isLogin: _isLogin, onChanged: _setMode),
                    SizedBox(height: sc.gap(28)),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isLogin
                        ? LoginForm(
                            key: const ValueKey('login'),
                            onSuccess: _routeAfterAuth,
                          )
                        : RegisterFlow(
                            key: const ValueKey('register'),
                            controller: _registerController,
                            onStepChanged: (s) => setState(() => _step = s),
                            onRegistered: _routeAfterAuth,
                            onSwitchToLogin: () => _setMode(true),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: backTop,
              left: backLeft,
              child: AnimatedOpacity(
                opacity: _showBackArrow ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showBackArrow,
                  child: AuthBackButton(onPressed: _handleBack),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
