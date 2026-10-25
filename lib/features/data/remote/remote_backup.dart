import '../../models/tracker.dart';

/// Step 5 placeholder: online backup / sync between the user's
/// own devices (no multi-user, no community, no social auth).
/// The backend (Firebase anonymous + Firestore, Supabase, or a
/// Google Drive file backup) is decided in step 5; the interface
/// is shaped so nothing here has to be redone.
abstract interface class TrackerBackupService {
  /// Uploads the current trackers (full snapshot, last write wins).
  Future<void> pushSnapshot(List<Tracker> trackers);

  /// Downloads the last backed up snapshot, or null when the
  /// backend has nothing for this user yet.
  Future<List<Tracker>?> pullSnapshot();
}

/// Safe to inject anywhere: every call is a no-op.
class NoopTrackerBackupService implements TrackerBackupService {
  const NoopTrackerBackupService();

  @override
  Future<void> pushSnapshot(List<Tracker> trackers) async {}

  @override
  Future<List<Tracker>?> pullSnapshot() async => null;
}
