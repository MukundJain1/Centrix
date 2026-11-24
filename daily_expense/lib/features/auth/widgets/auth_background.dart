import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import 'auth_scale.dart';

/// Glowing background + keyboard-aware, scrollable, width-limited content.
///
/// Use it as the body of a Scaffold with `resizeToAvoidBottomInset: false`.
/// This widget lifts the content above the keyboard itself, keeps it inside
/// the safe area (so it never goes under the status bar), and centres it when
/// there is spare room.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.contentAlignment = Alignment.center,
  });

  final Widget child;

  /// Where the content sits when there is spare vertical room.
  /// Alignment(0, -0.3) sits a little above the middle.
  final Alignment contentAlignment;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sc = AuthScale.of(context);
    final hPad = mq.size.width < 360 ? 16.0 : 24.0;
    final vPad = sc.gap(24);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(top: -80, right: -60, child: _glow(280, 0.18)),
        Positioned(bottom: -100, left: -80, child: _glow(260, 0.10)),
        Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SafeArea(
            bottom: !sc.keyboardOpen,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - vPad * 2),
                    ),
                    child: Align(
                      alignment: contentAlignment,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _glow(double size, double alpha) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primaryAccent.withValues(alpha: alpha),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}