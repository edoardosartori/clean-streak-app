import '../../models/streak_run.dart';
import '../../models/tracker.dart';

/// Manual (no codegen) Hive serialization: one map per tracker,
/// stored under the tracker id. The field names are a private
/// format: changing them is a migration. The reader stays
/// defensive on purpose: a malformed record is skipped instead
/// of crashing the boot; an unknown glyph name degrades to "no
/// glyph" instead of dropping the whole tracker. Records saved
/// before the celebration step have no 'celebratedMilestones'
/// key and records saved before the history step have no
/// 'history' key: they load with an empty set / empty list. The
/// Drive backup uses the same map, so the history travels with
/// every backup for free and old backups restore fine.

Map<String, dynamic> trackerToMap(Tracker tracker) {
  return <String, dynamic>{
    'id': tracker.id,
    'name': tracker.name,
    'glyph': tracker.glyph?.name,
    'scene': tracker.scene.name,
    'startAt': tracker.startAt.toIso8601String(),
    'disabledMilestones': tracker.disabledMilestones.toList(
      growable: false,
    ),
    'celebratedMilestones': tracker.celebratedMilestones.toList(
      growable: false,
    ),
    'history': <Map<String, String>>[
      for (final StreakRun run in tracker.history)
        <String, String>{
          'startedAt': run.startedAt.toIso8601String(),
          'endedAt': run.endedAt.toIso8601String(),
        },
    ],
  };
}

/// Decodes one stored record. Returns null when the record is
/// malformed (missing or invalid id, scene or startAt): the
/// caller skips it and keeps loading the rest.
Tracker? trackerFromMap(Map<dynamic, dynamic> map) {
  final dynamic id = map['id'];
  if (id is! String || id.isEmpty) {
    return null;
  }

  final dynamic sceneName = map['scene'];
  final dynamic startAtValue = map['startAt'];
  if (sceneName is! String || startAtValue is! String) {
    return null;
  }
  final HeroScene? scene = HeroScene.values.asNameMap()[sceneName];
  final DateTime? startAt = DateTime.tryParse(startAtValue);
  if (scene == null || startAt == null) {
    return null;
  }

  TimerGlyphId? glyph;
  final dynamic glyphName = map['glyph'];
  if (glyphName is String) {
    glyph = TimerGlyphId.values.asNameMap()[glyphName];
  }

  String? name;
  final dynamic storedName = map['name'];
  if (storedName is String && storedName.isNotEmpty) {
    name = storedName;
  }

  final Set<String> disabledMilestones = <String>{
    for (final dynamic milestoneId
        in map['disabledMilestones'] as List<dynamic>? ?? const <dynamic>[])
      if (milestoneId is String) milestoneId,
  };

  final Set<String> celebratedMilestones = <String>{
    for (final dynamic celebratedId
        in map['celebratedMilestones'] as List<dynamic>? ?? const <dynamic>[])
      if (celebratedId is String) celebratedId,
  };

  // History (history step): every malformed entry is skipped, a
  // run that does not end after it starts is dropped. A record
  // without the key (or with a non-list value) loads empty.
  final List<StreakRun> history = <StreakRun>[];
  final dynamic storedHistory = map['history'];
  if (storedHistory is List<dynamic>) {
    for (final dynamic entry in storedHistory) {
      if (entry is Map<dynamic, dynamic>) {
        final dynamic runStart = entry['startedAt'];
        final dynamic runEnd = entry['endedAt'];
        if (runStart is String && runEnd is String) {
          final DateTime? startedAt = DateTime.tryParse(runStart);
          final DateTime? endedAt = DateTime.tryParse(runEnd);
          if (startedAt != null &&
              endedAt != null &&
              endedAt.isAfter(startedAt)) {
            history.add(StreakRun(startedAt: startedAt, endedAt: endedAt));
          }
        }
      }
    }
  }

  return Tracker(
    id: id,
    name: name,
    glyph: glyph,
    scene: scene,
    startAt: startAt,
    disabledMilestones: disabledMilestones,
    celebratedMilestones: celebratedMilestones,
    history: history,
  );
}
