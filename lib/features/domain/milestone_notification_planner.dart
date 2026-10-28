import '../models/tracker.dart';
import 'milestone_engine.dart';

/// One planned system notification: a future milestone of a card.
class MilestoneNotification {
  const MilestoneNotification({
    required this.id,
    required this.trackerId,
    required this.milestoneId,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  /// Stable Android notification id derived from the pair
  /// (tracker id, milestone id). The same pair always maps to the
  /// same id: re-applying a plan overwrites schedules instead of
  /// duplicating them.
  final int id;

  final String trackerId;
  final String milestoneId;

  /// "1 day!" - the same headline the in-app celebration shows.
  final String title;

  /// "Milestone reached · `<card name>`" (or "Timer" when unnamed).
  final String body;

  /// Device-local wall-clock moment the notification fires at.
  final DateTime fireAt;
}

/// The full desired state of the system notifications.
class MilestoneNotificationPlan {
  const MilestoneNotificationPlan({
    required this.toSchedule,
    required this.toCancel,
  });

  /// Every upcoming milestone of every card.
  final List<MilestoneNotification> toSchedule;

  /// Ids of the milestones already passed: they fired while the
  /// app was closed and their tray entries are removed as soon as
  /// the plan is re-applied, because the in-app celebrations cover
  /// them.
  final Set<int> toCancel;
}

/// Pure planning: cards in, plan out. No plugin, no side effects,
/// fully testable. The scheduler layer applies the plan.
class MilestoneNotificationPlanner {
  MilestoneNotificationPlanner({MilestoneEngine? engine})
      : engine = engine ?? MilestoneEngine();

  final MilestoneEngine engine;

  /// Safety margin over the engine default: the whole catalog must
  /// fit in one plan even for a card started right now.
  static const int _maxPerCard = 50;

  /// Deterministic int32 id for a (tracker, milestone) pair.
  static int notificationIdFor(String trackerId, String milestoneId) =>
      Object.hash(trackerId, milestoneId) & 0x7FFFFFFF;

  MilestoneNotificationPlan planFor(
    List<Tracker> trackers, {
    DateTime? at,
  }) {
    final List<MilestoneNotification> toSchedule = <MilestoneNotification>[];
    final Set<int> toCancel = <int>{};

    for (final Tracker tracker in trackers) {
      for (final MilestoneUpcoming upcoming in engine.upcoming(
        startAt: tracker.startAt,
        disabledMilestones: tracker.disabledMilestones,
        count: _maxPerCard,
        at: at,
      )) {
        toSchedule.add(
          MilestoneNotification(
            id: notificationIdFor(tracker.id, upcoming.definition.id),
            trackerId: tracker.id,
            milestoneId: upcoming.definition.id,
            title: '${upcoming.definition.label}!',
            body: 'Milestone reached! · ${tracker.name ?? 'Timer'}',
            fireAt: upcoming.targetDate,
          ),
        );
      }
      for (final MilestoneReached reached in engine.reached(
        startAt: tracker.startAt,
        disabledMilestones: tracker.disabledMilestones,
        at: at,
      )) {
        toCancel.add(notificationIdFor(tracker.id, reached.definition.id));
      }
    }

    return MilestoneNotificationPlan(
      toSchedule: toSchedule,
      toCancel: toCancel,
    );
  }
}
