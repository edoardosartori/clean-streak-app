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
}
