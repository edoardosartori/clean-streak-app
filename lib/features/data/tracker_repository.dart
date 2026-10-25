import '../models/tracker.dart';

/// Persistence boundary for the trackers.
///
/// The UI never touches storage directly: [TrackerController]
/// mirrors every data mutation here. `data/local/` holds the Hive
/// implementation, `data/remote/` the step 5 backup/sync stub.
abstract interface class TrackerRepository {
  /// All saved trackers in tab order (box insertion order).
  Future<List<Tracker>> loadTrackers();

  /// Inserts or overwrites the tracker with the same id.
  Future<void> saveTracker(Tracker tracker);

  /// Removes the tracker, no-op when the id is unknown.
  Future<void> deleteTracker(String id);
}
