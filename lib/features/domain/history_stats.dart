import '../models/streak_run.dart';

/// Aggregated history numbers shown on the back of the hero card
/// (history step). Pure domain: no UI, no I/O, injectable clock.
class HistoryStats {
  const HistoryStats({
    required this.bestRunDays,
    required this.resetCount,
  });

  /// Longest streak ever, the live one included (whole days).
  final int bestRunDays;

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
  for (final StreakRun run in runs) {
    final int days = run.wholeDays;
    if (days > best) {
      best = days;
    }
  }

  return HistoryStats(
    bestRunDays: best,
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

/// The history after the streak start moves to [newStartAt]
/// (instant reset, relapse, editor correction). Pure: the
/// controller is a one-liner around this, both user rules live
/// here and are tested in history_stats_test.
///
/// Rule 1 — forward move (new start AFTER the old one): the old
/// streak closes into a run that ends exactly at the new start.
/// A streak that started 5 days ago, corrected to 3 days ago,
/// leaves a 2 day run (5 - 3) ending where the 3 days begin.
///
/// Rule 2 — backward move (new start BEFORE the old one): the
/// old streak never happened, nothing is logged for it. If the
/// current streak had 3 days and the start moves to 5 days ago,
/// those 3 days vanish.
///
/// On top of both, the closed runs are corrected against the
/// boundary (the earlier of the two starts): every run that
/// claims clean days at or after the boundary is not credible. A
/// run that CONTAINS the boundary keeps its credible days and is
/// shortened to end there; a run that sits entirely INSIDE the
/// corrected period (a stale record, or one covered by the
/// closing run) is removed entirely. Runs that ended before the
/// boundary stay untouched: those are the teeth of the sawtooth.
List<StreakRun> correctedHistory({
  required List<StreakRun> history,
  required DateTime previousStartAt,
  required DateTime newStartAt,
}) {
  final DateTime boundary =
      newStartAt.isBefore(previousStartAt) ? newStartAt : previousStartAt;

  // Walk the runs from the most recent one backwards until a
  // run ends at or before the boundary: that one and everything
  // before it is credible.
  int keep = history.length;
  int truncateAt = -1;
  for (int i = history.length - 1; i >= 0; i--) {
    final StreakRun run = history[i];
    if (!run.endedAt.isAfter(boundary)) {
      break;
    }
    if (run.startedAt.isBefore(boundary)) {
      // Contains the boundary: the credible days before it stay.
      keep = i;
      truncateAt = i;
      break;
    }
    // Entirely inside the corrected period: not credible, gone.
    keep = i;
  }

  List<StreakRun> corrected;
  if (truncateAt >= 0) {
    corrected = <StreakRun>[
      ...history.sublist(0, truncateAt),
      StreakRun(startedAt: history[truncateAt].startedAt, endedAt: boundary),
    ];
  } else if (keep == history.length) {
    corrected = history;
  } else {
    corrected = history.sublist(0, keep);
  }

  if (!newStartAt.isAfter(previousStartAt)) {
    return corrected;
  }
  return <StreakRun>[
    ...corrected,
    StreakRun(startedAt: previousStartAt, endedAt: newStartAt),
  ];
}
