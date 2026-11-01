import 'package:flutter/foundation.dart';

import '../../models/tracker.dart';

/// Online backup boundary (step 5): a whole-snapshot backup of
/// the trackers in the user's private Google Drive App Data
/// folder. Not a sync: the last write wins and the restore is a
/// full local replacement.
///
/// A ChangeNotifier so the top bar cloud chip and the backup
/// sheet rebuild when the sign-in state changes. Until the user
/// signs in manually once, the wired implementation is the Noop
/// below: the OAuth flow always starts with a user tap, it can
/// never be forced by the app.
abstract class TrackerBackupService extends ChangeNotifier {
  /// Whether an account is signed in and the auto-backup mirror
  /// is active.
  bool get isSignedIn;

  /// Email of the signed-in account (null until sign-in).
  String? get accountEmail;

  /// When the last successful upload finished (null = never in
  /// this install).
  DateTime? get lastBackupAt;

  /// Timers stored in the last successful upload.
  int get storedTrackerCount;

  /// True while a manual operation (sign-in, backup, restore)
  /// is running: the sheet disables its buttons.
  bool get isBusy;

  /// Interactive sign-in (account picker + Drive App Data
  /// consent). Returns false when the user cancels the picker;
  /// throws [DriveBackupException] when something really failed.
  Future<bool> signIn();

  /// Best-effort silent restore of a previous session: the
  /// backup sheet calls it when it opens, so the app never pops
  /// an account picker unasked (e.g. at startup). A canceled or
  /// failed restore is not an error.
  Future<void> restoreSessionSilently();

  Future<void> signOut();

  /// Silent upload of the full snapshot, last write wins. Never
  /// throws and never shows any UI: the automatic mirror uses
  /// this after every mutation. False when not signed in or
  /// when the silent authorization fails (the manual button
  /// shows the error).
  Future<bool> pushSnapshot(List<Tracker> trackers);

  /// Manual, user-initiated backup ("Back up now"): unlike
  /// [pushSnapshot] this may show the Drive consent prompt when
  /// the authorization is missing, or when the cached token has
  /// gone stale (revoked from the account settings). A prompt
  /// always starts from a user tap, so the automatic mirror must
  /// use [pushSnapshot] instead.
  Future<bool> backupNow(List<Tracker> trackers);

  /// Technical details of the last failed [pushSnapshot] or
  /// [backupNow] (null after a successful one): the backup sheet
  /// shows them on "Show error details".
  String? get lastPushErrorDetails;

  /// Downloads and decodes the snapshot, or null when Drive has
  /// nothing stored yet. Throws [DriveBackupException] on
  /// failure: it only runs from manual actions, so it may show
  /// the consent prompt when the authorization is missing or
  /// stale.
  Future<List<Tracker>?> pullSnapshot();
}

/// Failure with a user-facing message.
class DriveBackupException implements Exception {
  const DriveBackupException(
    this.message, {
    this.details,
    this.statusCode,
  });

  final String message;

  /// Technical cause of the failure (real exception, HTTP
  /// status, response body). Not user-facing: the sheet shows
  /// it only on "Show error details".
  final String? details;

  /// HTTP status of the failed Drive request, when the failure
  /// came from one (401 = stale/invalid token, 403 = missing
  /// scope).
  final int? statusCode;

  @override
  String toString() => details == null ? message : '$message\n\n$details';
}

/// No-op implementation wired when the user never signed in (or
/// when the Google Sign-In plugin fails to initialize): every
/// call is a no-op, the cloud chip shows the not-connected state.
class NoopTrackerBackupService extends TrackerBackupService {
  @override
  bool get isSignedIn => false;

  @override
  String? get accountEmail => null;

  @override
  DateTime? get lastBackupAt => null;

  @override
  int get storedTrackerCount => 0;

  @override
  bool get isBusy => false;

  @override
  String? get lastPushErrorDetails => null;

  @override
  Future<bool> signIn() async => false;

  @override
  Future<void> restoreSessionSilently() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> pushSnapshot(List<Tracker> trackers) async => false;

  @override
  Future<bool> backupNow(List<Tracker> trackers) async => false;

  @override
  Future<List<Tracker>?> pullSnapshot() async => null;
}
