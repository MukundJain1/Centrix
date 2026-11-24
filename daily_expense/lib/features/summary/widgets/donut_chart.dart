import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class DonutSlice {
  const DonutSlice(this.value, this.color);

  final double value;
  final Color color;
}

/// Ring chart with a label in the middle. Drawn with a CustomPainter, so it
/// needs no extra package.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerTop,
    required this.centerBottom,
    this.size = 190,
  });

  final List<DonutSlice> slices;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(slices),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTop,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerBottom,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  final List<DonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    // Faint full ring behind the slices.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    const gap = 0.04; // radians between slices
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2;
      if (sweep <= 0) continue;

      final drawn = sweep > gap * 2 ? sweep - gap : sweep;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = s.color;
      canvas.drawArc(rect, start + (sweep - drawn) / 2, drawn, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    if (old.slices.length != slices.length) return true;
    for (var i = 0; i < slices.length; i++) {
      if (old.slices[i].value != slices[i].value ||
          old.slices[i].color != slices[i].color) {
        return true;
      }
    }
    return false;
  }
}
