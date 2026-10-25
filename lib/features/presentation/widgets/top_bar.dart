import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../models/tracker.dart';
import '../state/app_state.dart';
import '../state/tracker_controller.dart';
import 'dashed_border.dart';
import 'timer_glyph.dart';

/// Top bar of the home: the timer tabs (tap or swipe), the "+"
/// tab that opens the editor and the theme toggle.
///
/// Long-press on a timer tab opens the editor for that tracker.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.controller,
    this.isDarkMode,
    this.onToggleTheme,
    this.onNewTimer,
    this.onEditTimer,
  });

  final TrackerController controller;

  /// Theme state owned by main.dart (pw-generator pattern).
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  /// Tap on the "+" tab: create a new timer.
  final VoidCallback? onNewTimer;

  /// Long-press on a timer tab: edit that tracker.
  final ValueChanged<Tracker>? onEditTimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ValueListenableBuilder<AppState>(
              valueListenable: controller,
              builder: (context, state, _) {
                return Row(
                  children: [
                    for (int i = 0; i < state.trackers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _TabChip(
                        tracker: state.trackers[i],
                        selected: i == state.selectedIndex,
                        activeColor: ext.stateActive,
                        activeTint: ext.stateActiveTint,
                        inactiveColor: secondary,
                        inactiveBackground: ext.surfaceVariant,
                        onTap: () => controller.select(i),
                        onLongPress: onEditTimer == null
                            ? null
                            : () => onEditTimer!(state.trackers[i]),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _AddChip(color: secondary, onTap: onNewTimer),
                  ],
                );
              },
            ),
          ),
        ),
        if (onToggleTheme != null && isDarkMode != null) ...[
          const SizedBox(width: 8),
          _ThemeToggle(
            isDarkMode: isDarkMode!,
            onTap: onToggleTheme!,
          ),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tracker,
    required this.selected,
    required this.activeColor,
    required this.activeTint,
    required this.inactiveColor,
    required this.inactiveBackground,
    required this.onTap,
    this.onLongPress,
  });

  final Tracker tracker;
  final bool selected;
  final Color activeColor;
  final Color activeTint;
  final Color inactiveColor;
  final Color inactiveBackground;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? activeColor : inactiveColor;

    return Material(
      color: selected ? activeTint : inactiveBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TimerGlyph(id: tracker.glyph, size: 18, color: fg),
              if (tracker.name != null) ...[
                const SizedBox(width: 6),
                Text(
                  tracker.name!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "+" tab: dashed outline, opens the editor (mockup v0.3.4).
class _AddChip extends StatelessWidget {
  const _AddChip({required this.color, this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DashedRoundedRectPainter(
        color: color.withValues(alpha: 0.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.add_rounded, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDarkMode, required this.onTap});

  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: ext.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
