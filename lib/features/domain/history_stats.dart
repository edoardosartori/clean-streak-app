import '../models/streak_run.dart';

/// Aggregated history numbers shown on the back of the hero card
/// (history step). Pure domain: no UI, no I/O, injectable clock.
class HistoryStats {
  const HistoryStats({
    required this.bestRunDays,
    required this.totalCleanDays,
    required this.resetCount,
  });

  /// Longest streak ever, the live one included (whole days).
  final int bestRunDays;

  /// Every clean day this tracker has ever seen: all closed runs
  /// plus the live streak (whole days).
  final int totalCleanDays;

  /// How many times the streak was closed (= closed runs).
  final int resetCount;
}

/// One point of the chart line: how many days clean at [at].
class HistorySample {
  const HistorySample({required this.at, required this.daysClean});

  final DateTime at;
  final double daysClean;
}

/// Valid runs only, chronological. A run is valid when it ends
/// strictly after it starts; anything else (clock skew, corrupt
/// records) is dropped — the codec already refuses to load one,
/// this keeps the stats and the chart consistent anyway.
List<StreakRun> validRunsSorted(List<StreakRun> history) {
  final List<StreakRun> runs = <StreakRun>[
    for (final StreakRun run in history)
      if (run.endedAt.isAfter(run.startedAt)) run,
  ]..sort((StreakRun a, StreakRun b) => a.startedAt.compareTo(b.startedAt));
  return runs;
}

int _wholeDays(DateTime from, DateTime to) {
  return to.isAfter(from) ? to.difference(from).inDays : 0;
}

/// Stats over the closed runs plus the live streak.
HistoryStats computeHistoryStats({
  required List<StreakRun> history,
  required DateTime currentStartAt,
  required DateTime now,
}) {
  final List<StreakRun> runs = validRunsSorted(history);
  final int currentDays = _wholeDays(currentStartAt, now);

  int best = currentDays;
  int total = currentDays;
  for (final StreakRun run in runs) {
    final int days = run.wholeDays;
    if (days > best) {
      best = days;
    }
    total += days;
  }

  return HistoryStats(
    bestRunDays: best,
    totalCleanDays: total,
    resetCount: runs.length,
  );
}

/// The chart line, day by day: each streak climbs from zero, the
/// line drops to zero where it closed and climbs again; the live
/// streak climbs to [now] — the "sawtooth" that shows the real
/// journey over time. Pure: the painter only draws what comes
/// back, it owns no logic.
List<HistorySample> computeHistorySeries({
  required List<StreakRun> history,
  required DateTime currentStartAt,
  required DateTime now,
}) {
  final List<StreakRun> runs = validRunsSorted(history);
  final List<HistorySample> samples = <HistorySample>[];

  void rise(DateTime from, DateTime to) {
    if (!to.isAfter(from)) {
      return;
    }
    samples.add(HistorySample(at: from, daysClean: 0));
    samples.add(
      HistorySample(at: to, daysClean: to.difference(from).inDays.toDouble()),
    );
  }

  for (final StreakRun run in runs) {
    rise(run.startedAt, run.endedAt);
  }
  rise(currentStartAt, now);
  return samples;
}
