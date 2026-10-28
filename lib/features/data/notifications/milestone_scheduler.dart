import '../../domain/milestone_notification_planner.dart';

/// System milestone notifications (Step 4d).
///
/// The controller mirrors every data mutation to the scheduler
/// fire-and-forget, exactly like the repository. The plan is
/// always the full desired state, so re-applying it is idempotent:
/// stale pending notifications are cancelled and the rest is
/// overwritten thanks to the deterministic ids.
abstract class MilestoneScheduler {
  /// Applies [plan]: cancels everything that is no longer wanted
  /// (including the milestones that fired while the app was
  /// closed), then (re)schedules every upcoming milestone.
  Future<void> apply(MilestoneNotificationPlan plan);

  /// Asks for POST_NOTIFICATIONS once, on the first run after the
  /// update. If denied it is never asked again: the app keeps
  /// working identically, the in-app celebrations do not need it.
  Future<void> requestPermissionIfNeeded();

  /// The tracker id of the notification that cold-started the app
  /// (null on a normal launch), so the home opens on that card.
  Future<String?> launchTrackerId();

  /// Called when the user taps a milestone notification while the
  /// app is running (foreground or background). The portrait layout
  /// registers itself here to select the card.
  set onTrackerTapped(void Function(String trackerId)? handler);
}

/// Drops every plan and never prompts: used when the plugin cannot
/// be initialized. Everything else keeps working.
class NoopMilestoneScheduler implements MilestoneScheduler {
  @override
  Future<void> apply(MilestoneNotificationPlan plan) async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<String?> launchTrackerId() async => null;

  @override
  set onTrackerTapped(void Function(String trackerId)? handler) {}
}
