import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/feedback/fusion_dialog.dart';
import '../../../core/theme/fusion_motion.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/streak_calculator.dart';
import '../../models/tracker.dart';
import '../state/app_state.dart';
import '../state/tracker_controller.dart';
import '../widgets/milestone_card.dart';
import '../widgets/streak_hero_card.dart';
import '../widgets/timer_glyph.dart';

/// Home, portrait: timer tabs + hero card + milestones card,
/// vertical full view, no scroll.
class PortraitLayout extends StatefulWidget {
  const PortraitLayout({super.key, this.isDarkMode, this.onToggleTheme});

  /// Theme state is owned by main.dart (same pattern as
  /// pw-generator). Null = the toggle is simply not shown.
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  @override
  State<PortraitLayout> createState() => _PortraitLayoutState();
}

class _PortraitLayoutState extends State<PortraitLayout> {
  final TrackerController controller = TrackerController();
  late final PageController pageController;

  /// 1 s UI tick: recomputes breakdown/snapshot live. The controller
  /// is untouched — the data changes only on select/reset/editor.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: controller.selectedIndex);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    controller.addListener(_syncPage);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    controller.removeListener(_syncPage);
    controller.dispose();
    pageController.dispose();
    super.dispose();
  }

  /// Tab tap -> animate the PageView to the selection.
  void _syncPage() {
    final int target = controller.selectedIndex;
    if (pageController.hasClients && pageController.page?.round() != target) {
      pageController.animateToPage(
        target,
        duration: FusionMotion.normal,
        curve: FusionMotion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(theme.brightness),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _TopBar(
                  controller: controller,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: controller.value.trackers.length,
                    onPageChanged: controller.select,
                    itemBuilder: (context, index) {
                      final Tracker tracker = controller.value.trackers[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StreakHeroCard(
                            tracker: tracker,
                            onReset: () => _confirmReset(tracker),
                          ),
                          const SizedBox(height: 16),
                          MilestoneCard(tracker: tracker),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(Tracker tracker) async {
    final int days = StreakCalculator().totalDays(tracker.startAt);
    final bool confirmed = await FusionDialog.confirm(
      context,
      title: tracker.name == null ? 'Reset timer?' : 'Reset ${tracker.name}?',
      message:
          'The streak restarts from now.\nCurrent: $days ${days == 1 ? 'day' : 'days'}',
      confirmLabel: 'Reset',
      isDestructive: true,
    );
    if (confirmed && mounted) controller.resetSelected();
  }

  static SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }
}

/// Top bar: swipeable timer tabs + theme toggle.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    this.isDarkMode,
    this.onToggleTheme,
  });

  final TrackerController controller;
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

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
                      ),
                    ],
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
  });

  final Tracker tracker;
  final bool selected;
  final Color activeColor;
  final Color activeTint;
  final Color inactiveColor;
  final Color inactiveBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? activeColor : inactiveColor;

    return Material(
      color: selected ? activeTint : inactiveBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
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
