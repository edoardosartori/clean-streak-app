import 'package:clean_streak/features/domain/milestone_catalog.dart';
import 'package:clean_streak/features/domain/milestone_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final MilestoneEngine engine = MilestoneEngine();
  final DateTime start = DateTime(2026, 10, 12, 20, 47);
  final DateTime now = DateTime(2026, 10, 16, 20, 47); // 4 days in

  group('MilestoneCatalog', () {
    test('fixed ids in order', () {
      expect(
        MilestoneCatalog.fixed.map((m) => m.id).toList(),
        ['1d', '2d', '3d', '7d', '1m', '2m', '3m', '6m', '9m', '1y'],
      );
    });

    test('recurring half-year series is lazy and non-disable-able', () {
      final List<MilestoneDefinition> tail =
          MilestoneCatalog.ordered().skip(10).take(4).toList();
      expect(tail.map((m) => m.id).toList(), ['1.5y', '2y', '2.5y', '3y']);
      expect(tail.every((m) => !m.canDisable), isTrue);
      expect(MilestoneCatalog.fixed.every((m) => m.canDisable), isTrue);
    });

    test('labels', () {
      MilestoneDefinition byId(String id) =>
          MilestoneCatalog.fixed.firstWhere((m) => m.id == id);
      expect(byId('1d').label, '1 day');
      expect(byId('7d').label, '7 days');
      expect(byId('1m').label, '1 month');
      expect(byId('9m').label, '9 months');
      expect(byId('1y').label, '1 year');
      expect(MilestoneCatalog.ordered().elementAt(10).label, '1.5 years');
    });
  });

  group('MilestoneEngine.snapshot', () {
    test('four-day streak: reached 3d, current 7d, next 1m', () {
      final s = engine.snapshot(startAt: start, at: now);
      expect(s.lastReached!.definition.id, '3d');
      expect(s.lastReached!.reachedAt, DateTime(2026, 10, 15, 20, 47));
      expect(s.current!.definition.id, '7d');
      expect(s.current!.targetDate, DateTime(2026, 10, 19, 20, 47));
      expect(s.current!.progress, closeTo(4 / 7, 0.0001));
      expect(s.current!.remaining, const Duration(days: 3));
      expect(s.next!.definition.id, '1m');
      expect(s.next!.targetDate, DateTime(2026, 11, 12, 20, 47));
    });

    test('streak under one day: nothing reached yet', () {
      final s = engine.snapshot(
        startAt: start,
        at: start.add(const Duration(hours: 12)),
      );
      expect(s.lastReached, isNull);
      expect(s.current!.definition.id, '1d');
      expect(s.next!.definition.id, '2d');
    });

    test('disabled milestones are skipped (2d off does not affect 3d)', () {
      final s = engine.snapshot(
        startAt: start,
        disabledMilestones: {'2d'},
        at: now,
      );
      expect(s.lastReached!.definition.id, '3d');
      expect(s.current!.definition.id, '7d');
      expect(s.next!.definition.id, '1m');
    });

    test('disabling the current milestone shifts focus forward', () {
      final s = engine.snapshot(
        startAt: start,
        disabledMilestones: {'7d'},
        at: now,
      );
      expect(s.current!.definition.id, '1m');
      expect(s.next!.definition.id, '2m');
    });

    test('half-year milestones cannot be disabled', () {
      final s = engine.snapshot(
        startAt: start,
        disabledMilestones: {'1.5y', '2y'},
        at: start.add(const Duration(days: 400)),
      );
      expect(s.current!.definition.id, '1.5y');
      expect(s.current!.targetDate, DateTime(2028, 4, 12, 20, 47));
      expect(s.next!.definition.id, '2y');
      expect(s.next!.targetDate, DateTime(2028, 10, 12, 20, 47));
    });

    test('month-end clamp: 1m from Jan 31 lands on Feb 28', () {
      final s = engine.snapshot(
        startAt: DateTime(2027, 1, 31, 9, 0),
        disabledMilestones: {'1d', '2d', '3d', '7d'},
        at: DateTime(2027, 2, 10, 9, 0),
      );
      expect(s.current!.definition.id, '1m');
      expect(s.current!.targetDate, DateTime(2027, 2, 28, 9, 0));
    });
  });

  group('MilestoneEngine.upcoming', () {
    test('returns the next active milestones, skipping disabled', () {
      final u = engine.upcoming(
        startAt: start,
        disabledMilestones: {'2d'},
        count: 3,
        at: now,
      );
      expect(u.map((m) => m.definition.id).toList(), ['7d', '1m', '2m']);
    });

    test('keeps half-year milestones even if "disabled"', () {
      final u = engine.upcoming(
        startAt: start,
        disabledMilestones: {'1.5y', '1m', '2m', '3m', '6m', '9m', '1y'},
        count: 4,
        at: now,
      );
      expect(
          u.map((m) => m.definition.id).toList(), ['7d', '1.5y', '2y', '2.5y']);
    });
  });

  group('MilestoneEngine.reached', () {
    test('four-day streak: 1d, 2d, 3d chronologically', () {
      final List<MilestoneReached> r = engine.reached(startAt: start, at: now);
      expect(r.map((m) => m.definition.id).toList(), ['1d', '2d', '3d']);
      expect(r.first.reachedAt, DateTime(2026, 10, 13, 20, 47));
      expect(r.last.reachedAt, DateTime(2026, 10, 15, 20, 47));
    });

    test('nothing reached before the first day', () {
      expect(
        engine.reached(
          startAt: start,
          at: start.add(const Duration(hours: 12)),
        ),
        isEmpty,
      );
    });

    test('disabled milestones are skipped, half-years kept', () {
      // ~700 days in: past 1.5y, not yet 2y.
      final List<MilestoneReached> r = engine.reached(
        startAt: start,
        disabledMilestones: {'2d', '1.5y'},
        at: DateTime(2028, 9, 11, 20, 47),
      );
      final List<String> ids = r.map((m) => m.definition.id).toList();
      expect(ids.contains('2d'), isFalse);
      expect(ids.contains('1.5y'), isTrue);
      expect(ids.last, '1.5y');
    });
  });
}
