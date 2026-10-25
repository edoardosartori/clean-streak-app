import 'package:hive_ce/hive_ce.dart';

import '../../models/tracker.dart';
import '../tracker_repository.dart';
import 'tracker_codec.dart';

/// Hive CE implementation of [TrackerRepository].
///
/// One box, one record per tracker (key = tracker id). The box
/// keeps insertion order, which is the tab order; a save on an
/// existing id overwrites in place, so edits never move a tab.
/// The box is injected, so tests run on a real in-memory Hive
/// box with a temp directory.
class HiveTrackerRepository implements TrackerRepository {
  HiveTrackerRepository({required Box<Map> box}) : _box = box;

  static const String boxName = 'trackers';

  final Box<Map> _box;

  @override
  Future<List<Tracker>> loadTrackers() async {
    final List<Tracker> trackers = <Tracker>[];
    for (final dynamic raw in _box.values) {
      if (raw is Map) {
        final Tracker? tracker = trackerFromMap(raw);
        if (tracker != null) {
          trackers.add(tracker);
        }
      }
    }
    return trackers;
  }

  @override
  Future<void> saveTracker(Tracker tracker) =>
      _box.put(tracker.id, trackerToMap(tracker));

  @override
  Future<void> deleteTracker(String id) => _box.delete(id);
}
