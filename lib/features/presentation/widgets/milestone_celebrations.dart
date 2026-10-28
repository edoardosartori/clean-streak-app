import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/milestone_catalog.dart';
import '../../domain/milestone_engine.dart';
import '../../models/tracker.dart';
import 'timer_glyph.dart';

/// One milestone to celebrate: which card reached it, which
/// milestone and when.
class MilestoneCelebration {
  const MilestoneCelebration({
    required this.tracker,
    required this.milestone,
    required this.reachedAt,
  });

  final Tracker tracker;
  final MilestoneDefinition milestone;
  final DateTime reachedAt;
}

/// Queue of milestone celebrations (mockup v0.1).
///
/// [scan] runs at boot (after the first frame) and on every 1 s
/// tick: every active milestone already reached and not in the
/// card's celebrated set becomes a celebration, chronological
/// across all cards. The cards are marked immediately through
/// [onMarkCelebrated] (controller update, persisted by Hive), so
/// a killed process never re-celebrates anything.
class MilestoneCelebrationQueue extends ChangeNotifier {
  MilestoneCelebrationQueue({required this.onMarkCelebrated});

  /// Persists the celebrated state of a card (controller call).
  final ValueChanged<Tracker> onMarkCelebrated;

  final List<MilestoneCelebration> _pending = <MilestoneCelebration>[];

  bool get isShowing => _pending.isNotEmpty;
  int get pendingCount => _pending.length;
  MilestoneCelebration? get current => _pending.isEmpty ? null : _pending.first;

  /// Queues every un-celebrated reached milestone of every card.
  void scan(List<Tracker> trackers) {
    final MilestoneEngine engine = MilestoneEngine();
    final List<MilestoneCelebration> fresh = <MilestoneCelebration>[];
    final Set<String> marked = <String>{};

    for (final Tracker tracker in trackers) {
      for (final MilestoneReached reached in engine.reached(
        startAt: tracker.startAt,
        disabledMilestones: tracker.disabledMilestones,
      )) {
        if (tracker.celebratedMilestones.contains(reached.definition.id)) {
          continue;
        }
        fresh.add(
          MilestoneCelebration(
            tracker: tracker,
            milestone: reached.definition,
            reachedAt: reached.reachedAt,
          ),
        );
        if (marked.add(tracker.id)) {
          onMarkCelebrated(tracker);
        }
      }
    }

    if (fresh.isEmpty) {
      return;
    }
    // Chronological across all cards (mockup: soonest first).
    fresh.sort(
      (MilestoneCelebration a, MilestoneCelebration b) =>
          a.reachedAt.compareTo(b.reachedAt),
    );
    _pending.addAll(fresh);
    notifyListeners();
  }

  /// "Continue": drops the current sheet and shows the next one.
  void dismissCurrent() {
    if (_pending.isEmpty) {
      return;
    }
    _pending.removeAt(0);
    notifyListeners();
  }

  /// "Skip all": clears the whole queue.
  void dismissAll() {
    if (_pending.isEmpty) {
      return;
    }
    _pending.clear();
    notifyListeners();
  }
}

/// Full-screen celebration overlay: scrim + blur (FusionDialog
/// recipe) with the current sheet on top of the home.
class MilestoneCelebrationOverlay extends StatelessWidget {
  const MilestoneCelebrationOverlay({super.key, required this.queue});

  final MilestoneCelebrationQueue queue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    final MilestoneCelebration? current = queue.current;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final double blur =
        tokens.dimension('component.dialog.scrimBlur').toDouble();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: GestureDetector(
        // Opaque: blocks every interaction with the home behind.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: ext.scrim,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: _CelebrationSheet(
            celebration: current,
            isDark: isDark,
            secondary: secondary,
            pendingCount: queue.pendingCount,
            onContinue: queue.dismissCurrent,
            onSkipAll: queue.pendingCount > 1 ? queue.dismissAll : null,
          ),
        ),
      ),
    );
  }
}

class _CelebrationSheet extends StatelessWidget {
  const _CelebrationSheet({
    required this.celebration,
    required this.isDark,
    required this.secondary,
    required this.pendingCount,
    required this.onContinue,
    required this.onSkipAll,
  });

  final MilestoneCelebration celebration;
  final bool isDark;
  final Color secondary;
  final int pendingCount;
  final VoidCallback onContinue;
  final VoidCallback? onSkipAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ext.success, width: 4),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.check_rounded,
                size: 32,
                color: ext.success,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'MILESTONE REACHED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: secondary,
            ),
          ),
          const SizedBox(height: 4),
          _MilestoneHeadline(label: celebration.milestone.label),
          const SizedBox(height: 16),
          _TrackerRow(
            tracker: celebration.tracker,
            reachedAt: celebration.reachedAt,
            secondary: secondary,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          if (onSkipAll != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSkipAll,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                foregroundColor: secondary,
              ),
              child: const Text(
                'Skip all',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (pendingCount > 1) ...[
            const SizedBox(height: 10),
            _QueueDots(count: pendingCount, secondary: secondary),
          ],
        ],
      ),
    );
  }
}

/// "2 days" with the number in JetBrains Mono (suite rule:
/// numbers and data always in mono).
class _MilestoneHeadline extends StatelessWidget {
  const _MilestoneHeadline({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final int space = label.indexOf(' ');
    final String number = label.substring(0, space);
    final String rest = label.substring(space + 1);

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: <TextSpan>[
          TextSpan(
            text: number,
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
          TextSpan(text: ' $rest!'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({
    required this.tracker,
    required this.reachedAt,
    required this.secondary,
  });

  final Tracker tracker;
  final DateTime reachedAt;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return Row(
      children: <Widget>[
        if (tracker.glyph != null) ...<Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ext.stateActiveTint,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: TimerGlyph(
              id: tracker.glyph!,
              size: 18,
              color: ext.stateActive,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tracker.name ?? 'Timer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Reached ${_formatDate(reachedAt)}',
                style: TextStyle(fontSize: 11, color: secondary),
              ),
            ],
          ),
        ),
      ],
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

  /// "Oct 18, 2026 · 20:47" — same format as the editor relapse.
  static String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year} · '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

  static String _twoDigits(int n) => n < 10 ? '0$n' : '$n';
}

/// Queue indicator: dots + "1 of 3" (mono), only when queueing.
class _QueueDots extends StatelessWidget {
  const _QueueDots({required this.count, required this.secondary});

  final int count;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FusionThemeExtension>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 5),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i == 0 ? ext.stateActive : secondary.withValues(alpha: 0.35),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          '1 of $count',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            color: secondary,
          ),
        ),
      ],
    );
  }
}
