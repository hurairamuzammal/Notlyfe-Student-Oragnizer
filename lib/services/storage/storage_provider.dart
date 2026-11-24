import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/storage/providers/custom_http_providers.dart';
import 'package:notlyfe/services/storage/providers/google_drive_providers.dart';
import 'package:notlyfe/services/storage/providers/local_directory_providers.dart';
import 'package:notlyfe/services/storage/providers/supabase_default_notes_provider.dart';
import 'package:notlyfe/services/storage/providers/webdav_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef StorageProgressCallback = void Function(
  int bytesTransferred,
  int totalBytes,
  double speedBytesPerSec,
);

/// Result of running a live connectivity & read/write capability probe against a storage backend.
@immutable
class StorageTestResult {
  final bool success;
  final String message;
  final Duration? latency;
  final Map<String, dynamic> details;

  const StorageTestResult({
    required this.success,
    required this.message,
    this.latency,
    this.details = const {},
  });

  @override
  String toString() =>
      'StorageTestResult(success: $success, message: $message, latency: ${latency?.inMilliseconds}ms)';
}

/// Pluggable interface for storing and retrieving course files/attachments.
///
/// Open-source contributors can implement this class and register it via
/// [StorageBackendRegistry.instance.registerFileProvider] to add any custom
/// storage backend (S3, IPFS, WebDAV, Nextcloud, local folder, custom API, etc.).
abstract class CustomFileStorageProvider {
  /// Unique identifier (e.g. `'google_drive'`, `'webdav'`, `'custom_http'`, `'local_folder'`).
  String get typeId;

  /// Human-friendly name shown in Settings.
  String get displayName;

  /// Short description of where files live and any privacy/cost notes.
  String get description;

  /// URI prefix stored in `UserFiles.filePath` (e.g. `'gdrive://'`, `'webdav://'`).
  String get pathScheme;

  /// Whether this provider currently has the required configuration/credentials.
  Future<bool> isConfigured();

  /// Executes a safe connection + read/write probe and returns diagnostics.
  Future<StorageTestResult> testConnection();

  /// Uploads [file] for the given course and returns a [UserFiles] descriptor.
  Future<UserFiles?> uploadFile({
    required String courseId,
    required String courseTitle,
    required File file,
    required String fileName,
    required String mimeType,
    required String userId,
    StorageProgressCallback? onProgress,
  });

  /// Lists all files stored for [courseId] under this backend.
  Future<List<UserFiles>> listFiles({
    required String courseId,
    required String courseTitle,
    required String userId,
  });

  /// Lists files across all [courses]. Defaults to aggregating [listFiles].
  Future<List<UserFiles>> listAllCoursesFiles({
    required List<Course> courses,
    required String userId,
  }) async {
    final all = <UserFiles>[];
    for (final course in courses) {
      final items = await listFiles(
        courseId: course.id,
        courseTitle: course.title,
        userId: userId,
      );
      all.addAll(items);
    }
    return all;
  }

  /// Downloads [file] to [destinationFile], reporting optional progress.
  Future<bool> downloadFile({
    required UserFiles file,
    required File destinationFile,
    StorageProgressCallback? onProgress,
  });

  /// Deletes [file] from the remote/custom storage backend.
  Future<bool> deleteFile(UserFiles file);

  /// Whether this provider owns [filePath].
  bool ownsPath(String filePath) => filePath.startsWith('$pathScheme://');
}

/// Pluggable interface for storing and syncing E2EE Notes and Default Note Styles.
///
/// By default Notlyfe uses [SupabaseDefaultNotesProvider], which keeps notes
/// E2EE encrypted in Supabase. Users can switch to Google Drive, WebDAV,
/// a custom REST/PostgREST server, a local directory, or any contributor-registered
/// backend in Settings so the central instance never becomes a bottleneck.
abstract class CustomNotesStorageProvider {
  /// Unique identifier (e.g. `'supabase_default'`, `'google_drive_notes'`).
  String get typeId;

  /// Human-friendly name shown in Settings.
  String get displayName;

  /// Short description of this notes sync location.
  String get description;

  /// Whether the provider is configured and ready for sync.
  Future<bool> isConfigured();

  /// Executes a safe connection & read/write probe and returns diagnostics.
  Future<StorageTestResult> testConnection();

  /// Fetches all E2EE-encrypted [Note] objects for [userId].
  Future<List<Note>> fetchNotes(String userId);

  /// Creates or updates a single E2EE-encrypted [note].
  Future<void> upsertNote(Note note);

  /// Deletes [note] from this storage location.
  Future<void> deleteNote(Note note);

  /// Fetches the user's saved default note style for cross-platform sync.
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async => null;

  /// Saves the user's default note style to this storage location for cross-platform sync.
  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {}
}

/// Central registry for file and notes storage providers.
class StorageBackendRegistry extends ChangeNotifier {
  StorageBackendRegistry._() {
    _registerBuiltIns();
  }

