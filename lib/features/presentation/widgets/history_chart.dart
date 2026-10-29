// FILE (NUOVO): lib/features/presentation/widgets/history_chart.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/history_stats.dart';

/// Line chart of the streak history (history step): the sawtooth
/// day by day — every streak climbs from zero, drops to zero where
/// it closed and climbs again, and the live streak climbs to now.
///
/// Pure drawing: the series comes from computeHistorySeries, the
/// palette from the Fusion tokens. The chart line is the ONE
/// active element of the screen (suite rule): stateActive line,
/// stateActiveTint fill, glow in dark only.
///
/// The painter never repaints on the 1s tick: samples are
/// compared day by day, and within a day the line would only move
/// by a fraction of a pixel (the "now" point is pinned to the
/// right edge regardless of the time of day).
class StreakHistoryChart extends StatelessWidget {
  const StreakHistoryChart({super.key, required this.series});

  /// Chronological samples, straight from computeHistorySeries.
  final List<HistorySample> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return CustomPaint(
      painter: HistoryChartPainter(
        series: series,
        lineColor: ext.stateActive,
        fillColor: ext.stateActiveTint,
        gridColor: isDark
            ? ext.border
            : const Color(0xFF12161B).withValues(alpha: 0.08),
        labelColor: secondary,
        glow: isDark,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Draws the history line: three gridlines (zero, half, top), the
/// Y labels in JetBrains Mono, the first date and "Now" on the X
/// axis, the tinted fill under the line and the stateActive line
/// on top (with a soft cyan glow in dark).
class HistoryChartPainter extends CustomPainter {
  HistoryChartPainter({
    required this.series,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.glow,
  });

  final List<HistorySample> series;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  final bool glow;

  /// Drawing area insets: Y labels on the left, X labels below.
  static const double _leftInset = 26;
  static const double _rightInset = 4;
  static const double _topInset = 6;
  static const double _bottomInset = 18;

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Milestone-flavored ceiling for the Y axis, so the top
  /// gridline is always a "known" number: 1, 3, 7, 14, 30, 90,
  /// 180, 365, then whole years.
  static int _niceCeil(double days) {
    final int v = days.ceil();
    if (v <= 1) return 1;
    if (v <= 3) return 3;
    if (v <= 7) return 7;
    if (v <= 14) return 14;
    if (v <= 30) return 30;
    if (v <= 90) return 90;
    if (v <= 180) return 180;
    if (v <= 365) return 365;
    return (v + 364) ~/ 365 * 365;
  }

  static String _shortDate(DateTime at) => '${_months[at.month - 1]} ${at.day}';

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2 || size.width < 60 || size.height < 40) {
      return;
    }

    final Rect area = Rect.fromLTRB(
      _leftInset,
      _topInset,
      size.width - _rightInset,
      size.height - _bottomInset,
    );

    double maxDays = 0;
    for (final HistorySample sample in series) {
      if (sample.daysClean > maxDays) {
        maxDays = sample.daysClean;
      }
    }
    final int yMax = _niceCeil(maxDays);

    final DateTime firstAt = series.first.at;
    final int firstMs = firstAt.millisecondsSinceEpoch;
    final int spanMs = math.max(
      1,
      series.last.at.millisecondsSinceEpoch - firstMs,
    );

    double xOf(DateTime at) =>
        area.left + (at.millisecondsSinceEpoch - firstMs) / spanMs * area.width;
    double yOf(double days) => area.bottom - days / yMax * area.height;

    // Grid: baseline, half, top.
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final double value in <double>[0, yMax / 2, yMax.toDouble()]) {
      final double y = yOf(value);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
    }
    _label(canvas, '0', area.left - 4, yOf(0), alignRight: true);
    _label(canvas, '$yMax', area.left - 4, yOf(yMax.toDouble()),
        alignRight: true);
    // Half gridline label only when it is a whole number of days.
    if (yMax % 2 == 0) {
      _label(canvas, '${yMax ~/ 2}', area.left - 4, yOf(yMax / 2),
          alignRight: true);
    }

    // The line and the fill under it, sample by sample.
    final Path line = Path()
      ..moveTo(xOf(series.first.at), yOf(series.first.daysClean));
    final Path fill = Path()..moveTo(xOf(series.first.at), area.bottom);
    for (final HistorySample sample in series) {
      final Offset point = Offset(xOf(sample.at), yOf(sample.daysClean));
      line.lineTo(point.dx, point.dy);
      fill.lineTo(point.dx, point.dy);
    }
    fill.lineTo(xOf(series.last.at), area.bottom);
    fill.close();

    canvas.drawPath(fill, Paint()..color = fillColor);

    final Paint stroke = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Cyan glow in dark only (same rule as the milestone bar).
    if (glow) {
      final Paint glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(line, glowPaint);
    }
    canvas.drawPath(line, stroke);

    // X axis: first date on the left, "Now" pinned to the right.
    _label(canvas, _shortDate(series.first.at), area.left, area.bottom + 10);
    _label(canvas, 'Now', area.right, area.bottom + 10, alignRight: true);
  }

  /// One small JetBrains Mono label; [y] is the vertical CENTER of
  /// the text, [alignRight] anchors it to the right edge of [x].
  void _label(
    Canvas canvas,
    String text,
    double x,
    double y, {
    bool alignRight = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double left = alignRight ? x - painter.width : x;
    final double top =
        (y - painter.height / 2).clamp(0.0, double.infinity).toDouble();
    painter.paint(canvas, Offset(left, top));
  }

  @override
  bool shouldRepaint(covariant HistoryChartPainter oldDelegate) {
    if (oldDelegate.glow != glow ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.series.length != series.length) {
      return true;
    }
    // Day-level comparison: within the same day the tick moves
    // nothing (see the class docs), so the chart stays still.
    for (int i = 0; i < series.length; i++) {
      final HistorySample a = oldDelegate.series[i];
      final HistorySample b = series[i];
      if (a.daysClean != b.daysClean ||
          a.at.year != b.at.year ||
          a.at.month != b.at.month ||
          a.at.day != b.at.day) {
        return true;
      }
    }
    return false;
  }
}
