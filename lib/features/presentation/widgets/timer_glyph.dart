import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/tracker.dart';

/// Line-art timer glyph, traced 1:1 from the suite mockups:
/// 108 viewport, stroke 7, round caps and joins, filled dots
/// where the mockup has them. The color comes from the caller —
/// the context decides (gray inactive, cyan active, blue picker).
class TimerGlyph extends StatelessWidget {
  const TimerGlyph({
    super.key,
    required this.id,
    required this.size,
    required this.color,
  });

  final TimerGlyphId id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TimerGlyphPainter(id: id, color: color),
    );
  }
}

class _TimerGlyphPainter extends CustomPainter {
  _TimerGlyphPainter({required this.id, required this.color});

  final TimerGlyphId id;
  final Color color;

  static const double _viewport = 108;
  static const double _stroke = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final (stroke, fill) = _pathsFor(id);
    final double scale = size.width / _viewport;

    canvas.save();
    canvas.scale(scale, scale);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(stroke, paint);

    if (fill != null) {
      canvas.drawPath(
        fill,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimerGlyphPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.color != color;

  static (Path, Path?) _pathsFor(TimerGlyphId id) {
    switch (id) {
      case TimerGlyphId.droplet:
        return (
          Path()
            ..moveTo(54, 20)
            ..cubicTo(63, 34, 72, 47, 72, 60)
            ..cubicTo(72, 71, 64, 79, 54, 79)
            ..cubicTo(44, 79, 36, 71, 36, 60)
            ..cubicTo(36, 47, 45, 34, 54, 20)
            ..close(),
          null,
        );

      case TimerGlyphId.flame:
        return (
          Path()
            ..moveTo(54, 22)
            ..cubicTo(58, 34, 70, 42, 72, 58)
            ..cubicTo(74, 73, 65, 86, 54, 86)
            ..cubicTo(43, 86, 34, 73, 36, 58)
            ..cubicTo(38, 42, 50, 34, 54, 22)
            ..close(),
          null,
        );

      case TimerGlyphId.wineGlass:
        return (
          Path()
            ..moveTo(38, 26)
            ..lineTo(70, 26)
            ..cubicTo(70, 46, 62, 54, 54, 54)
            ..cubicTo(46, 54, 38, 46, 38, 26)
            ..close()
            ..moveTo(54, 54)
            ..lineTo(54, 72)
            ..moveTo(42, 78)
            ..lineTo(66, 78),
          null,
        );

      case TimerGlyphId.cigarette:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(30, 50, 48, 14),
                const Radius.circular(7),
              ),
            )
            ..moveTo(62, 50)
            ..lineTo(62, 64)
            ..moveTo(70, 42)
            ..cubicTo(76, 34, 68, 30, 72, 22),
          null,
        );

      case TimerGlyphId.candy:
        return (
          Path()
            ..addOval(
              Rect.fromCircle(center: const Offset(54, 54), radius: 16),
            )
            ..moveTo(38, 54)
            ..lineTo(28, 46)
            ..lineTo(30, 60)
            ..close()
            ..moveTo(70, 54)
            ..lineTo(80, 46)
            ..lineTo(78, 60)
            ..close(),
          null,
        );

      case TimerGlyphId.coffee:
        return (
          Path()
            ..moveTo(36, 44)
            ..lineTo(70, 44)
            ..cubicTo(70, 60, 64, 68, 54, 68)
            ..cubicTo(44, 68, 38, 60, 38, 44)
            ..close()
            ..moveTo(70, 48)
            ..cubicTo(80, 48, 80, 62, 68, 62)
            ..moveTo(46, 30)
            ..cubicTo(46, 26, 50, 26, 50, 22)
            ..moveTo(58, 30)
            ..cubicTo(58, 26, 62, 26, 62, 22),
          null,
        );

      case TimerGlyphId.phone:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(40, 24, 28, 60),
                const Radius.circular(8),
              ),
            )
            ..moveTo(50, 72)
            ..lineTo(58, 72),
          null,
        );

      case TimerGlyphId.dice:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(34, 34, 40, 40),
                const Radius.circular(8),
              ),
            ),
          _dots(const [Offset(46, 46), Offset(54, 54), Offset(62, 62)]),
        );

      case TimerGlyphId.pill:
        final Path p = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(32, 44, 44, 20),
              const Radius.circular(10),
            ),
          )
          ..moveTo(54, 44)
          ..lineTo(54, 64);
        return (p.transform(_pillRotationMatrix().storage), null);

      case TimerGlyphId.burger:
        return (
          Path()
            ..moveTo(32, 50)
            ..cubicTo(32, 34, 76, 34, 76, 50)
            ..close()
            ..moveTo(32, 58)
            ..lineTo(76, 58)
            ..moveTo(36, 66)
            ..lineTo(72, 66),
          null,
        );

      case TimerGlyphId.tv:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(30, 36, 48, 32),
                const Radius.circular(5),
              ),
            )
            ..moveTo(46, 68)
            ..lineTo(46, 74)
            ..moveTo(62, 68)
            ..lineTo(62, 74)
            ..moveTo(38, 76)
            ..lineTo(70, 76),
          null,
        );

      case TimerGlyphId.gamepad:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(28, 44, 52, 26),
                const Radius.circular(13),
              ),
            )
            ..moveTo(42, 50)
            ..lineTo(42, 64)
            ..moveTo(35, 57)
            ..lineTo(49, 57),
          _dots(const [Offset(66, 52), Offset(72, 60)]),
        );

      case TimerGlyphId.shoppingBag:
        return (
          Path()
            ..moveTo(34, 46)
            ..lineTo(74, 46)
            ..lineTo(70, 78)
            ..lineTo(38, 78)
            ..close()
            ..moveTo(44, 46)
            ..cubicTo(44, 32, 64, 32, 64, 46),
          null,
        );

      case TimerGlyphId.dumbbell:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(30, 40, 10, 28),
                const Radius.circular(5),
              ),
            )
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(68, 40, 10, 28),
                const Radius.circular(5),
              ),
            )
            ..moveTo(40, 54)
            ..lineTo(68, 54),
          null,
        );

      case TimerGlyphId.cookie:
        return (
          Path()
            ..addOval(
              Rect.fromCircle(center: const Offset(54, 54), radius: 22),
            ),
          _dots(const [Offset(46, 48), Offset(60, 50), Offset(52, 62)]),
        );

      case TimerGlyphId.card:
        return (
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(30, 40, 48, 30),
                const Radius.circular(6),
              ),
            )
            ..moveTo(30, 52)
            ..lineTo(78, 52)
            ..moveTo(36, 62)
            ..lineTo(50, 62),
          null,
        );
    }
  }

  static Path _dots(List<Offset> centers) {
    final Path fill = Path();
    for (final Offset c in centers) {
      fill.addOval(Rect.fromCircle(center: c, radius: 2.5));
    }
    return fill;
  }

  static Matrix4 _pillRotationMatrix() {
    return Matrix4.identity()
      ..translateByDouble(54.0, 54.0, 0.0, 1.0)
      ..rotateZ(-math.pi / 4)
      ..translateByDouble(-54.0, -54.0, 0.0, 1.0);
  }
}
