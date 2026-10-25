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

/// Step 3a seed: three timers like the mockup, in memory only.
/// Persistence (Hive) arrives with step 4: quitting the app resets
/// everything, which is expected at this point.
AppState seedAppState({DateTime Function()? clock}) {
  final DateTime now = (clock ?? DateTime.now)();

  return AppState(trackers: [
    // 4 days + 01:09:02, like the mockup hero.
    Tracker(
      id: 'alcohol',
      glyph: TimerGlyphId.wineGlass,
      name: 'Alcohol',
      scene: HeroScene.peaks,
      startAt: now.subtract(
        const Duration(days: 4, hours: 1, minutes: 9, seconds: 2),
      ),
    ),
    // Unnamed timer: in the tab only the glyph is visible.
    Tracker(
      id: 'smoking',
      glyph: TimerGlyphId.cigarette,
      scene: HeroScene.city,
      startAt: now.subtract(const Duration(days: 11, hours: 5)),
    ),
    // 2d milestone switched off: snapshot skips over it.
    Tracker(
      id: 'sugar',
      glyph: TimerGlyphId.candy,
      name: 'Sugar',
      scene: HeroScene.lake,
      startAt: now.subtract(const Duration(days: 1, hours: 3)),
      disabledMilestones: const {'2d'},
    ),
  ]);
}
