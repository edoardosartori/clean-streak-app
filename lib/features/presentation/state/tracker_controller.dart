import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/tracker.dart';
import '../../data/tracker_repository.dart';
import 'app_state.dart';

/// Owns the app state (ValueNotifier, suite convention).
///
/// The 1 s UI tick lives in the layout, not here: the controller
/// changes only when the data changes (tab selection, reset,
/// editor, add/delete).
///
/// Persistence: when a [TrackerRepository] is injected,
/// every data mutation is mirrored to it, fire-and-forget (Hive
/// writes are readable immediately; the future only covers the
/// disk flush). The tab selection is NOT persisted (confirmed
/// decision: the app always restarts on the first tab).
class TrackerController extends ValueNotifier<AppState> {
  TrackerController({AppState? initial, TrackerRepository? repository})
      : _repository = repository,
        super(initial ?? const AppState(trackers: []));

  /// Design cap: at most 20 active timers (confirmed decision).
  static const int maxTrackers = 20;

  final TrackerRepository? _repository;

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
    final Tracker reset = trackers[i].copyWith(startAt: DateTime.now());
    trackers[i] = reset;
    value = value.copyWith(trackers: trackers);
    _save(reset);
  }

  /// Adds a new tracker and selects it.
  /// Returns false when the 20 timer cap is reached.
  bool addTracker(Tracker tracker) {
    if (value.trackers.length >= maxTrackers) {
      return false;
    }
    value = value.copyWith(
      trackers: [...value.trackers, tracker],
      selectedIndex: value.trackers.length,
    );
    _save(tracker);
    return true;
  }

  /// Saves an editor edit (icon, name, scene, milestones, relapse).
  void updateTracker(Tracker tracker) {
    final List<Tracker> trackers = List<Tracker>.of(value.trackers);
    final int i = trackers.indexWhere((Tracker t) => t.id == tracker.id);
    if (i == -1) {
      return;
    }
    trackers[i] = tracker;
    value = value.copyWith(trackers: trackers);
    _save(tracker);
  }

  /// Removes a tracker and keeps the selection valid.
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
  }

  void _save(Tracker tracker) {
    final TrackerRepository? repository = _repository;
    if (repository != null) {
      unawaited(repository.saveTracker(tracker));
    }
  }
}
