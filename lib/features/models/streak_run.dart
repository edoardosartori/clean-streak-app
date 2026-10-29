import 'package:flutter/foundation.dart';

/// One past streak of a tracker: from the moment it started to the
/// moment it was closed (instant reset or a relapse date set from
/// the editor).
///
/// The CURRENT streak is never a run: it is always the live
/// [Tracker.startAt]; when it closes, it lands here.
@immutable
class StreakRun {
  const StreakRun({required this.startedAt, required this.endedAt});

  /// When the streak started.
  final DateTime startedAt;

  /// When the streak ended (the reset or relapse moment). Always
  /// strictly after [startedAt]: the codec and the stats skip
  /// anything else by design.
  final DateTime endedAt;

  /// Whole days the streak lasted (truncated, like every "days"
  /// figure in the app).
  int get wholeDays => endedAt.difference(startedAt).inDays;
}
