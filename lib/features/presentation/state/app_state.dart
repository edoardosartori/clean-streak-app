import 'package:flutter/foundation.dart';

import '../../models/tracker.dart';

/// Immutable snapshot of the app: the trackers and the selected tab.
@immutable
class AppState {
  const AppState({required this.trackers, this.selectedIndex = 0});

  final List<Tracker> trackers;
  final int selectedIndex;

  Tracker? get selected {
    if (trackers.isEmpty) return null;
    final int i = selectedIndex.clamp(0, trackers.length - 1);
    return trackers[i];
  }

  AppState copyWith({List<Tracker>? trackers, int? selectedIndex}) {
    return AppState(
      trackers: trackers ?? this.trackers,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}
