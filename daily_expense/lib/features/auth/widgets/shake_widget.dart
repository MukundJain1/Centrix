import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wiggles its child sideways. Use a GlobalKey and call `shake()`:
///
///   final _shake = GlobalKey<ShakeWidgetState>();
///   ShakeWidget(key: _shake, child: ...);
///   _shake.currentState?.shake();
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.child});

  final Widget child;

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  void shake() => _controller.forward(from: 0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final dx = math.sin(_controller.value * 3 * 2 * math.pi) *
            10 *
            (1 - _controller.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
