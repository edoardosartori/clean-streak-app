import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/feedback/fusion_dialog.dart';
import '../../../core/theme/fusion_motion.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../data/notifications/milestone_scheduler.dart';
import '../../data/remote/remote_backup.dart';
import '../../data/tracker_repository.dart';
import '../../domain/streak_calculator.dart';
import '../../models/tracker.dart';
import '../state/app_state.dart';
import '../state/tracker_controller.dart';
import '../widgets/backup_sheet.dart';
import '../widgets/empty_trackers.dart';
import '../widgets/milestone_card.dart';
import '../widgets/milestone_celebrations.dart';
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
    this.scheduler,
    this.initialSelectedTrackerId,
    this.backup,
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

  /// System milestone notifications (step 4d). Null = no
  /// notifications, everything else keeps working.
  final MilestoneScheduler? scheduler;

  /// Card to open at boot when the app was launched by tapping a
  /// milestone notification (cold start).
  final String? initialSelectedTrackerId;

  /// Online backup (step 5). Null = no cloud chip in the top bar.
  final TrackerBackupService? backup;

  @override
  State<PortraitLayout> createState() => _PortraitLayoutState();
}

class _PortraitLayoutState extends State<PortraitLayout> {
  late final TrackerController controller;
  late final MilestoneCelebrationQueue celebrations;
  late final PageController pageController;

  /// 1 s UI tick: recomputes breakdown/snapshot live and checks
  /// for milestones to celebrate. The controller changes only on
  /// select/reset/editor/celebration marking.
  Timer? _ticker;

  /// "Backup saved" toast (step 5): the automatic mirror is
  /// silent, the manual one confirms with a toast.
  Timer? _toastTimer;
  String? _toastText;
  DateTime? _toastAt;

  @override
  void initState() {
    super.initState();
    controller = TrackerController(
      initial: AppState(trackers: widget.initialTrackers),
      repository: widget.repository,
      scheduler: widget.scheduler,
      backup: widget.backup,
    );
    celebrations = MilestoneCelebrationQueue(
      onMarkCelebrated: controller.updateTracker,
    );
    // Cold start from a tapped notification: the home opens on
    // that card before the PageView exists, so no jump is needed.
    if (widget.initialSelectedTrackerId != null) {
      _selectTrackerById(widget.initialSelectedTrackerId!);
    }
    pageController = PageController(initialPage: controller.selectedIndex);
    // Taps while the app is running (foreground or background)
    // select the card of the milestone.
    widget.scheduler?.onTrackerTapped = _selectTrackerById;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _scanCelebrations();
        setState(() {});
      }
    });
    controller.addListener(_syncPage);
    celebrations.addListener(_onCelebrationsChanged);
    // The cloud chip follows the sign-in state (silent restore at
    // boot included).
    widget.backup?.addListener(_onBackupChanged);
    // First scan after the first frame: the home shows up, then
    // the celebrations of everything reached while away. The
    // notification permission is asked here too, once ever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scanCelebrations();
        unawaited(widget.scheduler?.requestPermissionIfNeeded());
      }
    });
  }

  @override
  void dispose() {
    widget.scheduler?.onTrackerTapped = null;
    widget.backup?.removeListener(_onBackupChanged);
    _ticker?.cancel();
    _toastTimer?.cancel();
    controller.removeListener(_syncPage);
    celebrations.removeListener(_onCelebrationsChanged);
    controller.dispose();
    celebrations.dispose();
    pageController.dispose();
    super.dispose();
  }

  /// Celebration check (boot + every tick): queues one sheet per
  /// newly reached, un-celebrated milestone of every card.
  void _scanCelebrations() {
    celebrations.scan(controller.value.trackers);
  }

  void _onCelebrationsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onBackupChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Selects the card a milestone notification points at (tap
  /// with the app running, or a cold start launched by a tap).
  void _selectTrackerById(String trackerId) {
    if (!mounted) {
      return;
    }
    final int index =
        controller.value.trackers.indexWhere((Tracker t) => t.id == trackerId);
    if (index >= 0) {
      controller.select(index);
    }
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

  /// Cloud chip tap -> backup sheet (step 5).
  Future<void> _openBackupSheet() async {
    final TrackerBackupService? backup = widget.backup;
    if (backup == null) {
      return;
    }
    await showBackupSheet(
      context,
      controller: controller,
      backup: backup,
      onBackedUp: _showBackupToast,
    );
  }

  /// "Backup saved" confirmation of a manual backup (approved
  /// mockup): a toast at the bottom of the home, auto-dismissed.
  void _showBackupToast() {
    _toastTimer?.cancel();
    setState(() {
      _toastText = 'Backup saved';
      _toastAt = widget.backup?.lastBackupAt ?? DateTime.now();
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _toastText = null;
          _toastAt = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(theme.brightness),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: <Widget>[
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 12),
                    TopBar(
                      controller: controller,
                      isDarkMode: widget.isDarkMode,
                      onToggleTheme: widget.onToggleTheme,
                      onNewTimer: () => _openEditor(isNew: true),
                      onEditTimer: (tracker) => _openEditor(isNew: false),
                      onBackupTap:
                          widget.backup == null ? null : _openBackupSheet,
                      isBackupConnected: widget.backup?.isSignedIn ?? false,
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
                                children: <Widget>[
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
            if (celebrations.isShowing)
              Positioned.fill(
                child: MilestoneCelebrationOverlay(queue: celebrations),
              ),
            if (_toastText != null)
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: _BackupToast(text: _toastText!, at: _toastAt!),
              ),
          ],
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

/// Bottom toast: FusionDialog surface recipe (surface + border in
/// dark, soft shadow in light), success check, text and the
/// backup date in JetBrains Mono.
class _BackupToast extends StatelessWidget {
  const _BackupToast({required this.text, required this.at});

  final String text;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FusionThemeExtension ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: ext.border) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF12161B).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_rounded, size: 18, color: ext.success),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            _formatToastDate(at),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'JetBrains Mono',
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }

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

  /// "Oct 28, 2026 · 14:32" — the editor / celebration format.
  static String _formatToastDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year} · '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

  static String _twoDigits(int n) => n < 10 ? '0$n' : '$n';
}
