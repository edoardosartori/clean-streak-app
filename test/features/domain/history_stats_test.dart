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
      expect(stats.totalCleanDays, 4);
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
      expect(stats.totalCleanDays, 19);
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
      expect(stats.totalCleanDays, 29);
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
      expect(stats.totalCleanDays, 2);
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
          StreakRun(startedAt: aug4, endedAt: aug4.add(const Duration(days: 2))),
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
}
