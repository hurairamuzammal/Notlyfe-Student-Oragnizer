import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google Drive storage restricted strictly to the `drive.file` scope.
///
/// Only accesses the dedicated `Notlyfe/` folder created by this app.
/// Once connected during setup, credentials and account state are encrypted
/// via [SecureStorageService] and restored silently across app restarts.
class GoogleDriveStorageService {
  GoogleDriveStorageService._();
  static final GoogleDriveStorageService instance =
      GoogleDriveStorageService._();

  static const List<String> strictDriveScopes = <String>[
    drive.DriveApi.driveFileScope,
    'email',
    'profile',
    'openid',
  ];

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '176811783170-usp8utmp46t7k4ptt0hfqfo54d6nhq8b.apps.googleusercontent.com',
  );

  static const String rootFolderName = 'Notlyfe';
  static const String _folderMimeType = 'application/vnd.google-apps.folder';

  static const String _prefConnected = 'gdrive_connected';
  static const String _prefEmail = 'gdrive_email';
  static const String _prefDisplayName = 'gdrive_display_name';
  static const String _prefRootFolderId = 'gdrive_notlyfe_root_folder_id';
  static const String _prefTokenExpiry = 'gdrive_token_expiry';
  static const String _prefOwnerUserId = 'gdrive_owner_user_id';
  static const String _prefSetupHandled = 'gdrive_initial_setup_handled';
  static const String _secAccessToken = 'gdrive_access_token';
  static const String _secRefreshToken = 'gdrive_refresh_token';

  bool _initialized = false;
  bool _silentRestoreAttempted = false;
  GoogleSignInAccount? _currentAccount;
  StreamSubscription<AuthState>? _authSubscription;
  String? _cachedRootFolderId;
  final Map<String, String> _courseFolderCache = {};

  /// Native Google Sign-In SDK is available on Android and iOS only.
  bool get isNativeSignInSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initializes Google Sign-In on mobile, migrates any legacy plaintext tokens,
  /// and hooks Supabase auth events so OAuth Drive tokens are encrypted immediately.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    await _purgeLegacyPlaintextTokens();
    _attachSupabaseAuthListener();

    if (isNativeSignInSupported) {
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId: googleWebClientId,
        );
      } catch (e) {
        debugPrint('GoogleSignIn init notice: $e');
      }
      // Restore previously authorized account silently without user prompts.
      await _tryRestoreAccountSilently();
    }
  }

  void _attachSupabaseAuthListener() {
    if (_authSubscription != null) return;
    try {
      final auth = Supabase.instance.client.auth;
      final current = auth.currentSession;
      if (current != null) {
        _captureSupabaseProviderTokens(current);
      }
      _authSubscription = auth.onAuthStateChange.listen((state) {
        final session = state.session;
        if (session != null) {
          _captureSupabaseProviderTokens(session);
        }
      });
    } catch (_) {
      // Supabase may not be initialized in isolated unit tests.
    }
  }

  Future<void> _captureSupabaseProviderTokens(Session session) async {
    final token = session.providerToken;
    if (token == null || token.isEmpty) return;

    await saveConnectedSession(
      email: session.user.email ?? '',
      accessToken: token,
      refreshToken: session.providerRefreshToken,
      ownerUserId: session.user.id,
      displayName: session.user.userMetadata?['full_name']?.toString(),
    );
  }

  /// Moves any old unencrypted provider token out of Hive into SecureStorage.
  Future<void> _purgeLegacyPlaintextTokens() async {
    try {
      if (!Hive.isBoxOpen('testBox')) return;
      final box = Hive.box('testBox');
      final legacy = box.get('google_provider_token');
      if (legacy is String && legacy.isNotEmpty) {
        final existing = await SecureStorageService.readSecure(_secAccessToken);
        if (existing == null || existing.isEmpty) {
          await SecureStorageService.writeSecure(_secAccessToken, legacy);
        }
      }
      await box.delete('google_provider_token');
    } catch (_) {}
  }

  String _currentAuthUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'local_user';
    } catch (_) {
      return 'local_user';
    }
  }

  /// Persists a verified Drive connection securely so setup only happens once.
  Future<void> saveConnectedSession({
    required String email,
    required String accessToken,
    String? refreshToken,
    String? displayName,
    String? ownerUserId,
    GoogleSignInAccount? account,
  }) async {
    if (account != null) {
      _currentAccount = account;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefConnected, true);
    await prefs.setBool(_prefSetupHandled, true);
    if (email.trim().isNotEmpty) {
      await prefs.setString(_prefEmail, email.trim());
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await prefs.setString(_prefDisplayName, displayName.trim());
    }
    await prefs.setString(_prefOwnerUserId, ownerUserId ?? _currentAuthUserId());

    await SecureStorageService.writeSecure(_secAccessToken, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await SecureStorageService.writeSecure(_secRefreshToken, refreshToken);
    }

    final expiry = DateTime.now().toUtc().add(const Duration(minutes: 55));
    await prefs.setString(_prefTokenExpiry, expiry.toIso8601String());
  }

  Future<bool> hasHandledInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefSetupHandled) == true) return true;
    return isDriveConnected();
  }

  Future<void> markInitialSetupHandled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSetupHandled, true);
  }

  /// Silently restores the native Google account across cold restarts.
  Future<void> _tryRestoreAccountSilently() async {
    if (!isNativeSignInSupported || _currentAccount != null) return;
    if (_silentRestoreAttempted) return;
    _silentRestoreAttempted = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefConnected) != true) return;

      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (future != null) {
        final account = await future;
        if (account != null) {
          _currentAccount = account;
        }
      }
    } catch (e) {
      debugPrint('Silent Drive account restore notice: $e');
    }
  }

  /// Returns true when the current user has an active persisted Drive setup.
  Future<bool> isDriveConnected() async {
    await ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefConnected) != true) return false;

    final owner = prefs.getString(_prefOwnerUserId);
    final currentUid = _currentAuthUserId();
    if (owner != null &&
        owner.isNotEmpty &&
        currentUid != 'local_user' &&
        owner != 'local_user' &&
        owner != currentUid) {
      return false;
    }

    if (_currentAccount != null) return true;

    final savedEmail = prefs.getString(_prefEmail);
    if (savedEmail != null && savedEmail.isNotEmpty) return true;

    final token = await SecureStorageService.readSecure(_secAccessToken);
    if (token != null && token.isNotEmpty) return true;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.providerToken != null &&
          session!.providerToken!.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<String?> getConnectedEmail() async {
    await ensureInitialized();
    if (!await isDriveConnected()) return null;

    if (_currentAccount != null && _currentAccount!.email.isNotEmpty) {
      return _currentAccount!.email;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefEmail);
    if (saved != null && saved.isNotEmpty) return saved;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email != null &&
          Supabase.instance.client.auth.currentSession?.providerToken != null) {
        return user!.email;
      }
    } catch (_) {}
    return null;
  }

  /// One-time interactive flow to connect the user's Google Drive (`drive.file`).
  /// Returns null on success or a user-facing error message.
  Future<String?> connectDrive() async {
    await ensureInitialized();

    if (!isNativeSignInSupported) {
      return _connectDriveViaOAuthFallback();
    }

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: strictDriveScopes,
      );
      final scopesToAuthorize = <String>[drive.DriveApi.driveFileScope];
      final authz = await account.authorizationClient
              .authorizationForScopes(scopesToAuthorize) ??
          await account.authorizationClient.authorizeScopes(scopesToAuthorize);

      await saveConnectedSession(
        email: account.email,
        accessToken: authz.accessToken,
        displayName: account.displayName,
        account: account,
      );

      final authClient = authz.authClient(scopes: scopesToAuthorize);
      final driveApi = drive.DriveApi(authClient);
      await getOrCreateNotlyfeRootFolder(driveApi);
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google Drive connection was cancelled.';
      }
      return _connectDriveViaOAuthFallback();
    } catch (_) {
      return _connectDriveViaOAuthFallback();
    }
  }

  Future<String?> _connectDriveViaOAuthFallback() async {
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'notlyfe://login-callback',
        scopes: drive.DriveApi.driveFileScope,
        queryParams: const {
          'access_type': 'offline',
          'prompt': 'consent',
        },
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return 'Could not open Google Drive authorization.';
      }
      // Actual connection state is committed by _captureSupabaseProviderTokens
      // once the OAuth callback returns a valid provider token.
      return null;
    } catch (e) {
      return 'Failed to connect Google Drive: $e';
    }
  }

  /// Disconnects Google Drive locally without touching files stored on Drive.
  Future<void> disconnectDrive() async {
    await ensureInitialized();
    if (isNativeSignInSupported) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    _currentAccount = null;
    _silentRestoreAttempted = false;
    _cachedRootFolderId = null;
    _courseFolderCache.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefConnected, false);
    await prefs.remove(_prefEmail);
    await prefs.remove(_prefRootFolderId);
    await prefs.remove(_prefTokenExpiry);
    await prefs.remove(_prefOwnerUserId);
    await SecureStorageService.deleteSecure(_secAccessToken);
    await SecureStorageService.deleteSecure(_secRefreshToken);
  }

  /// Returns an authenticated [drive.DriveApi] using silent recovery first.
  Future<drive.DriveApi?> _getDriveApi({
    bool interactiveIfNeeded = false,
    bool forceRefreshToken = false,
  }) async {
    await ensureInitialized();
    final driveScope = <String>[drive.DriveApi.driveFileScope];

    if (isNativeSignInSupported && _currentAccount == null) {
      _silentRestoreAttempted = false;
      await _tryRestoreAccountSilently();
    }

    // 1. Silent token lookup/refresh from restored native Google account.
    if (_currentAccount != null) {
      try {
        if (forceRefreshToken) {
          final oldToken =
              await SecureStorageService.readSecure(_secAccessToken);
          if (oldToken != null && oldToken.isNotEmpty) {
            try {
              await _currentAccount!.authorizationClient
                  .clearAuthorizationToken(accessToken: oldToken);
            } catch (_) {}
          }
        }

        var authz = await _currentAccount!.authorizationClient
            .authorizationForScopes(driveScope);

        if (authz == null && !forceRefreshToken) {
          final oldToken =
              await SecureStorageService.readSecure(_secAccessToken);
          if (oldToken != null && oldToken.isNotEmpty) {
            try {
              await _currentAccount!.authorizationClient
                  .clearAuthorizationToken(accessToken: oldToken);
            } catch (_) {}
          }
          authz = await _currentAccount!.authorizationClient
              .authorizationForScopes(driveScope);
        }

        if (authz != null) {
          await saveConnectedSession(
            email: _currentAccount!.email,
            accessToken: authz.accessToken,
            displayName: _currentAccount!.displayName,
            account: _currentAccount,
          );
          return drive.DriveApi(authz.authClient(scopes: driveScope));
        }
      } catch (e) {
        debugPrint('Silent Drive refresh notice: $e');
      }
    }

    // 2. Valid encrypted access token stored in SecureStorage.
    if (!forceRefreshToken) {
      try {
        final savedToken =
            await SecureStorageService.readSecure(_secAccessToken);
        final refreshToken =
            await SecureStorageService.readSecure(_secRefreshToken);
        final prefs = await SharedPreferences.getInstance();
        final expiryStr = prefs.getString(_prefTokenExpiry);
        if (savedToken != null && savedToken.isNotEmpty) {
          final expiry =
              expiryStr != null ? DateTime.tryParse(expiryStr) : null;
          if (expiry == null || DateTime.now().toUtc().isBefore(expiry)) {
            final credentials = gapis.AccessCredentials(
              gapis.AccessToken(
                'Bearer',
                savedToken,
                expiry ?? DateTime.now().toUtc().add(const Duration(minutes: 30)),
              ),
              refreshToken,
              driveScope,
            );
            final client =
                gapis.authenticatedClient(http.Client(), credentials);
            return drive.DriveApi(client);
          }
        }
      } catch (e) {
        debugPrint('Saved token fallback notice: $e');
      }
    }

    // 3. Active Supabase session providerToken.
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final providerToken = session?.providerToken;
      if (providerToken != null && providerToken.isNotEmpty) {
        await _captureSupabaseProviderTokens(session!);
        final credentials = gapis.AccessCredentials(
          gapis.AccessToken(
            'Bearer',
            providerToken,
            DateTime.now().toUtc().add(const Duration(minutes: 55)),
          ),
          session.providerRefreshToken,
          driveScope,
        );
        final client = gapis.authenticatedClient(http.Client(), credentials);
        return drive.DriveApi(client);
      }
    } catch (_) {}

    // 4. Interactive fallback only when explicitly requested and silent recovery fails.
    if (interactiveIfNeeded && isNativeSignInSupported) {
      try {
        final account = await GoogleSignIn.instance.authenticate(
          scopeHint: strictDriveScopes,
        );
        final authz =
            await account.authorizationClient.authorizeScopes(driveScope);
        await saveConnectedSession(
          email: account.email,
          accessToken: authz.accessToken,
          displayName: account.displayName,
          account: account,
        );
        return drive.DriveApi(authz.authClient(scopes: driveScope));
      } catch (e) {
        debugPrint('Interactive Drive auth fallback error: $e');
      }
    }

    return null;
  }

  /// Runs a Drive API action and silently refreshes + retries once on HTTP 401.
  Future<T> _runWithAuthRetry<T>(
    Future<T> Function(drive.DriveApi api) action, {
    bool interactiveIfNeeded = false,
  }) async {
    final api = await _getDriveApi(interactiveIfNeeded: interactiveIfNeeded);
    if (api == null) {
      throw Exception(
        'Google Drive is not connected. Open Settings to connect Google Drive.',
      );
    }

    try {
      return await action(api);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 401) rethrow;
      final refreshed = await _getDriveApi(
        interactiveIfNeeded: interactiveIfNeeded,
        forceRefreshToken: true,
      );
      if (refreshed == null) rethrow;
      return action(refreshed);
    }
  }

  String _escapeDriveQuery(String input) {
    return input.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  }

  /// Finds or creates the dedicated `Notlyfe` root folder on Drive.
  Future<String> getOrCreateNotlyfeRootFolder(drive.DriveApi api) async {
    if (_cachedRootFolderId != null && _cachedRootFolderId!.isNotEmpty) {
      return _cachedRootFolderId!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefRootFolderId);
    if (savedId != null && savedId.isNotEmpty) {
      try {
        final existing = await api.files.get(
          savedId,
          $fields: 'id, name, trashed',
        ) as drive.File;
        if (existing.trashed != true && existing.id != null) {
          _cachedRootFolderId = existing.id!;
          return _cachedRootFolderId!;
        }
      } catch (_) {}
    }

    final query =
        "mimeType = '$_folderMimeType' and name = '$rootFolderName' and trashed = false";
    final fileList = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
      pageSize: 5,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final folderId = fileList.files!.first.id!;
      _cachedRootFolderId = folderId;
      await prefs.setString(_prefRootFolderId, folderId);
      return folderId;
    }

    final folderMeta = drive.File()
      ..name = rootFolderName
      ..mimeType = _folderMimeType;

    final created = await api.files.create(
      folderMeta,
      $fields: 'id, name',
    );

    final folderId = created.id!;
    _cachedRootFolderId = folderId;
    await prefs.setString(_prefRootFolderId, folderId);
    return folderId;
  }

  Future<String> getOrCreateCourseFolder(
    drive.DriveApi api, {
    required String courseId,
    required String courseTitle,
  }) async {
    final safeCourseName =
        courseTitle.trim().isEmpty ? 'Course_$courseId' : courseTitle.trim();
    final cacheKey = '${courseId}_$safeCourseName';

    if (_courseFolderCache.containsKey(cacheKey)) {
      return _courseFolderCache[cacheKey]!;
    }

    final rootId = await getOrCreateNotlyfeRootFolder(api);
    final escapedName = _escapeDriveQuery(safeCourseName);

    final query =
        "'$rootId' in parents and mimeType = '$_folderMimeType' and name = '$escapedName' and trashed = false";
    final fileList = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
      pageSize: 5,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final folderId = fileList.files!.first.id!;
      _courseFolderCache[cacheKey] = folderId;
      return folderId;
    }

    final folderMeta = drive.File()
      ..name = safeCourseName
      ..mimeType = _folderMimeType
      ..parents = <String>[rootId];

    final created = await api.files.create(
      folderMeta,
      $fields: 'id, name',
    );

    final folderId = created.id!;
    _courseFolderCache[cacheKey] = folderId;
    return folderId;
  }

  Future<UserFiles?> uploadCourseFile({
    required String courseId,
    required String courseTitle,
    required File file,
    required String fileName,
    required String mimeType,
    required String userId,
    Function(int bytesSent, int totalBytes, double speedBytesPerSec)? onProgress,
  }) async {
    return _runWithAuthRetry((api) async {
      final courseFolderId = await getOrCreateCourseFolder(
        api,
        courseId: courseId,
        courseTitle: courseTitle,
      );

      final fileLength = await file.length();
      final driveFileMeta = drive.File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = <String>[courseFolderId]
        ..appProperties = <String, String>{
          'notlyfe_course_id': courseId,
          'notlyfe_course_title': courseTitle,
        };

      final stopwatch = Stopwatch()..start();
      var sent = 0;
      var lastReportedTime = 0;

      final countedStream = file.openRead().transform<List<int>>(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, output) {
            sent += chunk.length;
            output.add(chunk);
            final elapsedMs = stopwatch.elapsedMilliseconds;
            if (onProgress != null &&
                (elapsedMs - lastReportedTime > 150 || sent == fileLength)) {
              lastReportedTime = elapsedMs;
              final speed =
                  elapsedMs > 0 ? (sent / (elapsedMs / 1000.0)) : 0.0;
              onProgress(sent, fileLength, speed);
            }
          },
        ),
      );

      final media =
          drive.Media(countedStream, fileLength, contentType: mimeType);

      final uploaded = await api.files.create(
        driveFileMeta,
        uploadMedia: media,
        $fields: 'id, name, mimeType, size, createdTime',
      );

      if (uploaded.id == null) {
        throw Exception('Google Drive did not return a valid file ID.');
      }

      final userFile = UserFiles(
        id: uploaded.id.hashCode.abs(),
        filePath: 'gdrive://${uploaded.id}',
        fileName: uploaded.name ?? fileName,
        fileType: uploaded.mimeType ?? mimeType,
        userId: userId,
        courseId: courseId,
        fileSize: int.tryParse(uploaded.size ?? '') ?? fileLength,
      );

      await _cacheFileMetadataLocally(userFile);
      return userFile;
    }, interactiveIfNeeded: true);
  }

  Future<List<UserFiles>> listCourseFiles({
    required String courseId,
    required String courseTitle,
    required String userId,
  }) async {
    try {
      return await _runWithAuthRetry((api) async {
        final courseFolderId = await getOrCreateCourseFolder(
          api,
          courseId: courseId,
          courseTitle: courseTitle,
        );

        final query =
            "'$courseFolderId' in parents and mimeType != '$_folderMimeType' and trashed = false";
        final fileList = await api.files.list(
          q: query,
          spaces: 'drive',
          orderBy: 'createdTime desc',
          $fields: 'files(id, name, mimeType, size, createdTime)',
          pageSize: 100,
        );

        final results = <UserFiles>[];
        for (final f in fileList.files ?? <drive.File>[]) {
          if (f.id == null) continue;
          results.add(UserFiles(
            id: f.id.hashCode.abs(),
            filePath: 'gdrive://${f.id}',
            fileName: f.name ?? 'Untitled',
            fileType: f.mimeType ?? 'application/octet-stream',
            userId: userId,
            courseId: courseId,
            fileSize: int.tryParse(f.size ?? '0') ?? 0,
          ));
        }

        await _replaceCachedCourseFiles(userId, courseId, results);
        return results;
      });
    } catch (e) {
      debugPrint('Drive list fallback for course $courseTitle: $e');
      return getCachedFilesForCourse(courseId, userId: userId);
    }
  }

  Future<bool> downloadDriveFile({
    required String driveFileId,
    required File destinationFile,
    Function(int bytesReceived, int totalBytes, double speedBytesPerSec)?
        onProgress,
  }) async {
    return _runWithAuthRetry((api) async {
      final Object response = await api.files.get(
        driveFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is! drive.Media) return false;

      final sink = destinationFile.openWrite();
      try {
        final total = response.length ?? 0;
        var received = 0;
        final stopwatch = Stopwatch()..start();
        var lastReportedTime = 0;

        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (onProgress != null &&
              (elapsedMs - lastReportedTime > 150 || received == total)) {
            lastReportedTime = elapsedMs;
            final speed =
                elapsedMs > 0 ? (received / (elapsedMs / 1000.0)) : 0.0;
            onProgress(received, total, speed);
          }
        }
        await sink.flush();
        return true;
      } catch (_) {
        if (await destinationFile.exists()) {
          try {
            await destinationFile.delete();
          } catch (_) {}
        }
        rethrow;
      } finally {
        await sink.close();
      }
    }, interactiveIfNeeded: true);
  }

  Future<bool> deleteDriveFile(String driveFileId) async {
    return _runWithAuthRetry((api) async {
      await api.files.delete(driveFileId);
      return true;
    }, interactiveIfNeeded: true);
  }

  Future<bool> testDriveFolderAccess() async {
    try {
      return await _runWithAuthRetry((api) async {
        final rootId = await getOrCreateNotlyfeRootFolder(api);
        return rootId.isNotEmpty;
      });
    } catch (_) {
      return false;
    }
  }

  Future<String> getOrCreateSubfolder(
    drive.DriveApi api,
    String folderName,
  ) async {
    final safeName = folderName.trim().isEmpty ? 'General' : folderName.trim();
    final cacheKey = 'sub_$safeName';
    if (_courseFolderCache.containsKey(cacheKey)) {
      return _courseFolderCache[cacheKey]!;
    }

    final rootId = await getOrCreateNotlyfeRootFolder(api);
    final escapedName = _escapeDriveQuery(safeName);
    final query =
        "'$rootId' in parents and mimeType = '$_folderMimeType' and name = '$escapedName' and trashed = false";
    final fileList = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
      pageSize: 5,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final id = fileList.files!.first.id!;
      _courseFolderCache[cacheKey] = id;
      return id;
    }

    final folderMeta = drive.File()
      ..name = safeName
      ..mimeType = _folderMimeType
      ..parents = <String>[rootId];
    final created = await api.files.create(folderMeta, $fields: 'id, name');
    final id = created.id!;
    _courseFolderCache[cacheKey] = id;
    return id;
  }

  Future<void> upsertJsonDocument({
    required String subfolderName,
    required String fileName,
    required String jsonContent,
  }) async {
    await _runWithAuthRetry((api) async {
      final folderId = await getOrCreateSubfolder(api, subfolderName);
      final escaped = _escapeDriveQuery(fileName);
      final existing = await api.files.list(
        q: "'$folderId' in parents and name = '$escaped' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
        pageSize: 2,
      );

      final bytes = utf8.encode(jsonContent);
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        final fileId = existing.files!.first.id!;
        await api.files.update(
          drive.File()..name = fileName,
          fileId,
          uploadMedia: media,
        );
      } else {
        final meta = drive.File()
          ..name = fileName
          ..mimeType = 'application/json'
          ..parents = <String>[folderId];
        await api.files.create(meta, uploadMedia: media);
      }
    });
  }

  Future<Map<String, String>> readAllJsonDocuments({
    required String subfolderName,
  }) async {
    return _runWithAuthRetry((api) async {
      final folderId = await getOrCreateSubfolder(api, subfolderName);
      final fileList = await api.files.list(
        q: "'$folderId' in parents and mimeType != '$_folderMimeType' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
        pageSize: 200,
      );

      final docs = <String, String>{};
      for (final f in fileList.files ?? <drive.File>[]) {
        if (f.id == null || f.name == null) continue;
        final res = await api.files.get(
          f.id!,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        if (res is drive.Media) {
          final chunks = <int>[];
          await for (final chunk in res.stream) {
            chunks.addAll(chunk);
          }
          docs[f.name!] = utf8.decode(chunks, allowMalformed: true);
        }
      }
      return docs;
    });
  }

  Future<bool> deleteNamedFileInSubfolder({
    required String subfolderName,
    required String fileName,
  }) async {
    return _runWithAuthRetry((api) async {
      final folderId = await getOrCreateSubfolder(api, subfolderName);
      final escaped = _escapeDriveQuery(fileName);
      final existing = await api.files.list(
        q: "'$folderId' in parents and name = '$escaped' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
        pageSize: 5,
      );
      for (final f in existing.files ?? <drive.File>[]) {
        if (f.id != null) {
          await api.files.delete(f.id!);
        }
      }
      return true;
    });
  }

  String _cacheKey(String userId, String courseId) =>
      'gdrive_files_${userId}_$courseId';

  Future<void> _cacheFileMetadataLocally(UserFiles file) async {
    try {
      if (!Hive.isBoxOpen('testBox')) return;
      final box = Hive.box('testBox');
      final key = _cacheKey(file.userId.toString(), file.courseId);
      final rawList = box.get(key, defaultValue: <dynamic>[]) as List? ?? [];
      final updated = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['file_path'] != file.filePath)
          .toList();
      updated.insert(0, file.toMap());
      await box.put(key, updated);
    } catch (_) {}
  }

  Future<void> _replaceCachedCourseFiles(
    String userId,
    String courseId,
    List<UserFiles> files,
  ) async {
    try {
      if (!Hive.isBoxOpen('testBox')) return;
      final box = Hive.box('testBox');
      await box.put(
        _cacheKey(userId, courseId),
        files.map((f) => f.toMap()).toList(),
      );
    } catch (_) {}
  }

  Future<List<UserFiles>> getCachedFilesForCourse(
    String courseId, {
    String? userId,
  }) async {
    try {
      if (!Hive.isBoxOpen('testBox')) return [];
      final box = Hive.box('testBox');
      final uid = userId ?? _currentAuthUserId();
      final rawList = box.get(
            _cacheKey(uid, courseId),
            defaultValue:
                box.get('gdrive_files_$courseId', defaultValue: <dynamic>[]),
          ) as List? ??
          [];
      return rawList
          .map((e) => UserFiles.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UserFiles>> listAllCoursesFiles({
    required List<Course> courses,
    required String userId,
  }) async {
    final all = <UserFiles>[];
    for (final course in courses) {
      final courseFiles = await listCourseFiles(
        courseId: course.id,
        courseTitle: course.title,
        userId: userId,
      );
      all.addAll(courseFiles);
    }
    return all;
  }
}
