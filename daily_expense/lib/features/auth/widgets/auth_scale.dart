import 'package:flutter/widgets.dart';

/// Responsive helper for the auth screens.
///
/// Spacing and sizes shrink on short screens, and shrink further while the
/// keyboard is open, so the whole form stays visible.
class AuthScale {
  const AuthScale._(this.keyboardOpen, this._factor);

  factory AuthScale.of(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    var factor = (height / 800).clamp(0.72, 1.0).toDouble();
    if (keyboardOpen) factor *= 0.8;
    return AuthScale._(keyboardOpen, factor);
  }

  final bool keyboardOpen;
  final double _factor;

  /// Scaled spacing.
  double gap(double value) => value * _factor;

  /// Scaled size that never goes below [min].
  double size(double value, {double min = 0}) {
    final scaled = value * _factor;
    return scaled < min ? min : scaled;
  }
}
