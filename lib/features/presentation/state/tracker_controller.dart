import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/notifications/milestone_scheduler.dart';
import '../../data/remote/remote_backup.dart';
import '../../data/tracker_repository.dart';
import '../../domain/history_stats.dart';
import '../../domain/milestone_engine.dart';
import '../../domain/milestone_notification_planner.dart';
import '../../models/streak_run.dart';
import '../../models/tracker.dart';
import 'app_state.dart';

/// Owns the app state (ValueNotifier, suite convention).
///
/// The 1 s UI tick lives in the layout, not here: the controller
/// changes only when the data changes (tab selection, reset,
/// editor, add/delete, celebration marks).
///
/// Persistence (step 4): when a [TrackerRepository] is injected,
/// every data mutation is mirrored to it, fire-and-forget (Hive
/// writes are readable immediately; the future only covers the
/// disk flush). The tab selection is NOT persisted (confirmed
/// decision: the app always restarts on the first tab).
///
/// System notifications (step 4d): same mirror pattern. Every
/// mutation (and the construction itself) re-applies the full
/// notification plan: deterministic ids make it idempotent, stale
/// pending notifications are cancelled, milestones that fired
/// while the app was closed are removed from the tray because the
/// in-app celebrations cover them.
///
/// Online backup (step 5): same mirror pattern once more. Every
/// mutation (and the construction) uploads the full snapshot to
/// Drive, fire-and-forget: pushSnapshot never throws and queues
/// the uploads. Until the user signed in manually the wired
/// service is a Noop, so nothing happens.
///
/// History (step 8): the streak start moving closes and corrects
/// the history through the pure domain helper correctedHistory
/// (the user rules live there, tested in history_stats_test): a
/// forward move closes the old streak into a run ending at the
/// new start (5 days -> 3 days leaves a 2 day run); a backward
/// move logs nothing for the old streak (the 3 days vanish) and
/// corrects the closed runs — shortened to the boundary when they
/// contain it, removed when they sit inside the corrected period.
///
/// Delete step: deleteRun removes ONE closed run from a
/// tracker's history — the manual repair hatch for a tooth
/// logged by mistake.
class TrackerController extends ValueNotifier<AppState> {
  TrackerController({
    AppState? initial,
    TrackerRepository? repository,
    MilestoneScheduler? scheduler,
    TrackerBackupService? backup,
  })  : _repository = repository,
        _scheduler = scheduler,
        _backup = backup,
        super(initial ?? const AppState(trackers: [])) {
    // Boot: plan the loaded cards immediately, so the system knows
    // about every upcoming milestone even if the app then stays
    // closed for weeks.
    _rescheduleNotifications();
    // Boot mirror for the backup too: a returning user pushes the
    // loaded state as it is (idempotent, last write wins). With
    // no signed-in account yet this is a silent no-op.
    _pushBackup();
  }

  /// Design cap: at most 20 active timers (confirmed decision).
  static const int maxTrackers = 20;

  final TrackerRepository? _repository;

  final MilestoneScheduler? _scheduler;

  final TrackerBackupService? _backup;

  final MilestoneNotificationPlanner _planner = MilestoneNotificationPlanner();

  int get selectedIndex => value.selectedIndex;

  void select(int index) {
    if (index != value.selectedIndex) {
      value = value.copyWith(selectedIndex: index);
    }
  }

  /// Restarts the streak of the selected timer from now.
  /// The UI confirms with FusionDialog (destructive) before calling.
  void resetSelected() {
    if (value.trackers.isEmpty) {
      return;
    }
    final List<Tracker> trackers = List<Tracker>.of(value.trackers);
    final int i = value.selectedIndex.clamp(0, trackers.length - 1);
    final Tracker previous = trackers[i];
    final DateTime now = DateTime.now();
    final Tracker stored = _refreshCelebrated(
      previous
          .copyWith(history: _closedHistory(previous, now))
          .copyWith(startAt: now),
    );
    trackers[i] = stored;
    value = value.copyWith(trackers: trackers);
    _save(stored);
    _rescheduleNotifications();
    _pushBackup();
  }

  /// Adds a new tracker and selects it.
  /// Returns false when the 20 timer cap is reached.
  bool addTracker(Tracker tracker) {
    if (value.trackers.length >= maxTrackers) {
      return false;
    }
    final Tracker stored = _refreshCelebrated(tracker);
    value = value.copyWith(
      trackers: [...value.trackers, stored],
      selectedIndex: value.trackers.length,
    );
    _save(stored);
    _rescheduleNotifications();
    _pushBackup();
    return true;
  }

  /// Saves an editor edit (icon, name, scene, milestones, relapse).
  /// A relapse that moves the start forward first appends the run
  /// the old streak is closing (history step).
  void updateTracker(Tracker tracker) {
    final List<Tracker> trackers = List<Tracker>.of(value.trackers);
    final int i = trackers.indexWhere((Tracker t) => t.id == tracker.id);
    if (i == -1) {
      return;
    }
    final Tracker previous = trackers[i];
    final Tracker incoming = tracker.copyWith(
      history: _closedHistory(previous, tracker.startAt),
    );
    final Tracker stored = _refreshCelebrated(incoming);
    trackers[i] = stored;
    value = value.copyWith(trackers: trackers);
    _save(stored);
    _rescheduleNotifications();
    _pushBackup();
  }

