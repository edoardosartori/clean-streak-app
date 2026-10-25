import 'package:flutter/material.dart';

import '../../models/tracker.dart';

/// Colors a scene needs, resolved by HeroSceneBackdrop from the
/// Fusion tokens: the sky from the "scene.*" section, every shape
/// from the "primitive.color.*" tokens. No color is hardcoded in
/// the painter.
class SceneColors {
  const SceneColors({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.ink,
    required this.slate950,
    required this.slate850,
    required this.slate700,
    required this.slate400,
    required this.slate100,
    required this.paper950,
    required this.paper600,
    required this.paper150,
    required this.white,
    required this.warmWhite,
    required this.blue500,
    required this.blue700,
    required this.cyan400,
    required this.amber400,
    required this.amber700,
    required this.green400,
    required this.green700,
  });

  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color ink;
  final Color slate950;
  final Color slate850;
  final Color slate700;
  final Color slate400;
  final Color slate100;
  final Color paper950;
  final Color paper600;
  final Color paper150;
  final Color white;
  final Color warmWhite;
  final Color blue500;
  final Color blue700;
  final Color cyan400;
  final Color amber400;
  final Color amber700;
  final Color green400;
  final Color green700;

  @override
  bool operator ==(Object other) =>
      other is SceneColors &&
      other.skyTop == skyTop &&
      other.skyMid == skyMid &&
      other.skyBottom == skyBottom &&
      other.ink == ink &&
      other.slate950 == slate950 &&
      other.slate850 == slate850 &&
      other.slate700 == slate700 &&
      other.slate400 == slate400 &&
      other.slate100 == slate100 &&
      other.paper950 == paper950 &&
      other.paper600 == paper600 &&
      other.paper150 == paper150 &&
      other.white == white &&
      other.warmWhite == warmWhite &&
      other.blue500 == blue500 &&
      other.blue700 == blue700 &&
      other.cyan400 == cyan400 &&
      other.amber400 == amber400 &&
      other.amber700 == amber700 &&
      other.green400 == green400 &&
      other.green700 == green700;

  @override
  int get hashCode => Object.hashAll([
        skyTop,
        skyMid,
        skyBottom,
        ink,
        slate950,
        slate850,
        slate700,
        slate400,
        slate100,
        paper950,
        paper600,
        paper150,
        white,
        warmWhite,
        blue500,
        blue700,
        cyan400,
        amber400,
        amber700,
        green400,
        green700,
      ]);
}

/// Paints the 8 hero card scenes, dark and light variants.
///
/// Same geometry as the v0.3.4 mockups in a 294x340 design space,
/// stretched onto the available size (the hero card uses the same
/// aspect). All colors arrive resolved from the tokens via
/// [SceneColors]; the 1s tick never repaints this layer because
/// shouldRepaint stays false while scene, theme and colors are
/// unchanged.
class ScenePainter extends CustomPainter {
  const ScenePainter({
    required this.scene,
    required this.brightness,
    required this.colors,
  });

  final HeroScene scene;
  final Brightness brightness;
  final SceneColors colors;

  static const double _w = 294;
  static const double _h = 340;

  // ------------------------------------------------------ geometry

