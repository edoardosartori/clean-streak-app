import 'package:hive_ce/hive_ce.dart';

import '../../models/tracker.dart';
import '../tracker_repository.dart';
import 'tracker_codec.dart';

/// Hive CE implementation of [TrackerRepository].
///
/// One box, one record per tracker (key = tracker id); a save on
/// an existing id overwrites in place, so edits never move a tab.
/// The tab order lives in an explicit order record (key
/// [_orderKey]): Hive never rewrites the position of an existing
/// key — a clear followed by re-puts puts every key back in its
/// old slot — so the order cannot rely on the box insertion
/// order. The record is written by [reorderTrackers] and applied
/// by [loadTrackers], which falls back to the box order for the
/// trackers the record does not cover (old installs, brand new
/// trackers). The order record is a non-tracker record: the codec
/// skips it (no id/scene/startAt). The box is injected, so tests
/// run on a real in-memory Hive box with a temp directory.
class HiveTrackerRepository implements TrackerRepository {
  HiveTrackerRepository({required Box<Map> box}) : _box = box;

  static const String boxName = 'trackers';

  /// Key of the order record: {'ids': [the ids in tab order]}.
  static const String _orderKey = '__order__';

  final Box<Map> _box;

  @override
  Future<List<Tracker>> loadTrackers() async {
    final Map<String, Tracker> byId = <String, Tracker>{};
    for (final dynamic raw in _box.values) {
      if (raw is Map) {
        final Tracker? tracker = trackerFromMap(raw);
        if (tracker != null) {
          byId[tracker.id] = tracker;
        }
      }
    }
    // Tab order: the order record first, then whatever it does
    // not cover, in box order (insertion order of the map above).
    final List<Tracker> ordered = <Tracker>[];
    for (final String id in _storedOrder()) {
      final Tracker? tracker = byId.remove(id);
      if (tracker != null) {
        ordered.add(tracker);
      }
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  @override
  Future<void> saveTracker(Tracker tracker) =>
      _box.put(tracker.id, trackerToMap(tracker));

  @override
  Future<void> deleteTracker(String id) => _box.delete(id);

  @override
  Future<void> reorderTrackers(List<String> orderedIds) async {
    // Defensive: the new order must be exactly the stored tracker
    // ids (same count, no unknown id, no duplicate). Anything else
    // would reorder the wrong thing, so it stays a silent no-op.
    final Set<String> stored =
        _box.keys.toSet().cast<String>()..remove(_orderKey);
    if (stored.length != orderedIds.length) {
      return;
    }
    for (final String id in orderedIds) {
      if (!stored.contains(id)) {
        return;
      }
    }
    await _box.put(_orderKey, <String, dynamic>{'ids': orderedIds});
  }

  /// The stored order record, empty when there is none (old
  /// installs and brand new boxes: pure box order).
  List<String> _storedOrder() {
    final dynamic raw = _box.get(_orderKey);
    if (raw is Map) {
      final dynamic ids = raw['ids'];
      if (ids is List) {
        return <String>[
          for (final dynamic id in ids)
            if (id is String) id,
        ];
      }
    }
    return const <String>[];
  }
}
