import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tracker.dart';
import '../local/tracker_codec.dart';
import 'remote_backup.dart';

/// Authorization headers plus the raw access token (needed to
/// purge the local token cache when Drive rejects it).
typedef _TokenHeaders = ({Map<String, String> headers, String token});

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
/// - Authorization: silent first ([pushSnapshot] must never show
///   UI). The manual paths ([backupNow], [pullSnapshot]) fall
///   back to the interactive consent when the Drive scope was
///   never granted; when Drive answers 401/403 they purge the
///   local token cache and re-authorize, and if the fresh token
///   still lacks the scope they escalate to a full disconnect +
///   reconnect: a grant cached by Google Play services can
///   predate the scope being added to the project, and only a
///   revocation forces the consent screen that fixes it.
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

  /// Real error behind the last failed authorization attempt
  /// (null when the account is simply not signed in, or when
  /// the last attempt succeeded).
  String? _authError;

  /// Details of the last failed upload (null after a success):
  /// the backup sheet shows them on "Show error details".
  String? _lastPushErrorDetails;

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

  @override
  String? get lastPushErrorDetails => _lastPushErrorDetails;

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
      // Warm up the Drive App Data consent: interactive the
      // first time, then cached by the plugin (Credential
      // Manager on Android). A stale cached token is not a
      // problem here: the upload paths purge and re-authorize
      // it when Drive rejects it.
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
      throw DriveBackupException(
        'Sign-in failed. Check the connection and try again.',
        details: 'GoogleSignInException (${error.code}): $error',
      );
    } catch (error) {
      throw DriveBackupException(
        'Sign-in failed. Check the connection and try again.',
        details: '$error',
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
      // Full disconnect, not a plain sign-out: it also revokes
      // the app's grants on the account. That is intentional —
      // it is the documented cure when the granted scopes and
      // the cached tokens disagree, so "Sign out" doubles as
      // the manual reset of the whole connection.
      await signIn.disconnect();
    } catch (_) {
      // Offline or already revoked: the local sign-out below
      // must still happen.
      await signIn.signOut();
    } finally {
      _account = null;
      _setBusy(false);
    }
  }

  @override
  Future<bool> pushSnapshot(List<Tracker> trackers) {
    return _enqueueUpload(trackers, interactive: false);
  }

  @override
  Future<bool> backupNow(List<Tracker> trackers) {
    return _enqueueUpload(trackers, interactive: true);
  }

  /// One upload at a time on the chain; failures keep the chain
  /// alive so one bad request cannot stall the next mutation.
  Future<bool> _enqueueUpload(
    List<Tracker> trackers, {
    required bool interactive,
  }) {
    final Future<bool> upload =
        _uploadChain.then<bool>((_) => _upload(trackers, interactive));
    _uploadChain = upload.then<void>((_) {}, onError: (_) {});
    return upload;
  }

  /// Silent authorization for the App Data scope, or null when
  /// the account is not signed in or the scope would need user
  /// interaction (the real failure, when there is one, lands in
  /// [_authError] for "Show error details").
  Future<_TokenHeaders?> _silentAuthorization() async {
    final GoogleSignInAccount? account = _account;
    if (account == null) {
      _authError = null;
      return null;
    }
    _authError = null;
    try {
      final GoogleSignInClientAuthorization? authorization =
          await account.authorizationClient.authorizationForScopes(
        const <String>[_scope],
      );
      if (authorization == null) {
        _authError =
            'The Drive App Data scope is not authorized (silent check).';
        return null;
      }
      return (
        headers: <String, String>{
          'Authorization': 'Bearer ${authorization.accessToken}',
          'X-Goog-AuthUser': '0',
        },
        token: authorization.accessToken,
      );
    } catch (error) {
      _authError = '$error';
      return null;
    }
  }

  /// Interactive authorization for the App Data scope: shows the
  /// consent the first time, or after the grant was revoked.
  /// Only callable from a user action (backup / restore button).
  Future<_TokenHeaders?> _interactiveAuthorization() async {
    final GoogleSignInAccount? account = _account;
    if (account == null) {
      _authError = 'Not signed in.';
      return null;
    }
    try {
      final GoogleSignInClientAuthorization authorization =
          await account.authorizationClient.authorizeScopes(
        const <String>[_scope],
      );
      return (
        headers: <String, String>{
          'Authorization': 'Bearer ${authorization.accessToken}',
          'X-Goog-AuthUser': '0',
        },
        token: authorization.accessToken,
      );
    } on GoogleSignInException catch (error) {
      _authError = error.code.name == 'canceled'
          ? 'The consent was canceled.'
          : 'authorizeScopes (${error.code}): $error';
      return null;
    } catch (error) {
      _authError = 'authorizeScopes: $error';
      return null;
    }
  }

  /// The plugin-documented cure for a token that Drive rejects
  /// (401/403): purge it from the local authorization caches,
  /// then re-authorize interactively so the consent can appear.
  Future<_TokenHeaders?> _refreshedAuthorization(String staleToken) async {
    final GoogleSignInAccount? account = _account;
    if (account == null) {
      return null;
    }
    try {
      await account.authorizationClient.clearAuthorizationToken(
        accessToken: staleToken,
      );
    } catch (_) {
      // Best effort: the token may already be gone from every
      // cache; the re-authorization is what matters.
    }
    return _interactiveAuthorization();
  }

  /// Escalation of last resort for the manual paths, when even
  /// a purged + re-authorized token still lacks the scope: the
  /// grant itself is stale on Google's side (e.g. the consent
  /// predates the scope being added to the project), and only
  /// revoking every grant forces the fresh consent screen that
  /// produces a token with the right scopes.
  Future<_TokenHeaders?> _fullReset() async {
    final GoogleSignIn? signIn = _signIn;
    if (signIn == null) {
      _authError = 'Not initialized.';
      return null;
    }
    try {
      await signIn.disconnect();
    } catch (_) {
      // Best effort: the fresh sign-in below is what matters.
    }
    // The disconnect fires a sign-out event: the sheet flickers
    // to the not-connected state for the length of the reset.
    _account = null;
    notifyListeners();
    try {
      final GoogleSignInAccount account = await signIn.authenticate();
      final GoogleSignInClientAuthorization authorization =
          await account.authorizationClient.authorizeScopes(
        const <String>[_scope],
      );
      if (!identical(account, _account)) {
        _account = account;
        notifyListeners();
      }
      return (
        headers: <String, String>{
          'Authorization': 'Bearer ${authorization.accessToken}',
          'X-Goog-AuthUser': '0',
        },
        token: authorization.accessToken,
      );
    } on GoogleSignInException catch (error) {
      _authError = error.code.name == 'canceled'
          ? 'The re-connect was canceled.'
          : 'fullReset (${error.code}): $error';
      return null;
    } catch (error) {
      _authError = 'fullReset: $error';
      return null;
    }
  }

  Future<bool> _upload(List<Tracker> trackers, bool interactive) async {
    _TokenHeaders? auth = await _silentAuthorization();
    if (auth == null && interactive) {
      auth = await _interactiveAuthorization();
    }
    if (auth == null) {
      _lastPushErrorDetails = _authError == null
          ? 'Not signed in.'
          : 'Drive authorization failed.\n\n$_authError';
      return false;
    }
    try {
      await _writeBackup(auth.headers, trackers);
      _lastPushErrorDetails = null;
      notifyListeners();
      return true;
    } on DriveBackupException catch (error) {
      // 401 = stale/invalid cached token, 403 = missing scope:
      // both are authorization failures, and both are curable
      // with a purge + interactive re-consent — but only when a
      // user action started this upload.
      if (interactive && (error.statusCode == 401 || error.statusCode == 403)) {
        final _TokenHeaders? refreshed = await _refreshedAuthorization(
          auth.token,
        );
        if (refreshed != null) {
          try {
            await _writeBackup(refreshed.headers, trackers);
            _lastPushErrorDetails = null;
            notifyListeners();
            return true;
          } on DriveBackupException catch (retryError) {
            if (retryError.statusCode == 401 ||
                retryError.statusCode == 403) {
              // Last resort: revoke every grant and reconnect, so
              // the consent screen appears again from scratch and
              // the new token cannot come from the poisoned one.
              final _TokenHeaders? reset = await _fullReset();
              if (reset != null) {
                try {
                  await _writeBackup(reset.headers, trackers);
                  _lastPushErrorDetails = null;
                  notifyListeners();
                  return true;
                } on DriveBackupException catch (resetError) {
                  _lastPushErrorDetails =
                      'Retry after re-connect failed.\n\n'
                      '${resetError.toString()}\n\n'
                      '${await _tokenInfo(reset.token)}';
                  return false;
                } catch (error, stackTrace) {
                  _lastPushErrorDetails = '$error\n$stackTrace';
                  return false;
                }
              }
              _lastPushErrorDetails =
                  'Re-connect did not produce a token.\n\n'
                  '$_authError\n\n${retryError.toString()}';
              return false;
            }
            _lastPushErrorDetails =
                'Retry after re-authorization failed.\n\n'
                '${retryError.toString()}\n\n'
                '${await _tokenInfo(refreshed.token)}';
            return false;
          } catch (error, stackTrace) {
            _lastPushErrorDetails = '$error\n$stackTrace';
            return false;
          }
        }
        _lastPushErrorDetails =
            'Re-authorization did not produce a token.\n\n'
            '$_authError\n\n${error.toString()}';
        return false;
      }
      _lastPushErrorDetails =
          '${error.toString()}\n\n${await _tokenInfo(auth.token)}';
      return false;
    } catch (error, stackTrace) {
      _lastPushErrorDetails = '$error\n$stackTrace';
      return false;
    }
  }

  /// Token introspection (Google's public tokeninfo endpoint):
  /// granted scopes, the client the token was issued to and its
  /// remaining life, so "Show error details" can say exactly why
  /// Drive rejects the token. The raw token never appears.
  Future<String> _tokenInfo(String accessToken) async {
    try {
      final http.Response response = await _client.get(
        Uri.parse('https://oauth2.googleapis.com/tokeninfo').replace(
          queryParameters: <String, String>{'access_token': accessToken},
        ),
      );
      if (response.statusCode != 200) {
        return 'Token info: unavailable (${response.statusCode})';
      }
      final dynamic data = jsonDecode(response.body);
      if (data is! Map) {
        return 'Token info: unexpected response';
      }
      return 'Token info:\n'
          'issued_to: ${data['issued_to'] ?? data['audience'] ?? '?'}\n'
          'scope: ${data['scope'] ?? '?'}\n'
          'expires_in: ${data['expires_in'] ?? '?'} s';
    } catch (error) {
      return 'Token info failed: $error';
    }
  }

  /// Full snapshot write: creates the file on first backup,
  /// overwrites it (last write wins) on every other one.
  Future<void> _writeBackup(
    Map<String, String> headers,
    List<Tracker> trackers,
  ) async {
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
  }

  @override
  Future<List<Tracker>?> pullSnapshot() async {
    _TokenHeaders? auth = await _silentAuthorization();
    auth ??= await _interactiveAuthorization();
    if (auth == null) {
      throw DriveBackupException(
        'Not signed in. Open the backup sheet and sign in first.',
        details: _authError,
      );
    }
    try {
      return await _downloadSnapshot(auth.headers);
    } on DriveBackupException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        final _TokenHeaders? refreshed = await _refreshedAuthorization(
          auth.token,
        );
        if (refreshed != null) {
          try {
            return await _downloadSnapshot(refreshed.headers);
          } on DriveBackupException catch (retryError) {
            if (retryError.statusCode == 401 ||
                retryError.statusCode == 403) {
              final _TokenHeaders? reset = await _fullReset();
              if (reset != null) {
                return await _downloadSnapshot(reset.headers);
              }
            }
            rethrow;
          }
        }
        final _TokenHeaders? reset = await _fullReset();
        if (reset != null) {
          return await _downloadSnapshot(reset.headers);
        }
      }
      rethrow;
    }
  }

  /// Lists the App Data folder and returns the id of the backup
  /// file, or null when this account has none yet.
  Future<String?> _findFileId(Map<String, String> headers) async {
    final Uri uri = Uri.parse(_filesUrl).replace(
      queryParameters: <String, String>{
        // Required: without an explicit spaces=appDataFolder Drive
        // checks access to the whole "drive" space, which the
        // drive.appdata scope does not cover — 403 insufficientScopes
        // with "location: spaces", even on a perfectly good token.
        'spaces': 'appDataFolder',
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
        statusCode: response.statusCode,
        details: 'GET $_filesUrl\n'
            'q: \'appDataFolder\' in parents and name = \'$_fileName\'\n'
            '${response.statusCode}\n${response.body}',
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

  /// Downloads and decodes the current backup, or null when the
  /// account has none yet.
  Future<List<Tracker>?> _downloadSnapshot(Map<String, String> headers) async {
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
        statusCode: response.statusCode,
        details: 'GET $_filesUrl/$fileId?alt=media\n'
            '${response.statusCode}\n${response.body}',
      );
    }
    return _decodeSnapshot(response.body);
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
        statusCode: created.statusCode,
        details: 'POST $_filesUrl\n'
            '${created.statusCode}\n${created.body}',
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
        statusCode: response.statusCode,
        details: 'PATCH $_uploadUrl/$fileId?uploadType=media\n'
            '${response.statusCode}\n${response.body}',
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
