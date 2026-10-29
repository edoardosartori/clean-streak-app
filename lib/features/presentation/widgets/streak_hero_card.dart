// FILE (SOSTITUISCE): lib/features/presentation/widgets/streak_hero_card.dart

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/fusion_motion.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/history_stats.dart';
import '../../domain/milestone_catalog.dart';
import '../../domain/milestone_engine.dart';
import '../../domain/streak_calculator.dart';
import '../../models/tracker.dart';
import 'history_chart.dart';
import 'scene_painter.dart';
import 'timer_glyph.dart';

/// Hero card of a timer: scene backdrop, calendar counter
/// (Y/M/D + h/m/s), milestone in focus with progress.
/// The header row carries the two compact actions: edit (opens
/// the tracker editor, which in edit mode also offers delete)
/// and reset.
///
/// History step — the flip: tapping the card body flips it 180
/// on the Y axis. The back is the streak history: the sawtooth
/// line chart (computeHistorySeries) plus the three aggregate
/// stats (computeHistoryStats). The flip is EPHEMERAL by
/// decision: the angle lives in this State, so swiping away in
/// the PageView disposes it and a fresh page always starts from
/// the front.
///
/// The counter block sits on a frosted panel (ink at 45% plus the
/// dialog scrim blur, both from fusion-tokens.json) so the data
/// stays readable over the brightest scenes, in both themes.
/// The panel is pinned under the header, so the scene highlights
/// stay visible in the middle of the card.
class StreakHeroCard extends StatefulWidget {
  const StreakHeroCard({
    super.key,
    required this.tracker,
    required this.onEdit,
    required this.onReset,
  });

  final Tracker tracker;

  /// Opens the tracker editor on this timer. The editor runs in
  /// edit mode, so it also shows the "Delete timer" action.
  final VoidCallback onEdit;

  /// Resets the streak (the caller asks for confirmation first).
  final VoidCallback onReset;

  @override
  State<StreakHeroCard> createState() => _StreakHeroCardState();
}

