import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Dashed rounded-rect stroke, mockup v0.3.4 style (the "+" tab
/// and the switched-off milestone chips). Flutter has no built-in
/// dashed borders, so this walks the rounded-rect path with
/// PathMetrics and draws alternating dashes.
class DashedRoundedRectPainter extends CustomPainter {
  const DashedRoundedRectPainter({
    required this.color,
    this.radius = 12,
    this.strokeWidth = 1,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double next = math.min(
          distance + (draw ? dashLength : gapLength),
          metric.length,
        );
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
