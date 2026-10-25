import 'milestone_catalog.dart';

/// The last milestone a streak reached (target date = reached date).
class MilestoneReached {
  const MilestoneReached({required this.definition, required this.reachedAt});

  final MilestoneDefinition definition;
  final DateTime reachedAt;
}

/// The milestone currently in progress, with progress and remaining time.
class MilestoneInFocus {
  const MilestoneInFocus({
    required this.definition,
    required this.targetDate,
    required this.progress,
    required this.remaining,
  });

  final MilestoneDefinition definition;
  final DateTime targetDate;

  /// 0.0 -> 1.0. Feeds the hero progress bar and the "57%" text.
  final double progress;

  final Duration remaining;
}

/// Any future milestone (used for the "next" row and scheduling).
class MilestoneUpcoming {
  const MilestoneUpcoming({required this.definition, required this.targetDate});

  final MilestoneDefinition definition;
  final DateTime targetDate;
}

/// Where a streak stands relative to its (active) milestones:
/// [lastReached] -> [current] -> [next], the three rows of the home card.
class MilestoneSnapshot {
  const MilestoneSnapshot({this.lastReached, this.current, this.next});

  /// Null when the streak has not reached any milestone yet (< 1 day).
  final MilestoneReached? lastReached;
  final MilestoneInFocus? current;
  final MilestoneUpcoming? next;
}

/// Answers every milestone question the app has:
/// - snapshot: reached / in progress / next (home card + hero)
/// - upcoming: the next N active milestones (notification scheduling)
///
/// Milestones disabled per timer are skipped, EXCEPT the recurring
/// half-year ones which are always active ([MilestoneDefinition.canDisable]).
class MilestoneEngine {
  MilestoneEngine({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final DateTime Function() clock;

  /// Current milestone state for a streak started at [startAt].
  MilestoneSnapshot snapshot({
    required DateTime startAt,
    Set<String> disabledMilestones = const {},
    DateTime? at,
  }) {
    final DateTime now = at ?? clock();

    MilestoneReached? lastReached;
    MilestoneInFocus? current;
    MilestoneUpcoming? next;

    for (final MilestoneDefinition m in MilestoneCatalog.ordered()) {
      if (m.canDisable && disabledMilestones.contains(m.id)) continue;

      final DateTime target = m.targetDateFrom(startAt);
      if (!target.isAfter(now)) {
        lastReached = MilestoneReached(definition: m, reachedAt: target);
        continue;
      }
      if (current == null) {
        current = MilestoneInFocus(
          definition: m,
          targetDate: target,
          progress: _progress(startAt, target, now),
          remaining: target.difference(now),
        );
        continue;
      }
      next = MilestoneUpcoming(definition: m, targetDate: target);
      break;
    }

    return MilestoneSnapshot(
        lastReached: lastReached, current: current, next: next);
  }

  /// The first [count] active milestones in the future, chronological.
  /// Used to schedule system + in-app notifications; rescheduled on
  /// reset / app start / boot.
  List<MilestoneUpcoming> upcoming({
    required DateTime startAt,
    Set<String> disabledMilestones = const {},
    int count = 10,
    DateTime? at,
  }) {
    final DateTime now = at ?? clock();
    final List<MilestoneUpcoming> result = <MilestoneUpcoming>[];

    for (final MilestoneDefinition m in MilestoneCatalog.ordered()) {
      if (result.length >= count) break;
      if (m.canDisable && disabledMilestones.contains(m.id)) continue;
      final DateTime target = m.targetDateFrom(startAt);
      if (target.isAfter(now)) {
        result.add(MilestoneUpcoming(definition: m, targetDate: target));
      }
    }
    return result;
  }

  double _progress(DateTime start, DateTime target, DateTime now) {
    final int total = target.difference(start).inMicroseconds;
    if (total <= 0) return 1.0;
    final int done = now.difference(start).inMicroseconds;
    return (done / total).clamp(0.0, 1.0);
  }
}