  static final StorageBackendRegistry instance = StorageBackendRegistry._();

  static const String _prefActiveFileProvider = 'notlyfe_active_file_provider';
  static const String _prefActiveNotesProvider =
      'notlyfe_active_notes_provider';

  final Map<String, CustomFileStorageProvider> _fileProviders = {};
  final Map<String, CustomNotesStorageProvider> _notesProviders = {};

  String _activeFileProviderId = GoogleDriveFileStorageProvider.id;
  String _activeNotesProviderId = SupabaseDefaultNotesProvider.id;
  bool _initialized = false;

  void _registerBuiltIns() {
    registerFileProvider(GoogleDriveFileStorageProvider(), notify: false);
    registerFileProvider(WebDavFileStorageProvider(), notify: false);
    registerFileProvider(CustomHttpFileStorageProvider(), notify: false);
    registerFileProvider(LocalDirectoryFileStorageProvider(), notify: false);

    registerNotesProvider(SupabaseDefaultNotesProvider(), notify: false);
    registerNotesProvider(GoogleDriveNotesStorageProvider(), notify: false);
    registerNotesProvider(WebDavNotesStorageProvider(), notify: false);
    registerNotesProvider(CustomHttpNotesStorageProvider(), notify: false);
    registerNotesProvider(LocalDirectoryNotesStorageProvider(), notify: false);
  }

  /// Loads persisted active backend selections from [SharedPreferences].
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFileId = prefs.getString(_prefActiveFileProvider);
      if (savedFileId != null && _fileProviders.containsKey(savedFileId)) {
        _activeFileProviderId = savedFileId;
      }
      final savedNotesId = prefs.getString(_prefActiveNotesProvider);
      if (savedNotesId != null && _notesProviders.containsKey(savedNotesId)) {
        _activeNotesProviderId = savedNotesId;
      }
    } catch (e) {
      debugPrint('StorageBackendRegistry init notice: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  List<CustomFileStorageProvider> get fileProviders =>
      List.unmodifiable(_fileProviders.values);

  List<CustomNotesStorageProvider> get notesProviders =>
      List.unmodifiable(_notesProviders.values);

  String get activeFileProviderId => _activeFileProviderId;
  String get activeNotesProviderId => _activeNotesProviderId;

  CustomFileStorageProvider get activeFileProvider =>
      _fileProviders[_activeFileProviderId] ?? _fileProviders.values.first;

  CustomNotesStorageProvider get activeNotesProvider =>
      _notesProviders[_activeNotesProviderId] ?? _notesProviders.values.first;

  /// Finds the file provider that owns [filePath], or falls back to [activeFileProvider].
  CustomFileStorageProvider? findFileProviderForPath(String filePath) {
    for (final provider in _fileProviders.values) {
      if (provider.ownsPath(filePath)) return provider;
    }
    return null;
  }

  /// Registers or replaces a custom file storage provider.
  void registerFileProvider(
    CustomFileStorageProvider provider, {
    bool notify = true,
  }) {
    _fileProviders[provider.typeId] = provider;
    if (notify) notifyListeners();
  }

  /// Registers or replaces a custom notes storage provider.
  void registerNotesProvider(
    CustomNotesStorageProvider provider, {
    bool notify = true,
  }) {
    _notesProviders[provider.typeId] = provider;
    if (notify) notifyListeners();
  }

  /// Unregisters a file provider (useful in tests or dynamic plugins).
  void unregisterFileProvider(String typeId) {
    if (_fileProviders.length <= 1) return;
    _fileProviders.remove(typeId);
    if (_activeFileProviderId == typeId) {
      _activeFileProviderId = _fileProviders.keys.first;
    }
    notifyListeners();
  }

  /// Unregisters a notes provider (useful in tests or dynamic plugins).
  void unregisterNotesProvider(String typeId) {
    if (_notesProviders.length <= 1) return;
    _notesProviders.remove(typeId);
    if (_activeNotesProviderId == typeId) {
      _activeNotesProviderId = _notesProviders.keys.first;
    }
    notifyListeners();
  }

  /// Switches the active file storage backend and persists the choice.
  Future<void> setActiveFileProvider(String typeId) async {
    if (!_fileProviders.containsKey(typeId)) {
      throw ArgumentError('Unknown file storage provider: $typeId');
    }
    _activeFileProviderId = typeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefActiveFileProvider, typeId);
    notifyListeners();
  }

  /// Switches the active notes storage location and persists the choice.
  Future<void> setActiveNotesProvider(String typeId) async {
    if (!_notesProviders.containsKey(typeId)) {
      throw ArgumentError('Unknown notes storage provider: $typeId');
    }
    _activeNotesProviderId = typeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefActiveNotesProvider, typeId);
    notifyListeners();
  }
}

final storageRegistryProvider = ChangeNotifierProvider<StorageBackendRegistry>(
  (ref) => StorageBackendRegistry.instance,
);