  static Path _poly(List<Offset> pts) {
    final Path p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final Offset o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  static final Path _peaksBack = _poly(const [
    Offset(0, 234),
    Offset(58, 162),
    Offset(104, 220),
    Offset(148, 154),
    Offset(202, 228),
    Offset(294, 126),
    Offset(294, 340),
    Offset(0, 340),
  ]);
  static final Path _peaksFront = _poly(const [
    Offset(0, 268),
    Offset(70, 222),
    Offset(130, 262),
    Offset(190, 214),
    Offset(294, 268),
    Offset(294, 340),
    Offset(0, 340),
  ]);

  static final Path _oceanBack = Path()
    ..moveTo(0, 245)
    ..cubicTo(60, 219, 100, 255, 150, 233)
    ..cubicTo(200, 211, 250, 245, 294, 225)
    ..lineTo(294, 340)
    ..lineTo(0, 340)
    ..close();
  static final Path _oceanFront = Path()
    ..moveTo(0, 300)
    ..cubicTo(70, 280, 120, 304, 180, 290)
    ..cubicTo(230, 278, 270, 294, 294, 284)
    ..lineTo(294, 340)
    ..lineTo(0, 340)
    ..close();

  static final Path _forestTrees = Path()
    ..moveTo(36, 340)
    ..lineTo(36, 178)
    ..lineTo(64, 214)
    ..lineTo(64, 340)
    ..close()
    ..moveTo(116, 340)
    ..lineTo(116, 146)
    ..lineTo(152, 194)
    ..lineTo(152, 340)
    ..close()
    ..moveTo(204, 340)
    ..lineTo(204, 186)
    ..lineTo(232, 220)
    ..lineTo(232, 340)
    ..close();

  static const List<Rect> _cityBlocks = [
    Rect.fromLTRB(20, 180, 60, 340),
    Rect.fromLTRB(70, 128, 116, 340),
    Rect.fromLTRB(130, 205, 166, 340),
    Rect.fromLTRB(180, 90, 232, 340),
    Rect.fromLTRB(245, 166, 285, 340),
  ];
  static const List<Offset> _cityWindows = [
    Offset(86, 156),
    Offset(98, 182),
    Offset(198, 132),
    Offset(210, 166),
    Offset(222, 196),
  ];

  static final Path _desertBack = Path()
    ..moveTo(0, 240)
    ..cubicTo(60, 210, 120, 240, 180, 222)
    ..cubicTo(230, 210, 260, 228, 294, 216)
    ..lineTo(294, 340)
    ..lineTo(0, 340)
    ..close();
  static final Path _desertFront = Path()
    ..moveTo(0, 280)
    ..cubicTo(80, 262, 160, 278, 294, 262)
    ..lineTo(294, 340)
    ..lineTo(0, 340)
    ..close();

  static final Path _lakeMountain = _poly(const [
    Offset(0, 190),
    Offset(60, 148),
    Offset(120, 190),
    Offset(294, 154),
    Offset(294, 208),
    Offset(0, 208),
  ]);
  static const List<List<Offset>> _lakeRipples = [
    [Offset(80, 238), Offset(112, 238)],
    [Offset(132, 252), Offset(172, 252)],
    [Offset(190, 232), Offset(216, 232)],
  ];

  static final Path _snowBack = _poly(const [
    Offset(0, 340),
    Offset(74, 110),
    Offset(148, 340),
  ]);
  static final Path _snowBackCap = _poly(const [
    Offset(54, 148),
    Offset(74, 110),
    Offset(94, 148),
    Offset(74, 133),
  ]);
  static final Path _snowFront = _poly(const [
    Offset(120, 340),
    Offset(200, 155),
    Offset(294, 340),
  ]);
  static final Path _snowFrontCap = _poly(const [
    Offset(180, 195),
    Offset(200, 155),
    Offset(220, 195),
    Offset(200, 181),
  ]);

  static final Path _auroraRibbon1 = Path()
    ..moveTo(50, 30)
    ..cubicTo(70, 100, 70, 170, 60, 240);
  static final Path _auroraRibbon2 = Path()
    ..moveTo(110, 24)
    ..cubicTo(130, 94, 130, 164, 120, 234);
  static final Path _auroraRibbon3 = Path()
    ..moveTo(170, 32)
    ..cubicTo(190, 102, 190, 172, 180, 242);
  static final Path _auroraGround = _poly(const [
    Offset(0, 300),
    Offset(294, 300),
    Offset(294, 340),
    Offset(0, 340),
  ]);

  // ------------------------------------------------------ paint

  @override
  bool shouldRepaint(ScenePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.brightness != brightness ||
      oldDelegate.colors != colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    // Sky: the scene token palette over the whole card, three
    // stops like the mockups (device space).
    final Rect sky = Offset.zero & size;
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyTop, colors.skyMid, colors.skyBottom],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(sky),
    );

    // Scene: uniform scale anchored to the bottom edge. No
    // distortion: if the card is taller than the design space the
    // extra room is pure sky, if it is shorter the top of the
    // scene is cropped by the sky.
    final double s = size.width / _w;
    canvas.save();
    canvas.translate(0.0, size.height - _h * s);
    canvas.scale(s, s);

    switch (scene) {
      case HeroScene.peaks:
        _peaks(canvas);
        break;
      case HeroScene.ocean:
        _ocean(canvas);
        break;
      case HeroScene.forest:
        _forest(canvas);
        break;
      case HeroScene.city:
        _city(canvas);
        break;
      case HeroScene.desert:
        _desert(canvas);
        break;
      case HeroScene.lake:
        _lake(canvas);
        break;
      case HeroScene.snow:
        _snow(canvas);
        break;
      case HeroScene.aurora:
        _aurora(canvas);
        break;
    }