  /// Removes a tracker and keeps the selection valid. The plan
  /// re-application cancels its pending notifications.
  void deleteTracker(String id) {
    final List<Tracker> trackers = [
      for (final Tracker t in value.trackers)
        if (t.id != id) t,
    ];
    value = value.copyWith(
      trackers: trackers,
      selectedIndex: trackers.isEmpty
          ? 0
          : value.selectedIndex.clamp(0, trackers.length - 1),
    );
    final TrackerRepository? repository = _repository;
    if (repository != null) {
      unawaited(repository.deleteTracker(id));
    }
    _rescheduleNotifications();
    _pushBackup();
  }

  /// Removes one closed run from the history (delete step): the
  /// manual repair hatch for a tooth logged by mistake. The UI
  /// confirms with FusionDialog (destructive) before calling; the
  /// run is matched by its start AND end, so an index can never
  /// point at the wrong tooth. The live streak is never touched:
  /// it is not a run. A no-op (silent) when the tracker or the run
  /// is not there.
  void deleteRun(String id, StreakRun run) {
    final List<Tracker> trackers = List<Tracker>.of(value.trackers);
    final int i = trackers.indexWhere((Tracker t) => t.id == id);
    if (i == -1) {
      return;
    }
    final Tracker previous = trackers[i];
    final List<StreakRun> next = <StreakRun>[
      for (final StreakRun r in previous.history)
        if (r.startedAt != run.startedAt || r.endedAt != run.endedAt) r,
    ];
    if (next.length == previous.history.length) {
      return;
    }
    final Tracker stored = previous.copyWith(history: next);
    trackers[i] = stored;
    value = value.copyWith(trackers: trackers);
    _save(stored);
    _rescheduleNotifications();
    _pushBackup();
  }

  /// Full local replacement from a Drive restore (step 5). The
  /// restored list becomes the state, the ids that disappeared
  /// are deleted from Hive, everything else is saved, and both
  /// the notification plan and the snapshot are mirrored back
  /// (the push is the restored content itself: last write wins,
  /// also when the local copy was newer). The restored trackers
  /// bring their own history with them: nothing is closed here.
  void replaceAll(List<Tracker> trackers) {
    final Set<String> removedIds = <String>{
      for (final Tracker t in value.trackers) t.id,
    }..removeAll(<String>{
        for (final Tracker t in trackers) t.id,
      });

    value = value.copyWith(trackers: trackers, selectedIndex: 0);

    final TrackerRepository? repository = _repository;
    if (repository != null) {
      for (final String id in removedIds) {
        unawaited(repository.deleteTracker(id));
      }
      for (final Tracker tracker in trackers) {
        unawaited(repository.saveTracker(tracker));
      }
    }
    _rescheduleNotifications();
    _pushBackup();
  }

  /// History (history step): fully delegated to the pure domain
  /// helper correctedHistory — the two user rules (forward close,
  /// backward vanish) plus the correction of the closed runs.
  List<StreakRun> _closedHistory(Tracker previous, DateTime newStartAt) {
    return correctedHistory(
      history: previous.history,
      previousStartAt: previous.startAt,
      newStartAt: newStartAt,
    );
  }

  /// Celebration state maintenance (celebration step):
  /// "celebrated" = the active milestones already passed at the
  /// current start. Recomputed on every save because every mutation
  /// changes it:
  /// - reset -> empty set: the new streak can celebrate everything
  /// - relapse in the past -> the already passed milestones are
  ///   marked celebrated silently (no celebration was watched)
  /// - milestone (re)enabled after it passed -> silent as well
  /// - the celebration queue marking a card lands here too
  Tracker _refreshCelebrated(Tracker tracker) {
    final Set<String> passed = <String>{
      for (final MilestoneReached reached in MilestoneEngine().reached(
        startAt: tracker.startAt,
        disabledMilestones: tracker.disabledMilestones,
      ))
        reached.definition.id,
    };
    return tracker.copyWith(celebratedMilestones: passed);
  }

  /// System notifications (milestone scheduler step): the plan is
  /// the full desired state, reapplied on every change.
  void _rescheduleNotifications() {
    final MilestoneScheduler? scheduler = _scheduler;
    if (scheduler == null) {
      return;
    }
    unawaited(scheduler.apply(_planner.planFor(value.trackers)));
  }

  /// Online backup mirror (step 5): fire-and-forget, the service
  /// queues and swallows the errors.
  void _pushBackup() {
    final TrackerBackupService? backup = _backup;
    if (backup == null) {
      return;
    }
    unawaited(backup.pushSnapshot(value.trackers));
  }

  void _save(Tracker tracker) {
    final TrackerRepository? repository = _repository;
    if (repository != null) {
      unawaited(repository.saveTracker(tracker));
    }
  }
}
