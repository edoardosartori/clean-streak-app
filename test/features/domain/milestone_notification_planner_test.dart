import 'package:clean_streak/features/domain/milestone_catalog.dart';
import 'package:clean_streak/features/domain/milestone_notification_planner.dart';
import 'package:clean_streak/features/models/tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime start = DateTime(2026, 10, 12, 20, 47);
  final DateTime now = DateTime(2026, 10, 16, 20, 47);

  final MilestoneNotificationPlanner planner = MilestoneNotificationPlanner();

  Tracker tracker({
    String id = 't1',
    String? name,
    DateTime? startAt,
    Set<String> disabled = const {},
  }) {
    return Tracker(
      id: id,
      scene: HeroScene.peaks,
      startAt: startAt ?? start,
      name: name,
      disabledMilestones: disabled,
    );
  }

  group('MilestoneNotificationPlanner.planFor', () {
    test('fresh card: the day milestone is scheduled at +24h', () {
      final MilestoneNotificationPlan plan =
          planner.planFor(<Tracker>[tracker(startAt: now)], at: now);

      final MilestoneNotification first = plan.toSchedule.first;
      final String dayLabel = MilestoneCatalog.ordered()
          .firstWhere((MilestoneDefinition m) => m.id == '1d')
          .label;

      expect(first.trackerId, 't1');
      expect(first.milestoneId, '1d');
      expect(first.fireAt, now.add(const Duration(hours: 24)));
      expect(first.title, '$dayLabel!');
      expect(first.body, 'Milestone reached! · Timer');
      expect(plan.toCancel, isEmpty);
    });

    test('reached milestones are cancelled, upcoming scheduled', () {
      // 4-day streak: 1d, 2d and 3d have passed (no 4d milestone).
      final MilestoneNotificationPlan plan =
          planner.planFor(<Tracker>[tracker()], at: now);

      expect(
        plan.toCancel,
        <int>{
          for (final String m in const <String>['1d', '2d', '3d'])
            MilestoneNotificationPlanner.notificationIdFor('t1', m),
        },
      );
      for (final MilestoneNotification n in plan.toSchedule) {
        expect(n.fireAt.isAfter(now), isTrue);
        expect(plan.toCancel.contains(n.id), isFalse);
      }
    });

    test('disabled milestones are not scheduled', () {
      final MilestoneNotificationPlan plan = planner.planFor(
        <Tracker>[
          tracker(startAt: now, disabled: const <String>{'1d', '2d'})
        ],
        at: now,
      );

      final List<String> ids = plan.toSchedule
          .map((MilestoneNotification n) => n.milestoneId)
          .toList();
      expect(ids, isNot(contains('1d')));
      expect(ids, isNot(contains('2d')));
    });

    test('named cards carry their name in the body', () {
      final MilestoneNotificationPlan plan =
          planner.planFor(<Tracker>[tracker(name: 'Water')], at: now);

      expect(
        plan.toSchedule.first.body,
        'Milestone reached! · Water',
      );
    });

    test('ids are deterministic and never shared between cards', () {
      final MilestoneNotificationPlan a =
          planner.planFor(<Tracker>[tracker()], at: now);
      final MilestoneNotificationPlan b =
          planner.planFor(<Tracker>[tracker()], at: now);

      expect(
        a.toSchedule.map((MilestoneNotification n) => n.id).toList(),
        b.toSchedule.map((MilestoneNotification n) => n.id).toList(),
      );
      expect(
        MilestoneNotificationPlanner.notificationIdFor('t1', '1d'),
        isNot(MilestoneNotificationPlanner.notificationIdFor('t2', '1d')),
      );
    });

    test('two cards: same shape, separate ids', () {
      final MilestoneNotificationPlan plan = planner.planFor(
        <Tracker>[
          tracker(id: 't1', startAt: now),
          tracker(id: 't2', startAt: now)
        ],
        at: now,
      );

      final int perCard = plan.toSchedule
          .where((MilestoneNotification n) => n.trackerId == 't1')
          .length;
      expect(
        plan.toSchedule
            .where((MilestoneNotification n) => n.trackerId == 't2')
            .length,
        perCard,
      );
      expect(
        plan.toSchedule.map((MilestoneNotification n) => n.id).toSet().length,
        plan.toSchedule.length,
      );
    });
  });
}
