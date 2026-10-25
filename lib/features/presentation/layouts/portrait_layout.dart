import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/feedback/fusion_dialog.dart';
import '../../../core/theme/fusion_motion.dart';
import '../../data/tracker_repository.dart';
import '../../domain/streak_calculator.dart';
import '../../models/tracker.dart';
import '../state/app_state.dart';
import '../state/tracker_controller.dart';
import '../widgets/empty_trackers.dart';
import '../widgets/milestone_card.dart';
import '../widgets/streak_hero_card.dart';
import '../widgets/top_bar.dart';
import '../widgets/tracker_editor_dialog.dart';

/// Home, portrait: top bar with the timer tabs and "+", then the
/// hero card and the milestones card. Vertical full view, no
/// scroll. The hero fills the free height.
class PortraitLayout extends StatefulWidget {
  const PortraitLayout({
    super.key,
    this.isDarkMode,
    this.onToggleTheme,
    this.repository,
    this.initialTrackers = const <Tracker>[],
  });

  /// Theme state is owned by main.dart (same pattern as
  /// pw-generator). Null = the toggle is simply not shown.
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  /// injected persistence. Null = the layout still works,
  /// it just does not save anything.
  final TrackerRepository? repository;

  /// Trackers loaded at boot, handed down from main.dart.
  final List<Tracker> initialTrackers;

  @override
  State<PortraitLayout> createState() => _PortraitLayoutState();
}

class _PortraitLayoutState extends State<PortraitLayout> {
  late final TrackerController controller;
  late final PageController pageController;

  /// 1 s UI tick: recomputes breakdown/snapshot live. The controller
  /// is untouched — the data changes only on select/reset/editor.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    controller = TrackerController(
      initial: AppState(trackers: widget.initialTrackers),
      repository: widget.repository,
    );
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

  /// Opens the editor: [isNew] creates a fresh draft (and guards
  /// the 20 timer cap), otherwise edits the selected tracker.
  Future<void> _openEditor({required bool isNew}) async {
    final AppState state = controller.value;

    if (isNew) {
      if (state.trackers.length >= TrackerController.maxTrackers) {
        await FusionDialog.show(
          context,
          title: 'Timer limit reached',
          message: 'You can keep up to '
              '${TrackerController.maxTrackers} active timers.',
        );
        return;
      }
    }

    final Tracker? draft = isNew
        ? Tracker(
            id: 't${DateTime.now().microsecondsSinceEpoch}',
            glyph: TimerGlyphId.droplet,
            scene: HeroScene.peaks,
            startAt: DateTime.now(),
          )
        : state.selected;
    if (draft == null) {
      return;
    }

    final TrackerEditorResult? result = await TrackerEditorDialog.show(
      context,
      tracker: draft,
      isNew: isNew,
    );
    if (result == null || !mounted) {
      return;
    }

    switch (result) {
      case TrackerEditorSaved(:final tracker):
        if (isNew) {
          controller.addTracker(tracker);
        } else {
          controller.updateTracker(tracker);
        }
      case TrackerEditorDeleted(:final id):
        controller.deleteTracker(id);
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
                TopBar(
                  controller: controller,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                  onNewTimer: () => _openEditor(isNew: true),
                  onEditTimer: (tracker) => _openEditor(isNew: false),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ValueListenableBuilder<AppState>(
                    valueListenable: controller,
                    builder: (context, state, _) {
                      if (state.trackers.isEmpty) {
                        return EmptyTrackers(
                          onNewTimer: () => _openEditor(isNew: true),
                        );
                      }
                      return PageView.builder(
                        controller: pageController,
                        itemCount: state.trackers.length,
                        onPageChanged: controller.select,
                        itemBuilder: (context, index) {
                          final Tracker tracker = state.trackers[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // The hero takes all the free height; the
                              // milestones card keeps its own size.
                              Expanded(
                                child: StreakHeroCard(
                                  tracker: tracker,
                                  onEdit: () => _openEditor(isNew: false),
                                  onReset: () => _confirmReset(tracker),
                                ),
                              ),
                              const SizedBox(height: 16),
                              MilestoneCard(tracker: tracker),
                            ],
                          );
                        },
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
