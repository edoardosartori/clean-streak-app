import 'package:flutter_test/flutter_test.dart';

import 'package:clean_streak/features/domain/history_stats.dart';
import 'package:clean_streak/features/models/streak_run.dart';

void main() {
  final DateTime sep1 = DateTime(2026, 9, 1, 10, 0);

  group('computeHistoryStats', () {
    test('empty history: everything comes from the live streak', () {
      final HistoryStats stats = computeHistoryStats(
        history: const <StreakRun>[],
        currentStartAt: sep1,
        now: sep1.add(const Duration(days: 4, hours: 2)),
      );

      expect(stats.bestRunDays, 4);
      expect(stats.resetCount, 0);
    });

    test('closed runs add up, the best one wins over the live streak', () {
      final HistoryStats stats = computeHistoryStats(
        history: <StreakRun>[
          StreakRun(
            startedAt: sep1,
            endedAt: sep1.add(const Duration(days: 12)),
          ),
          StreakRun(
            startedAt: sep1.add(const Duration(days: 12)),
            endedAt: sep1.add(const Duration(days: 12, hours: 23)),
          ),
        ],
        currentStartAt: sep1.add(const Duration(days: 13)),
        now: sep1.add(const Duration(days: 20)),
      );

      expect(stats.bestRunDays, 12);
      expect(stats.resetCount, 2);
    });

    test('the live streak can be the best', () {
      final HistoryStats stats = computeHistoryStats(
        history: <StreakRun>[
          StreakRun(
            startedAt: sep1,
            endedAt: sep1.add(const Duration(days: 2)),
          ),
        ],
        currentStartAt: sep1.add(const Duration(days: 3)),
        now: sep1.add(const Duration(days: 30)),
      );

      expect(stats.bestRunDays, 27);
      expect(stats.resetCount, 1);
    });

    test('invalid runs (end not after start) are dropped', () {
      final HistoryStats stats = computeHistoryStats(
        history: <StreakRun>[
          StreakRun(startedAt: sep1, endedAt: sep1),
          StreakRun(
            startedAt: sep1,
            endedAt: sep1.subtract(const Duration(hours: 1)),
          ),
        ],
        currentStartAt: sep1,
        now: sep1.add(const Duration(days: 2)),
      );

      expect(stats.bestRunDays, 2);
      expect(stats.resetCount, 0);
    });
  });

  group('computeHistorySeries', () {
    test('each streak climbs from zero and drops where it closed', () {
      final List<HistorySample> series = computeHistorySeries(
        history: <StreakRun>[
          StreakRun(
            startedAt: sep1,
            endedAt: sep1.add(const Duration(days: 3)),
          ),
          StreakRun(
            startedAt: sep1.add(const Duration(days: 3)),
            endedAt: sep1.add(const Duration(days: 5)),
          ),
        ],
        currentStartAt: sep1.add(const Duration(days: 5)),
        now: sep1.add(const Duration(days: 9)),
      );

      expect(series, hasLength(6));
      void expectSample(int i, DateTime at, double daysClean) {
        expect(series[i].at, at);
        expect(series[i].daysClean, daysClean);
      }

      expectSample(0, sep1, 0);
      expectSample(1, sep1.add(const Duration(days: 3)), 3);
      expectSample(2, sep1.add(const Duration(days: 3)), 0);
      expectSample(3, sep1.add(const Duration(days: 5)), 2);
      expectSample(4, sep1.add(const Duration(days: 5)), 0);
      expectSample(5, sep1.add(const Duration(days: 9)), 4);
    });

    test('unsorted runs come back chronological', () {
      final DateTime aug1 = DateTime(2026, 8, 1);
      final DateTime aug4 = DateTime(2026, 8, 4);
      final List<HistorySample> series = computeHistorySeries(
        history: <StreakRun>[
          StreakRun(
              startedAt: aug4, endedAt: aug4.add(const Duration(days: 2))),
          StreakRun(startedAt: aug1, endedAt: aug4),
        ],
        currentStartAt: aug4.add(const Duration(days: 2)),
        now: aug4.add(const Duration(days: 6)),
      );

      expect(series.first.at, aug1);
      expect(series.first.daysClean, 0);
      expect(series.last.at, aug4.add(const Duration(days: 6)));
      expect(series.last.daysClean, 4);
    });

    test('clock never past the start: only the runs are drawn', () {
      final List<HistorySample> series = computeHistorySeries(
        history: const <StreakRun>[],
        currentStartAt: sep1,
        now: sep1.subtract(const Duration(days: 1)),
      );

      expect(series, isEmpty);
    });
  });

  group('correctedHistory', () {
    // The user's examples (today = Oct 30, 2026).
    final DateTime oct5 = DateTime(2026, 10, 5);
    final DateTime oct8 = DateTime(2026, 10, 8);
    final DateTime oct10 = DateTime(2026, 10, 10);
    final DateTime oct20 = DateTime(2026, 10, 20);
    final DateTime oct25 = DateTime(2026, 10, 25); // 5 days ago
    final DateTime oct27 = DateTime(2026, 10, 27); // 3 days ago
    final DateTime oct30 = DateTime(2026, 10, 30); // today

    test('rule 1: a streak of 5 days corrected to 3 days ago closes into 2',
        () {
      final List<StreakRun> history = correctedHistory(
        history: const <StreakRun>[],
        previousStartAt: oct25,
        newStartAt: oct27,
      );

      expect(history, hasLength(1));
      expect(history.single.startedAt, oct25);
      expect(history.single.endedAt, oct27);
      expect(history.single.wholeDays, 2);
    });

    test('rule 1 on a closed run: 5 days become 2, ending at the new start',
        () {
      // The run was closed too late (it ends today); the relapse
      // set to 3 days ago lands inside it: the credible days
      // before the relapse stay, the run ends where the 3 days
      // begin.
      final List<StreakRun> history = correctedHistory(
        history: <StreakRun>[
          StreakRun(startedAt: oct25, endedAt: oct30),
        ],
        previousStartAt: oct30,
        newStartAt: oct27,
      );

      expect(history, hasLength(1));
      expect(history.single.startedAt, oct25);
      expect(history.single.endedAt, oct27);
      expect(history.single.wholeDays, 2);
    });

    test('rule 2: a 3 day streak reset to 5 days ago vanishes', () {
      final List<StreakRun> history = correctedHistory(
        history: const <StreakRun>[],
        previousStartAt: oct27,
        newStartAt: oct25,
      );

      expect(history, isEmpty);
    });

    test('rule 2 on a closed run: a run inside the correction goes', () {
      // The run [Oct 27 -> today] sits entirely inside the
      // corrected streak [Oct 25 -> now]: not credible, gone.
      final List<StreakRun> history = correctedHistory(
        history: <StreakRun>[
          StreakRun(startedAt: oct27, endedAt: oct30),
        ],
        previousStartAt: oct30,
        newStartAt: oct25,
      );

      expect(history, isEmpty);
    });

    test('runs that ended before the correction stay (the teeth)', () {
      final List<StreakRun> history = correctedHistory(
        history: <StreakRun>[
          StreakRun(
              startedAt: sep1, endedAt: sep1.add(const Duration(days: 4))),
        ],
        previousStartAt: oct30,
        newStartAt: oct27,
      );

      expect(history, hasLength(1));
      expect(history.single.startedAt, sep1);
    });

    test('a run ending exactly at the new start stays', () {
      final List<StreakRun> history = correctedHistory(
        history: <StreakRun>[
          StreakRun(startedAt: oct5, endedAt: oct27),
        ],
        previousStartAt: oct30,
        newStartAt: oct27,
      );

      expect(history, hasLength(1));
      expect(history.single.endedAt, oct27);
    });

    test('a stale run covered by the closing run is shortened to it', () {
      // Forward move over a stale record: the stale run ends after
      // the old start, so its credible days are only the ones
      // before it — then the closing run takes over.
      final List<StreakRun> history = correctedHistory(
        history: <StreakRun>[
          StreakRun(startedAt: oct5, endedAt: oct10),
        ],
        previousStartAt: oct8,
        newStartAt: oct20,
      );

      expect(history, hasLength(2));
      expect(history[0].startedAt, oct5);
      expect(history[0].endedAt, oct8);
      expect(history[1].startedAt, oct8);
      expect(history[1].endedAt, oct20);
    });

    test('rule 1 end to end: a 2 day tooth and a 3 day live streak', () {
      final List<StreakRun> history = correctedHistory(
        history: <StreakRun>[
          StreakRun(startedAt: oct25, endedAt: oct30),
        ],
        previousStartAt: oct30,
        newStartAt: oct27,
      );

      final HistoryStats stats = computeHistoryStats(
        history: history,
        currentStartAt: oct27,
        now: oct30,
      );

      expect(stats.bestRunDays, 3);
      expect(stats.resetCount, 1);
    });
  });
}
