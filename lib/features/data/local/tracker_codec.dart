import '../../models/tracker.dart';

/// Manual (no codegen) Hive serialization: one map per tracker,
/// stored under the tracker id. The field names are a private
/// format: changing them is a migration. The reader stays
/// defensive on purpose: a malformed record is skipped instead
/// of crashing the boot; an unknown glyph name degrades to "no
/// glyph" instead of dropping the whole tracker. Records saved
/// before the celebration step have no 'celebratedMilestones'
/// key: they load with an empty set.

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

  return Tracker(
    id: id,
    name: name,
    glyph: glyph,
    scene: scene,
    startAt: startAt,
    disabledMilestones: disabledMilestones,
    celebratedMilestones: celebratedMilestones,
  );
}
