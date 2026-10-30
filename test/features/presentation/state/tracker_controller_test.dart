// FILE (NUOVO): test/features/presentation/state/tracker_controller_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:clean_streak/features/models/streak_run.dart';
import 'package:clean_streak/features/models/tracker.dart';
import 'package:clean_streak/features/presentation/state/app_state.dart';
import 'package:clean_streak/features/presentation/state/tracker_controller.dart';

void main() {
  final DateTime oct5 = DateTime(2026, 10, 5);
  final DateTime oct10 = DateTime(2026, 10, 10);
  final DateTime oct20 = DateTime(2026, 10, 20);

  /// Two closed teeth ([Oct 5 -> Oct 10] and [Oct 10 -> Oct 20])
  /// plus a live streak from Oct 20: the delete step only ever
  /// touches the teeth, never the live start.
  TrackerController controllerWithHistory() {
    return TrackerController(
      initial: AppState(
        trackers: <Tracker>[
          Tracker(
            id: 't1',
            scene: HeroScene.peaks,
            startAt: oct20,
            history: <StreakRun>[
              StreakRun(startedAt: oct5, endedAt: oct10),
              StreakRun(startedAt: oct10, endedAt: oct20),
            ],
          ),
        ],
      ),
    );
  }

  group('deleteRun', () {
    test('removes exactly the tapped run, the live streak stays', () {
      final TrackerController controller = controllerWithHistory();
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.deleteRun(
        't1',
        StreakRun(startedAt: oct10, endedAt: oct20),
      );

      final List<StreakRun> history =
          controller.value.trackers.single.history;
      expect(history, hasLength(1));
      expect(history.single.startedAt, oct5);
      expect(history.single.endedAt, oct10);
      expect(controller.value.trackers.single.startAt, oct20);
      expect(notifications, 1);
    });

    test('a run with the same start but a different end is a no-op', () {
      // The match is start AND end together: a partial match can
      // never delete the wrong tooth.
      final TrackerController controller = controllerWithHistory();
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.deleteRun(
        't1',
        StreakRun(startedAt: oct10, endedAt: oct10.add(const Duration(days: 1))),
      );

      expect(controller.value.trackers.single.history, hasLength(2));
      expect(notifications, 0);
    });

    test('an unknown tracker id is a silent no-op', () {
      final TrackerController controller = controllerWithHistory();
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.deleteRun(
        'nope',
        StreakRun(startedAt: oct5, endedAt: oct10),
      );

      expect(controller.value.trackers.single.history, hasLength(2));
      expect(notifications, 0);
    });

    test('deleting every run leaves an empty history and keeps the streak',
        () {
      final TrackerController controller = controllerWithHistory();

      controller.deleteRun('t1', StreakRun(startedAt: oct5, endedAt: oct10));
      controller.deleteRun('t1', StreakRun(startedAt: oct10, endedAt: oct20));

      expect(controller.value.trackers.single.history, isEmpty);
      expect(controller.value.trackers.single.startAt, oct20);
    });
  });

  group('moveTracker (drag reorder step)', () {
    TrackerController threeTrackers() {
      return TrackerController(
        initial: AppState(
          trackers: <Tracker>[
            Tracker(id: 'a', scene: HeroScene.peaks, startAt: oct20),
            Tracker(id: 'b', scene: HeroScene.ocean, startAt: oct20),
            Tracker(id: 'c', scene: HeroScene.forest, startAt: oct20),
          ],
        ),
      );
    }

    test('moves the card, the selection follows the selected tracker', () {
      final TrackerController controller = threeTrackers();
      controller.select(2);

      controller.moveTracker(2, 0);

      expect(
        controller.value.trackers.map((Tracker t) => t.id),
        ['c', 'a', 'b'],
      );
      // Same card selected as before the move.
      expect(controller.value.selectedIndex, 0);
      expect(
        controller.value.trackers[controller.value.selectedIndex].id,
        'c',
      );
    });

    test('moving another card keeps the selected one selected', () {
      final TrackerController controller = threeTrackers();
      controller.select(0);

      controller.moveTracker(2, 1);

      expect(
        controller.value.trackers.map((Tracker t) => t.id),
        ['a', 'c', 'b'],
      );
      expect(controller.value.selectedIndex, 0);
      expect(
        controller.value.trackers[controller.value.selectedIndex].id,
        'a',
      );
    });

    test('a move to the same slot or an invalid index is a no-op', () {
      final TrackerController controller = threeTrackers();
      controller.select(0);
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.moveTracker(0, 0);
      controller.moveTracker(9, 0);

      expect(notifications, 0);
      expect(
        controller.value.trackers.map((Tracker t) => t.id),
        ['a', 'b', 'c'],
      );
      expect(controller.value.selectedIndex, 0);
    });
  });
}
