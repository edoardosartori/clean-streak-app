import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tracker.dart';
import '../local/tracker_codec.dart';
import 'remote_backup.dart';

/// Google Drive implementation of the backup service (step 5).
///
/// - Storage: the hidden App Data folder of the user's Drive
///   (scope `drive.appdata`): invisible in the Drive UI, private
///   to this app, deleted if the user removes the app from Drive.
/// - Identity: the Google account, so the backup survives a
///   reinstall and moves to a new phone.
/// - Format: one `backup.json` file overwritten in full every
///   time (last write wins, no sync). The tracker records reuse
///   the Hive codec, so `celebratedMilestones` and
///   `disabledMilestones` travel along for free.
/// - Transport: the plain Drive REST v3 endpoints via `http`
///   (the old Drive SDK for Android is deprecated).
///
/// Uploads are serialized through a future chain: the controller
/// mirrors every mutation fire-and-forget and only the last
/// snapshot matters, but the requests must not interleave.
class GoogleDriveTrackerBackupService extends TrackerBackupService {
  GoogleDriveTrackerBackupService._(this._preferences);

  /// The App Data scope is not a sensitive one: no Google
  /// verification needed, and the consent screen can stay in
  /// production (no 7-day token expiry like in testing).
  static const String _scope = 'https://www.googleapis.com/auth/drive.appdata';

  static const String _fileName = 'backup.json';
  static const String _lastRunKey = 'backup_last_run';
  static const String _storedCountKey = 'backup_stored_count';

  /// Snapshot format version, reserved for future migrations.
  static const int _snapshotVersion = 1;

  static const String _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const String _uploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files';

  final SharedPreferences _preferences;
  final http.Client _client = http.Client();

  GoogleSignIn? _signIn;
  GoogleSignInAccount? _account;

  DateTime? _lastBackupAt;
  int _storedTrackerCount = 0;
  bool _busy = false;

  /// Serialized uploads: one at a time, failures keep the chain
  /// alive so one bad request cannot stall the next mutation.
  Future<void> _uploadChain = Future<void>.value();

  /// Initializes the Google Sign-In plugin (exactly once per
  /// process, plugin requirement) and restores a previous
  /// sign-in silently. Call from main before the first frame.
  static Future<GoogleDriveTrackerBackupService> create({
    required String serverClientId,
    required SharedPreferences preferences,
  }) async {
    final GoogleDriveTrackerBackupService service =
        GoogleDriveTrackerBackupService._(preferences);
    await service._initialize(serverClientId);
    return service;
  }

