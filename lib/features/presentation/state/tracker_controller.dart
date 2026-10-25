import 'package:flutter/foundation.dart';

/// Placeholder controller for step 1: only the selected tab index.
/// Step 2 adds the domain layer (StreakCalculator, MilestoneEngine) and the
/// real AppState; step 3 wires it to the PageView of the timer tabs.
class TrackerController extends ValueNotifier<int> {
  TrackerController({int initialIndex = 0}) : super(initialIndex);

  /// Index of the timer currently visible in the swipeable tabs.
  int get selectedIndex => value;

  void select(int index) {
    if (index != value) value = index;
  }
}