class _StreakHeroCardState extends State<StreakHeroCard>
    with SingleTickerProviderStateMixin {
  /// 0 = front, 1 = fully flipped. Suite motion token for the
  /// duration; the rotation itself is linear (constant angular
  /// speed is what a physical flip looks like).
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: FusionMotion.normal,
  );

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  /// Tapping the card body flips it (decision). The header
  /// buttons win the gesture arena over the body tap, so they
  /// keep working untouched. A tap mid-animation is ignored
  /// instead of re-targeting, so a flip always completes.
  void _toggleFlip() {
    if (_flip.isAnimating) {
      return;
    }
    if (_flip.isCompleted) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Widget frontFace = _buildFrontFace(context);
    final Widget backFace = _buildBackFace(context);

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  // effect.elevation.light, same as the Fusion dialogs.
                  BoxShadow(
                    color: const Color(0xFF12161B).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: AnimatedBuilder(
          animation: _flip,
          builder: (BuildContext context, Widget? child) {
            final double angle = _flip.value * math.pi;
            // Past 90 degrees the back face becomes the visible
            // one; mirroring the angle keeps the rotation
            // continuous instead of bouncing at the halfway point.
            final bool back = _flip.value >= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(back ? angle - math.pi : angle),
              // The clip travels WITH the card: rounding the
              // corners inside the transform keeps them round
              // at every angle, instead of an axis-aligned
              // rectangle over a rotating card.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: back ? backFace : frontFace,
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // FRONT: the live streak, unchanged (scene + counter + milestone).
  // ------------------------------------------------------------------

  Widget _buildFrontFace(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final StreakBreakdown breakdown =
        StreakCalculator().breakdown(widget.tracker.startAt);
    final MilestoneSnapshot snapshot = MilestoneEngine().snapshot(
      startAt: widget.tracker.startAt,
      disabledMilestones: widget.tracker.disabledMilestones,
    );

    // The bar never shows 100%: near the milestone the progress
    // ROUNDS UP to "100%" seconds before it actually fires, so
    // anything from 99% up is clamped to 99 (user rule).
    final double shownProgress =
        (snapshot.current?.progress ?? 0.0).clamp(0.0, 0.99);

    // Content over the image is always white (mockup decision): both
    // themes draw a dark scrim over the scene. Gray sub-labels use the
    // dark semantic textSecondary, which reads well on the scrim.
    final Color secondary = tokens.color('semantic.dark.textSecondary');

    // Y/M/D labels: amber 400 in BOTH themes (mockup .dlab). The light
    // theme's characterSymbol (amber 700) is too dark over the scene.
    final Color ymdLabel = tokens.color('primitive.color.amber.400');

    // Big digits: blue in dark, white in light (mockup).
    final Color digitColor = isDark ? theme.colorScheme.primary : Colors.white;

    // Frosted panel behind the counter: same recipe as the Fusion
    // dialogs (ink scrim + blur), straight from the tokens.
    final Color panelScrim = tokens.color('primitive.color.inkA45');
    final double panelBlur = tokens.dimension('component.dialog.scrimBlur');

    return Stack(
      children: [
        Positioned.fill(
          child: HeroSceneBackdrop(
            scene: widget.tracker.scene,
            brightness: theme.brightness,
          ),
        ),
        // Dark scrim over the scene: stronger in dark (mockup).
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: isDark ? 0.40 : 0.30),
                  Colors.black.withValues(alpha: isDark ? 0.76 : 0.60),
                ],
              ),
            ),
          ),
        ),
        // Content fills the card height: the Spacer pushes the
        // milestone block to the bottom, the scene owns the middle.
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Optional glyph: a timer without an icon
                    // shows the name only (never a placeholder).
                    if (widget.tracker.glyph != null) ...[
                      TimerGlyph(
                        id: widget.tracker.glyph!,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: widget.tracker.name == null
                          ? const SizedBox.shrink()
                          : Text(
                              widget.tracker.name!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    _HeaderButton(
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit timer',
                      tileColor: Colors.white.withValues(alpha: 0.14),
                      iconColor: Colors.white.withValues(alpha: 0.92),
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 8),
                    _HeaderButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Reset timer',
                      tileColor: Colors.white.withValues(alpha: 0.14),
                      iconColor: Colors.white.withValues(alpha: 0.92),
                      onTap: widget.onReset,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Frosted data panel PINNED UNDER THE HEADER: the
                // counter stays in the top part of the card, and
                // the scene highlights (sun, peaks, rooftops) show
                // in the free space above the milestone block.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: panelBlur,
                      sigmaY: panelBlur,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: panelScrim,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _digitsRow(
                              items: [
                                (_twoDigits(breakdown.years), 'Y'),
                                (_twoDigits(breakdown.months), 'M'),
                                (_twoDigits(breakdown.days), 'D'),
                              ],
                              valueSize: 35,
                              valueColor: digitColor,
                              labelColor: ymdLabel,
                            ),
                            const SizedBox(height: 10),
                            _digitsRow(
                              items: [
                                (_twoDigits(breakdown.hours), 'h'),
                                (_twoDigits(breakdown.minutes), 'm'),
                                (_twoDigits(breakdown.seconds), 's'),
                              ],
                              valueSize: 20,
                              valueColor: Colors.white,
                              labelColor: secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                if (snapshot.current != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ext.stateActiveTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _compact(snapshot.current!.definition),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ext.stateActive,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _capitalize(
                                  snapshot.current!.definition.label),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(shownProgress * 100).round()}%',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 15,
                          color: digitColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor:
                                shownProgress.clamp(0.0, 1.0),
                            child: SizedBox.expand(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: ext.stateActive,
                                  // Cyan glow in dark only (mockup).
                                  boxShadow: isDark
                                      ? [
                                          BoxShadow(
                                            color: ext.stateActive
                                                .withValues(alpha: 0.25),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // BACK: the streak history — line chart + aggregate stats.
  // ------------------------------------------------------------------

  Widget _buildBackFace(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    // Same header as the front (decision: identical row), but
    // the frosted-white button recipe would vanish on the light
    // surface, so the tiles go theme-aware here: frosted white
    // in dark, soft ink tile in light. Same geometry, same role.
    final Color headerTile = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.06);
    final Color headerIcon = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : theme.colorScheme.onSurface;

    // One clock for chart and stats, so they can never disagree.
    final DateTime now = DateTime.now();
    final HistoryStats stats = computeHistoryStats(
      history: widget.tracker.history,
      currentStartAt: widget.tracker.startAt,
      now: now,
    );
    final List<HistorySample> series = computeHistorySeries(
      history: widget.tracker.history,
      currentStartAt: widget.tracker.startAt,
      now: now,
    );

    return ColoredBox(
      // Plain Fusion card surface: the scene belongs to the front.
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.tracker.glyph != null) ...[
                  TimerGlyph(
                    id: widget.tracker.glyph!,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: widget.tracker.name == null
                      ? const SizedBox.shrink()
                      : Text(
                          widget.tracker.name!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                ),
                _HeaderButton(
                  icon: Icons.edit_rounded,
                  tooltip: 'Edit timer',
                  tileColor: headerTile,
                  iconColor: headerIcon,
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: 8),
                _HeaderButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Reset timer',
                  tileColor: headerTile,
                  iconColor: headerIcon,
                  onTap: widget.onReset,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Streak history',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                // Quiet echo of the flip affordance: the whole
                // body is the tap target, the icon only hints it.
                Icon(Icons.flip, size: 18, color: secondary),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreakHistoryChart(series: series),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _HistoryStat(
                  value: '${stats.bestRunDays}',
                  label: 'Best run',
                ),
                _HistoryStat(
                  value: '${stats.totalCleanDays}',
                  label: 'Clean days',
                ),
                _HistoryStat(
                  value: '${stats.resetCount}',
                  label: 'Resets',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _digitsRow({
    required List<(String, String)> items,
    required double valueSize,
    required Color valueColor,
    required Color labelColor,
  }) {
    return Row(
      children: [
        for (final (value, label) in items)
          Expanded(
            child: Column(
              children: [
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: valueSize,
                    fontWeight: FontWeight.w400,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Compact badge label: "1D", "14D", "1M", "1Y" — the mono
  /// number-in-badge replaces the old droplet-for-all.
  static String _compact(MilestoneDefinition def) {
    if (def.days > 0) return '${def.days}D';
    if (def.months % 12 == 0) return '${def.months ~/ 12}Y';
    return '${def.months}M';
  }
}

/// One aggregate of the stats row: mono value on top, secondary
/// label below (numbers are always JetBrains Mono in the suite).
class _HistoryStat extends StatelessWidget {
  const _HistoryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Compact 40x40 action button of the hero header. The front uses
/// the frosted-white pair over the scene scrim; the back passes a
/// theme-aware pair, because frosted white would be invisible on
/// the light card surface.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.tileColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color tileColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

/// Scene backdrop of the hero card.
///
/// Draws the 8 scenes with a CustomPainter: the sky comes from the
/// "scene.*" Fusion tokens and every shape color from the
/// "primitive.color.*" tokens, so the palette always follows
/// fusion-tokens.json (no baked-in bitmaps). The painter never
/// repaints on the 1s tick: shouldRepaint is false unless scene,
/// theme or token colors change.
class HeroSceneBackdrop extends StatelessWidget {
  const HeroSceneBackdrop({
    super.key,
    required this.scene,
    required this.brightness,
  });

  final HeroScene scene;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final tokens = FusionTokensScope.of(context);
    final bool isDark = brightness == Brightness.dark;
    final String prefix = 'scene.${scene.name}.${isDark ? 'dark' : 'light'}';

    return CustomPaint(
      painter: ScenePainter(
        scene: scene,
        brightness: brightness,
        colors: SceneColors(
          skyTop: tokens.color('$prefix.skyTop'),
          skyMid: tokens.color('$prefix.skyMid'),
          skyBottom: tokens.color('$prefix.skyBottom'),
          ink: tokens.color('primitive.color.ink'),
          slate950: tokens.color('primitive.color.slate.950'),
          slate850: tokens.color('primitive.color.slate.850'),
          slate700: tokens.color('primitive.color.slate.700'),
          slate400: tokens.color('primitive.color.slate.400'),
          slate100: tokens.color('primitive.color.slate.100'),
          paper950: tokens.color('primitive.color.paper.950'),
          paper600: tokens.color('primitive.color.paper.600'),
          paper150: tokens.color('primitive.color.paper.150'),
          white: tokens.color('primitive.color.white'),
          warmWhite: tokens.color('primitive.color.warmWhite'),
          blue500: tokens.color('primitive.color.blue.500'),
          blue700: tokens.color('primitive.color.blue.700'),
          cyan400: tokens.color('primitive.color.cyan.400'),
          amber400: tokens.color('primitive.color.amber.400'),
          amber700: tokens.color('primitive.color.amber.700'),
          green400: tokens.color('primitive.color.green.400'),
          green700: tokens.color('primitive.color.green.700'),
        ),
      ),
    );
  }
}