  Future<void> _initialize(String serverClientId) async {
    final int? lastRun = _preferences.getInt(_lastRunKey);
    if (lastRun != null) {
      _lastBackupAt = DateTime.fromMillisecondsSinceEpoch(lastRun);
    }
    _storedTrackerCount = _preferences.getInt(_storedCountKey) ?? 0;

    final GoogleSignIn signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: serverClientId);
    _signIn = signIn;
    signIn.authenticationEvents.listen(_onAuthenticationEvent);
    // The silent restore does NOT run here: with more than one
    // Google account on the phone the Credential Manager shows
    // its account picker, and the app must never pop one unasked
    // at startup. The backup sheet triggers it on open instead
    // (see restoreSessionSilently).
  }

  @override
  Future<void> restoreSessionSilently() async {
    final GoogleSignIn? signIn = _signIn;
    if (signIn == null || _account != null) {
      return;
    }
    try {
      await signIn.attemptLightweightAuthentication();
    } catch (_) {
      // Nothing to restore, or the system selector was canceled:
      // a failed silent restore is not an error.
    }
  }

  void _onAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    final GoogleSignInAccount? account = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    if (!identical(account, _account)) {
      _account = account;
      notifyListeners();
    }
  }

  @override
  bool get isSignedIn => _account != null;

  @override
  String? get accountEmail => _account?.email;

  @override
  DateTime? get lastBackupAt => _lastBackupAt;

  @override
  int get storedTrackerCount => _storedTrackerCount;

  @override
  bool get isBusy => _busy;

  void _setBusy(bool busy) {
    if (_busy != busy) {
      _busy = busy;
      notifyListeners();
    }
  }

  @override
  Future<bool> signIn() async {
    final GoogleSignIn? signIn = _signIn;
    if (signIn == null || _busy) {
      return false;
    }
    _setBusy(true);
    try {
      final GoogleSignInAccount account =
          _account ?? await signIn.authenticate();
      // Drive App Data consent: interactive the first time, then
      // cached by the plugin (Credential Manager on Android).
      await account.authorizationClient.authorizeScopes(
        const <String>[_scope],
      );
      if (!identical(account, _account)) {
        _account = account;
        notifyListeners();
      }
      return true;
    } on GoogleSignInException catch (error) {
      // The user closed the account picker: a canceled sign-in,
      // not an error. Everything else reaches the sheet.
      if (error.code.name == 'canceled') {
        return false;
      }
      throw const DriveBackupException(
        'Sign-in failed. Check the connection and try again.',
      );
    } catch (_) {
      throw const DriveBackupException(
        'Sign-in failed. Check the connection and try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  @override
  Future<void> signOut() async {
    final GoogleSignIn? signIn = _signIn;
    if (signIn == null || _busy) {
      return;
    }
    _setBusy(true);
    try {
      await signIn.signOut();
    } finally {
      _account = null;
      _setBusy(false);
    }
  }

  @override
  Future<bool> pushSnapshot(List<Tracker> trackers) {
    final Future<bool> upload =
        _uploadChain.then<bool>((_) => _upload(trackers));
    _uploadChain = upload.then<void>((_) {}, onError: (_) {});
    return upload;
  }

  /// Silent authorization headers for the App Data scope, or
  /// null when they cannot be produced without interaction (not
  /// signed in, or consent revoked from the Drive settings).
  Future<Map<String, String>?> _authorizationHeaders() async {
    final GoogleSignInAccount? account = _account;
    if (account == null) {
      return null;
    }
    try {
      return await account.authorizationClient.authorizationHeaders(
        const <String>[_scope],
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _upload(List<Tracker> trackers) async {
    final Map<String, String>? headers = await _authorizationHeaders();
    if (headers == null) {
      return false;
    }
    try {
      final String? fileId = await _findFileId(headers);
      final String payload = _encodeSnapshot(trackers);
      if (fileId == null) {
        await _createFile(headers, payload);
      } else {
        await _updateFile(headers, fileId, payload);
      }
      _lastBackupAt = DateTime.now();
      _storedTrackerCount = trackers.length;
      await _preferences.setInt(
        _lastRunKey,
        _lastBackupAt!.millisecondsSinceEpoch,
      );
      await _preferences.setInt(_storedCountKey, _storedTrackerCount);
      notifyListeners();
      return true;
    } on DriveBackupException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Tracker>?> pullSnapshot() async {
    final Map<String, String>? headers = await _authorizationHeaders();
    if (headers == null) {
      throw const DriveBackupException(
        'Not signed in. Open the backup sheet and sign in first.',
      );
    }
    final String? fileId = await _findFileId(headers);
    if (fileId == null) {
      return null;
    }
    final Uri uri = Uri.parse('$_filesUrl/$fileId')
        .replace(queryParameters: <String, String>{'alt': 'media'});
    final http.Response response = await _client.get(
      uri,
      headers: _requestHeaders(headers),
    );
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'Could not download the backup (${response.statusCode}).',
      );
    }
    return _decodeSnapshot(response.body);
  }

  /// Lists the App Data folder and returns the id of the backup
  /// file, or null when this account has none yet.
  Future<String?> _findFileId(Map<String, String> headers) async {
    final Uri uri = Uri.parse(_filesUrl).replace(
      queryParameters: <String, String>{
        'q': "'appDataFolder' in parents and name = '$_fileName'",
        'fields': 'files(id,name)',
      },
    );
    final http.Response response = await _client.get(
      uri,
      headers: _requestHeaders(headers),
    );
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'Drive is unreachable (${response.statusCode}).',
      );
    }
    final dynamic data = jsonDecode(response.body);
    if (data is! Map || data['files'] is! List) {
      return null;
    }
    for (final dynamic file in data['files'] as List<dynamic>) {
      if (file is Map && file['name'] == _fileName && file['id'] is String) {
        return file['id'] as String;
      }
    }
    return null;
  }

  /// Creates the (empty) backup file in the App Data folder, then
  /// fills it: the plain metadata + media calls avoid the messy
  /// multipart upload entirely.
  Future<void> _createFile(
    Map<String, String> headers,
    String payload,
  ) async {
    final http.Response created = await _client.post(
      Uri.parse(_filesUrl),
      headers: _requestHeaders(headers, contentType: 'application/json'),
      body: jsonEncode(<String, dynamic>{
        'name': _fileName,
        'mimeType': 'application/json',
        'parents': <String>['appDataFolder'],
      }),
    );
    if (created.statusCode != 200 && created.statusCode != 201) {
      throw DriveBackupException(
        'Could not create the backup (${created.statusCode}).',
      );
    }
    final dynamic data = jsonDecode(created.body);
    final dynamic id = data is Map ? data['id'] : null;
    if (id is! String) {
      throw const DriveBackupException('Could not create the backup.');
    }
    await _updateFile(headers, id, payload);
  }

  /// Overwrites the whole file content (last write wins).
  Future<void> _updateFile(
    Map<String, String> headers,
    String fileId,
    String payload,
  ) async {
    final Uri uri = Uri.parse('$_uploadUrl/$fileId')
        .replace(queryParameters: <String, String>{'uploadType': 'media'});
    final http.Response response = await _client.patch(
      uri,
      headers: _requestHeaders(headers, contentType: 'application/json'),
      body: payload,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw DriveBackupException(
        'Could not save the backup (${response.statusCode}).',
      );
    }
  }

  /// The authorization headers carry their own content type: it
  /// must never win over the request one.
  Map<String, String> _requestHeaders(
    Map<String, String> auth, {
    String? contentType,
  }) {
    final Map<String, String> headers = Map<String, String>.from(auth);
    headers.remove('Content-Type');
    headers.remove('content-type');
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    return headers;
  }

  String _encodeSnapshot(List<Tracker> trackers) {
    return jsonEncode(<String, dynamic>{
      'version': _snapshotVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'trackers': <Map<String, dynamic>>[
        for (final Tracker tracker in trackers) trackerToMap(tracker),
      ],
    });
  }

  List<Tracker> _decodeSnapshot(String body) {
    final dynamic data = jsonDecode(body);
    if (data is! Map || data['trackers'] is! List) {
      throw const DriveBackupException('The backup on Drive is unreadable.');
    }
    final List<Tracker> trackers = <Tracker>[];
    for (final dynamic record in data['trackers'] as List<dynamic>) {
      if (record is Map) {
        final Tracker? tracker = trackerFromMap(record);
        if (tracker != null) {
          trackers.add(tracker);
        }
      }
    }
    return trackers;
  }
}
