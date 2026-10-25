import 'package:flutter/foundation.dart';

import '../../models/tracker.dart';
import 'app_state.dart';

/// Owns the app state (ValueNotifier, suite convention).
///
/// The 1 s UI tick lives in the layout, not here: the controller
/// changes only when the data changes (tab selection, reset,
/// editor — step 3c).
class TrackerController extends ValueNotifier<AppState> {
  TrackerController({AppState? initial}) : super(initial ?? seedAppState());

  int get selectedIndex => value.selectedIndex;

  void select(int index) {
    if (index != value.selectedIndex) {
      value = value.copyWith(selectedIndex: index);
    }
  }

  /// Restarts the streak of the selected timer from now.
  /// The UI confirms with FusionDialog (destructive) before calling.
  void resetSelected() {
    final List<Tracker> trackers = List<Tracker>.of(value.trackers);
    final int i = value.selectedIndex.clamp(0, trackers.length - 1);
    trackers[i] = trackers[i].copyWith(startAt: DateTime.now());
    value = value.copyWith(trackers: trackers);
  }
}
