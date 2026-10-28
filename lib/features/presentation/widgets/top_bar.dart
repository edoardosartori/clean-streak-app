import 'package:flutter/material.dart';

import '../../../core/theme/fusion_motion.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../models/tracker.dart';
import '../state/app_state.dart';
import '../state/tracker_controller.dart';
import 'dashed_border.dart';
import 'timer_glyph.dart';

/// Top bar of the home: the timer tabs (tap or swipe), the "+"
/// tab that opens the editor, the cloud backup chip and the
/// theme toggle.
///
/// Long-press on a timer tab opens the editor for that tracker.
/// When the selection changes (also from the swipe below) the
/// strip auto-scrolls to keep the selected tab in view.
class TopBar extends StatefulWidget {
  const TopBar({
    super.key,
    required this.controller,
    this.isDarkMode,
    this.onToggleTheme,
    this.onNewTimer,
    this.onEditTimer,
    this.onBackupTap,
    this.isBackupConnected = false,
  });

  final TrackerController controller;

  /// Theme state owned by main.dart (pw-generator pattern).
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  /// Tap on the "+" tab: create a new timer.
  final VoidCallback? onNewTimer;

  /// Long-press on a timer tab: edit that tracker.
  final ValueChanged<Tracker>? onEditTimer;

  /// Tap on the cloud chip: open the backup sheet (step 5).
  /// Null = the chip is not shown (no backup service wired).
  final VoidCallback? onBackupTap;

  /// Signed-in state: the chip icon uses the active color.
  final bool isBackupConnected;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final ScrollController _scrollController = ScrollController();

  /// Attached to whichever chip is currently selected: after a
  /// selection change the strip scrolls to keep it in view.
  final GlobalKey _selectedChipKey = GlobalKey(debugLabel: 'selected-tab');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revealSelected);
  }

  @override
  void didUpdateWidget(TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_revealSelected);
      widget.controller.addListener(_revealSelected);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revealSelected);
    _scrollController.dispose();
    super.dispose();
  }

  /// The selection changed (swipe or tab tap): after the frame
  /// the chip with the key is the new selected one, then the
  /// strip scrolls to it. alignment 0.5 = centered.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? chip = _selectedChipKey.currentContext;
      if (chip == null) return;
      Scrollable.ensureVisible(
        chip,
        duration: FusionMotion.normal,
        curve: FusionMotion.curve,
        alignment: 0.5,
      );
    });
  }

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
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: ValueListenableBuilder<AppState>(
              valueListenable: widget.controller,
              builder: (context, state, _) {
                return Row(
                  children: [
                    for (int i = 0; i < state.trackers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _TabChip(
                        key: i == state.selectedIndex ? _selectedChipKey : null,
                        tracker: state.trackers[i],
                        selected: i == state.selectedIndex,
                        activeColor: ext.stateActive,
                        activeTint: ext.stateActiveTint,
                        inactiveColor: secondary,
                        inactiveBackground: ext.surfaceVariant,
                        onTap: () => widget.controller.select(i),
                        onLongPress: widget.onEditTimer == null
                            ? null
                            : () => widget.onEditTimer!(state.trackers[i]),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _AddChip(color: secondary, onTap: widget.onNewTimer),
                  ],
                );
              },
            ),
          ),
        ),
        if (widget.onBackupTap != null) ...[
          const SizedBox(width: 8),
          _BackupChip(
            connected: widget.isBackupConnected,
            onTap: widget.onBackupTap!,
          ),
        ],
        if (widget.onToggleTheme != null && widget.isDarkMode != null) ...[
          const SizedBox(width: 8),
          _ThemeToggle(
            isDarkMode: widget.isDarkMode!,
            onTap: widget.onToggleTheme!,
          ),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    super.key,
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

    // No icon: the chip falls back to the name, or to a generic
    // "Timer" label when both are missing (never an empty chip).
    final TimerGlyphId? glyph = tracker.glyph;
    final String? label = tracker.name ?? (glyph == null ? 'Timer' : null);

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
              if (glyph != null) TimerGlyph(id: glyph, size: 18, color: fg),
              if (label != null) ...[
                if (glyph != null) const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
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

/// The cloud chip (step 5): opens the backup sheet. Same chip
/// style as the theme toggle; the active color (stateActive,
/// as the selected tabs) marks the signed-in state.
class _BackupChip extends StatelessWidget {
  const _BackupChip({required this.connected, required this.onTap});

  final bool connected;
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
            Icons.cloud_outlined,
            size: 20,
            color: connected ? ext.stateActive : theme.colorScheme.onSurface,
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