    canvas.restore();
  }

  // ------------------------------------------------------ scenes

  void _peaks(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _circle(canvas, const Offset(178, 56), 11, colors.blue500, alpha: 0.9);
      _fill(canvas, _peaksBack, colors.ink);
      _fill(canvas, _peaksFront, colors.slate950);
    } else {
      _circle(canvas, const Offset(178, 62), 14, colors.warmWhite);
      _fill(canvas, _peaksBack, colors.paper950);
      _fill(canvas, _peaksFront, colors.paper600);
    }
  }

  void _ocean(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _circle(canvas, const Offset(220, 75), 13, colors.slate100, alpha: 0.85);
      _fill(canvas, _oceanBack, colors.ink);
      _fill(canvas, _oceanFront, colors.slate850);
    } else {
      _circle(canvas, const Offset(220, 83), 18, colors.warmWhite);
      _fill(canvas, _oceanBack, colors.blue700);
      _fill(canvas, _oceanFront, colors.slate400);
    }
  }

  void _forest(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _fill(canvas, _forestTrees, colors.ink);
    } else {
      _circle(canvas, const Offset(230, 75), 16, colors.warmWhite);
      _fill(canvas, _forestTrees, colors.green700);
    }
  }

  void _city(Canvas canvas) {
    if (brightness == Brightness.dark) {
      for (int i = 0; i < _cityBlocks.length; i++) {
        _fillRect(
            canvas, _cityBlocks[i], i.isEven ? colors.ink : colors.slate950);
      }
      _circle(canvas, _cityWindows[0], 3, colors.blue500);
      _circle(canvas, _cityWindows[1], 3, colors.blue500);
      _circle(canvas, _cityWindows[2], 3, colors.cyan400);
      _circle(canvas, _cityWindows[3], 3, colors.blue500);
      _circle(canvas, _cityWindows[4], 3, colors.blue500);
    } else {
      _circle(canvas, const Offset(228, 87), 17, colors.amber400);
      for (int i = 0; i < _cityBlocks.length; i++) {
        _fillRect(canvas, _cityBlocks[i],
            i.isEven ? colors.paper600 : colors.paper950);
      }
    }
  }

  void _desert(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _fill(canvas, _desertBack, colors.ink);
      _fill(canvas, _desertFront, colors.paper950);
    } else {
      _circle(canvas, const Offset(220, 90), 18, colors.warmWhite);
      _fill(canvas, _desertBack, colors.amber700);
      _fill(canvas, _desertFront, colors.paper950);
    }
  }

  void _lake(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _circle(canvas, const Offset(90, 90), 16, colors.slate100, alpha: 0.85);
      _fill(canvas, _lakeMountain, colors.ink);
      _line(canvas, const Offset(0, 208), const Offset(294, 208),
          colors.slate700, 3, 1);
      for (final List<Offset> r in _lakeRipples) {
        _line(canvas, r[0], r[1], colors.blue500, 3, 0.7);
      }
    } else {
      _circle(canvas, const Offset(90, 90), 18, colors.warmWhite);
      _fill(canvas, _lakeMountain, colors.paper600);
      _line(canvas, const Offset(0, 208), const Offset(294, 208),
          colors.slate400, 3, 1);
      for (final List<Offset> r in _lakeRipples) {
        _line(canvas, r[0], r[1], colors.blue700, 3, 0.6);
      }
    }
  }

  void _snow(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _circle(canvas, const Offset(230, 68), 12, colors.slate100, alpha: 0.7);
      _fill(canvas, _snowBack, colors.slate700);
      _fill(canvas, _snowBackCap, colors.slate100);
      _fill(canvas, _snowFront, colors.slate850);
      _fill(canvas, _snowFrontCap, colors.slate400);
    } else {
      _circle(canvas, const Offset(230, 72), 17, colors.warmWhite);
      _fill(canvas, _snowBack, colors.paper600);
      _fill(canvas, _snowBackCap, colors.white);
      _fill(canvas, _snowFront, colors.slate400);
      _fill(canvas, _snowFrontCap, colors.slate100);
    }
  }

  void _aurora(Canvas canvas) {
    if (brightness == Brightness.dark) {
      _stroke(canvas, _auroraRibbon1, colors.cyan400, 14, 0.35);
      _stroke(canvas, _auroraRibbon2, colors.green400, 14, 0.30);
      _stroke(canvas, _auroraRibbon3, colors.blue500, 14, 0.35);
      _fill(canvas, _auroraGround, colors.slate950);
    } else {
      _stroke(canvas, _auroraRibbon1, colors.blue500, 14, 0.20);
      _stroke(canvas, _auroraRibbon2, colors.cyan400, 14, 0.18);
      _stroke(canvas, _auroraRibbon3, colors.green400, 14, 0.18);
      _circle(canvas, const Offset(228, 76), 16, colors.amber400);
      _fill(canvas, _auroraGround, colors.paper150);
    }
  }

  // ------------------------------------------------------ helpers

  void _fill(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
  }

  void _fillRect(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  void _circle(Canvas canvas, Offset center, double radius, Color color,
      {double alpha = 1.0}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = alpha >= 1.0 ? color : color.withValues(alpha: alpha),
    );
  }

  void _stroke(
      Canvas canvas, Path path, Color color, double width, double alpha) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color, double width,
      double alpha) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }
}
