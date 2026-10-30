import '../models/tracker.dart';

/// Persistence boundary for the trackers.
///
/// The UI never touches storage directly: [TrackerController]
/// mirrors every data mutation here. `data/local/` holds the Hive
/// implementation, `data/remote/` the step 5 backup/sync stub.
abstract interface class TrackerRepository {
  /// All saved trackers in tab order (the explicit order record
  /// written by [reorderTrackers], falling back to the storage
  /// insertion order for the trackers it does not cover).
  Future<List<Tracker>> loadTrackers();

  /// Inserts or overwrites the tracker with the same id.
  Future<void> saveTracker(Tracker tracker);

  /// Removes the tracker, no-op when the id is unknown.
  Future<void> deleteTracker(String id);

  /// Rewrites the tab order (drag reorder step). [orderedIds] is
  /// the COMPLETE id list in the new order: when it does not match
  /// the stored ids exactly (count, unknown id, duplicate) the
  /// call is a silent no-op, so a bad list can never destroy
  /// records.
  Future<void> reorderTrackers(List<String> orderedIds);
}
