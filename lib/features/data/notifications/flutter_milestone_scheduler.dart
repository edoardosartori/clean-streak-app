import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/milestone_notification_planner.dart';
import 'milestone_scheduler.dart';

/// [MilestoneScheduler] on top of flutter_local_notifications.
///
/// Setup performed by [create]:
/// - timezone database + device location (zonedSchedule needs a
///   TZDateTime)
/// - plugin initialization, with the tap callback routed to
///   [onTrackerTapped] (the payload is the tracker id)
///
/// Foreground behaviour: nothing to configure on Android. When the
/// app is open the 1 s tick queues the in-app celebration and the
/// marking save re-applies the plan, which cancels the fired
/// notification within the same second.
class FlutterMilestoneScheduler implements MilestoneScheduler {
  FlutterMilestoneScheduler._(this._plugin, this._preferences);

  static const String _channelId = 'milestones';
  static const String _channelName = 'Milestones';
  static const String _channelDescription = 'Milestone notifications';
  static const String _permissionRequestedKey =
      'milestone_notifications_permission_requested';

  /// White silhouette drawable: the status bar renders the alpha
  /// channel only, so the launcher mipmap would be a white square.
  static const String _icon = '@drawable/ic_notification';

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _preferences;

  void Function(String trackerId)? _onTrackerTapped;

  static Future<FlutterMilestoneScheduler> create({
    required SharedPreferences preferences,
  }) async {
    // Timezone database + device location.
    tz.initializeTimeZones();
    final TimezoneInfo localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    final FlutterMilestoneScheduler scheduler =
        FlutterMilestoneScheduler._(plugin, preferences);
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: scheduler._onNotificationResponse,
    );
    return scheduler;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _onTrackerTapped?.call(payload);
    }
  }

  @override
  set onTrackerTapped(void Function(String trackerId)? handler) {
    _onTrackerTapped = handler;
  }

  @override
  Future<void> apply(MilestoneNotificationPlan plan) async {
    // 1. Cancel what is no longer scheduled: deleted cards, and
    //    the pending dates of reset/relapsed cards (the wanted ids
    //    are overwritten right after).
    final Set<int> wanted = <int>{
      for (final MilestoneNotification n in plan.toSchedule) n.id
    };
    final List<PendingNotificationRequest> pending =
        await _plugin.pendingNotificationRequests();
    for (final PendingNotificationRequest request in pending) {
      if (!wanted.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    // 2. Cancel the milestones that already fired while the app
    //    was closed: the in-app celebrations cover them.
    for (final int id in plan.toCancel) {
      await _plugin.cancel(id: id);
    }

    // 3. (Re)schedule: same id = overwrite, never a duplicate.
    final AndroidScheduleMode scheduleMode = await _resolveScheduleMode();
    for (final MilestoneNotification notification in plan.toSchedule) {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(notification.fireAt, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: scheduleMode,
        payload: notification.trackerId,
      );
    }
  }

  @override
  Future<void> requestPermissionIfNeeded() async {
    if (_preferences.getBool(_permissionRequestedKey) ?? false) {
      return;
    }
    // Flag first: a denial must never trigger a second prompt.
    await _preferences.setBool(_permissionRequestedKey, true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<String?> launchTrackerId() async {
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    final String? payload = details.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    return payload;
  }

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// USE_EXACT_ALARM is declared in the manifest and granted with
  /// the install, so exact alarms are the default. If the platform
  /// ever reports otherwise, fall back silently to inexact: a
  /// slightly late notification beats no notification.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final bool? canExact = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.canScheduleExactNotifications();
    return (canExact ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
