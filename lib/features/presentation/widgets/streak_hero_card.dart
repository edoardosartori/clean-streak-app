import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/milestone_engine.dart';
import '../../domain/streak_calculator.dart';
import '../../models/tracker.dart';
import 'timer_glyph.dart';

/// Hero card of a timer: scene backdrop, "Clean for" calendar
/// counter (Y/M/D + h/m/s), milestone in focus with progress.
class StreakHeroCard extends StatelessWidget {
  const StreakHeroCard({
    super.key,
    required this.tracker,
    required this.onReset,
  });

  final Tracker tracker;
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

    // Big digits: blue in dark, white in light (mockup).
    final Color digitColor = isDark ? theme.colorScheme.primary : Colors.white;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TimerGlyph(
                        id: tracker.glyph,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
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
                      _ResetButton(onTap: onReset),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clean for',
                    style: TextStyle(fontSize: 13, color: secondary),
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
                    labelColor: ext.characterSymbol,
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
                                _capitalize(snapshot.current!.definition.label),
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

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});

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
        onPressed: onTap,
        icon: Icon(
          Icons.refresh_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

/// Scene backdrop of the hero card.
///
/// STEP 3A PLACEHOLDER: per-scene gradient read from the Fusion
/// tokens ("scene.<name>.<dark|light>.sky*"). The real bundle (8
/// scenes x dark/light bitmaps) will replace the build of this
/// widget with an Image.asset — nothing else in the card changes.
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
    final String prefix =
        'scene.${scene.name}.${brightness == Brightness.dark ? 'dark' : 'light'}';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens.color('$prefix.skyTop'),
            tokens.color('$prefix.skyMid'),
            tokens.color('$prefix.skyBottom'),
          ],
        ),
      ),
    );
  }
}
