// FILE (SOSTITUISCE): lib/features/presentation/widgets/streak_hero_card.dart

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/milestone_engine.dart';
import '../../domain/streak_calculator.dart';
import '../../models/tracker.dart';
import 'scene_painter.dart';
import 'timer_glyph.dart';

/// Hero card of a timer: scene backdrop, "Clean for" calendar
/// counter (Y/M/D + h/m/s), milestone in focus with progress.
/// The header row carries the two compact actions: edit (opens
/// the tracker editor, which in edit mode also offers delete)
/// and reset.
///
/// The counter block sits on a frosted panel (ink at 45% plus the
/// dialog scrim blur, both from fusion-tokens.json) so the data
/// stays readable over the brightest scenes, in both themes.
/// The panel is pinned under the header, so the scene highlights
/// stay visible in the middle of the card.
class StreakHeroCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final StreakBreakdown breakdown =
        StreakCalculator().breakdown(tracker.startAt);
    final MilestoneSnapshot snapshot = MilestoneEngine().snapshot(
      startAt: tracker.startAt,
      disabledMilestones: tracker.disabledMilestones,
    );

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

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: HeroSceneBackdrop(
                scene: tracker.scene,
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
                        if (tracker.glyph != null) ...[
                          TimerGlyph(
                            id: tracker.glyph!,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: tracker.name == null
                              ? const SizedBox.shrink()
                              : Text(
                                  tracker.name!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        _HeaderButton(
                          icon: Icons.edit_rounded,
                          tooltip: 'Edit timer',
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 8),
                        _HeaderButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Reset timer',
                          onTap: onReset,
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
                                Text(
                                  'Clean for',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _digitsRow(
                                  items: [
                                    (_twoDigits(breakdown.years), 'Y'),
                                    (_twoDigits(breakdown.months), 'M'),
                                    (_twoDigits(breakdown.days), 'D'),
                                  ],
                                  valueSize: 34,
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
                                  valueSize: 19,
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
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(height: 12),
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
                            child: TimerGlyph(
                              id: TimerGlyphId.droplet,
                              size: 20,
                              color: ext.stateActive,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                if (snapshot.next != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Next milestone: ${snapshot.next!.definition.label}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${(snapshot.current!.progress * 100).round()}%',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 14,
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
                                    snapshot.current!.progress.clamp(0.0, 1.0),
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
                    fontSize: 12,
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
}

/// Compact 36x36 action button of the hero header: frosted white
/// tile, white icon. Used for the edit and the reset actions.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: 0.92),
        ),
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
