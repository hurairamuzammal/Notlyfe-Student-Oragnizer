import 'dart:convert';
import 'dart:io';

import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted paths for storing files or notes in a user-selected local/synced folder
/// (e.g., SD card, Syncthing folder, Nextcloud local sync folder, or device backup).
class LocalDirectoryConfig {
  LocalDirectoryConfig._();

  static const _prefFilesDir = 'local_storage_files_dir';
  static const _prefNotesDir = 'local_storage_notes_dir';

  static Future<String?> getFilesDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefFilesDir);
  }

  static Future<void> setFilesDirectory(String? dirPath) async {
    final prefs = await SharedPreferences.getInstance();
    if (dirPath == null || dirPath.trim().isEmpty) {
      await prefs.remove(_prefFilesDir);
    } else {
      await prefs.setString(_prefFilesDir, dirPath.trim());
    }
  }

  static Future<String?> getNotesDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefNotesDir);
  }

  static Future<void> setNotesDirectory(String? dirPath) async {
    final prefs = await SharedPreferences.getInstance();
    if (dirPath == null || dirPath.trim().isEmpty) {
      await prefs.remove(_prefNotesDir);
    } else {
      await prefs.setString(_prefNotesDir, dirPath.trim());
    }
  }

  /// Resolves a child path inside [rootDir] and rejects any path traversal escape.
  static File resolveContainedFile(
    Directory rootDir,
    List<String> segments,
  ) {
    final rootCanonical = p.normalize(rootDir.absolute.path);
    final sanitized = segments
        .map((s) => StorageSecurityHelper.sanitizeSegment(s, fallback: 'item'))
        .toList();
    final targetPath = p.normalize(p.joinAll([rootCanonical, ...sanitized]));
    if (!p.isWithin(rootCanonical, targetPath)) {
      throw const FileSystemException('Path escapes configured storage root.');
    }
    return File(targetPath);
  }
}

/// Stores course files in a user-chosen local or externally-synced directory.
class LocalDirectoryFileStorageProvider extends CustomFileStorageProvider {
  static const String id = 'local_folder';

  final Future<String?> Function()? _dirLoader;

  LocalDirectoryFileStorageProvider({
    Future<String?> Function()? directoryLoader,
  }) : _dirLoader = directoryLoader;

  Future<Directory?> _rootDir() async {
    final path = await (_dirLoader != null
        ? _dirLoader()
        : LocalDirectoryConfig.getFilesDirectory());
    if (path == null || path.trim().isEmpty) return null;
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  String get typeId => id;

  @override
  String get displayName => 'Custom Local / Synced Folder';

  @override
  String get description =>
      'Save files in any device folder (ideal for Syncthing, local backup, or zero-cloud setups).';

  @override
  String get pathScheme => 'localdir';

  @override
  Future<bool> isConfigured() async {
    final path = await (_dirLoader != null
        ? _dirLoader()
        : LocalDirectoryConfig.getFilesDirectory());
    return path != null && path.trim().isNotEmpty;
  }

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final root = await _rootDir();
      if (root == null) {
        return StorageTestResult(
          success: false,
          message: 'No custom local folder selected yet.',
          latency: sw.elapsed,
        );
      }
      final probe = LocalDirectoryConfig.resolveContainedFile(
        root,
        ['.notlyfe_probe.txt'],
      );
      await probe.writeAsString('ok');
      final text = await probe.readAsString();
      if (await probe.exists()) await probe.delete();
      return StorageTestResult(
        success: text == 'ok',
        message: 'Local folder read/write verified at ${root.path}.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Local folder probe failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  @override
  Future<UserFiles?> uploadFile({
    required String courseId,
    required String courseTitle,
    required File file,
    required String fileName,
    required String mimeType,
    required String userId,
    StorageProgressCallback? onProgress,
  }) async {
    final root = await _rootDir();
    if (root == null) {
      throw Exception('Custom local folder is not configured.');
    }
    final safeCourse =
        StorageSecurityHelper.sanitizeSegment(courseTitle, fallback: courseId);
    final safeName = StorageSecurityHelper.sanitizeFileName(fileName);
    final dest = LocalDirectoryConfig.resolveContainedFile(
      root,
      ['Notlyfe', safeCourse, safeName],
    );
    await dest.parent.create(recursive: true);
    final bytes = await file.readAsBytes();
    await dest.writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length, 0);

    final virtualPath =
        'localdir://${Uri.encodeComponent(safeCourse)}/${Uri.encodeComponent(safeName)}';
    return UserFiles(
      id: virtualPath.hashCode.abs(),
      filePath: virtualPath,
      fileName: safeName,
      fileType: mimeType,
      userId: userId,
      courseId: courseId,
      fileSize: bytes.length,
    );
  }

  @override
  Future<List<UserFiles>> listFiles({
    required String courseId,
    required String courseTitle,
    required String userId,
  }) async {
    final root = await _rootDir();
    if (root == null) return [];
    final safeCourse =
        StorageSecurityHelper.sanitizeSegment(courseTitle, fallback: courseId);
    final courseDir = Directory(p.join(root.path, 'Notlyfe', safeCourse));
    if (!await courseDir.exists()) return [];

    final files = <UserFiles>[];
    await for (final entity in courseDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        final size = await entity.length();
        final vPath =
            'localdir://${Uri.encodeComponent(safeCourse)}/${Uri.encodeComponent(name)}';
        files.add(UserFiles(
          id: vPath.hashCode.abs(),
          filePath: vPath,
          fileName: name,
          fileType: 'application/octet-stream',
          userId: userId,
          courseId: courseId,
          fileSize: size,
        ));
      }
    }
    return files;
  }

  File _resolveVirtualFile(Directory root, String virtualPath) {
    final rest = virtualPath.substring('localdir://'.length);
    final segments = rest
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
    return LocalDirectoryConfig.resolveContainedFile(
      root,
      ['Notlyfe', ...segments],
    );
  }

  @override
  Future<bool> downloadFile({
    required UserFiles file,
    required File destinationFile,
    StorageProgressCallback? onProgress,
  }) async {
    final root = await _rootDir();
    if (root == null) return false;
    final src = _resolveVirtualFile(root, file.filePath);
    if (!await src.exists()) return false;
    final bytes = await src.readAsBytes();
    await destinationFile.writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length, 0);
    return true;
  }

  @override
  Future<bool> deleteFile(UserFiles file) async {
    final root = await _rootDir();
    if (root == null) return false;
    final src = _resolveVirtualFile(root, file.filePath);
    if (await src.exists()) {
      await src.delete();
    }
    return true;
  }
}

/// Stores E2EE-encrypted notes & default styles in a user-chosen local/synced folder.
class LocalDirectoryNotesStorageProvider extends CustomNotesStorageProvider {
  static const String id = 'local_folder_notes';
  static const String _styleFileName = 'default_style.json';

  final Future<String?> Function()? _dirLoader;

  LocalDirectoryNotesStorageProvider({
    Future<String?> Function()? directoryLoader,
  }) : _dirLoader = directoryLoader;

  Future<Directory?> _notesDir() async {
    final path = await (_dirLoader != null
        ? _dirLoader()
        : LocalDirectoryConfig.getNotesDirectory());
    if (path == null || path.trim().isEmpty) return null;
    final dir = Directory(p.join(path, 'NotlyfeNotes'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  String get typeId => id;

  @override
  String get displayName => 'Custom Local Folder (Device / Syncthing)';

  @override
  String get description =>
      'Store E2EE-encrypted note files in a custom folder on this device.';

  @override
  Future<bool> isConfigured() async {
    final path = await (_dirLoader != null
        ? _dirLoader()
        : LocalDirectoryConfig.getNotesDirectory());
    return path != null && path.trim().isNotEmpty;
  }

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final dir = await _notesDir();
      if (dir == null) {
        return StorageTestResult(
          success: false,
          message: 'No custom notes folder selected yet.',
          latency: sw.elapsed,
        );
      }
      final probe =
          LocalDirectoryConfig.resolveContainedFile(dir, ['.probe.json']);
      await probe.writeAsString('{"ok":true}');
      final content = await probe.readAsString();
      if (await probe.exists()) await probe.delete();
      return StorageTestResult(
        success: content.contains('"ok":true'),
        message: 'Custom notes folder verified at ${dir.path}.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Custom notes folder probe failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  String _noteFileName(String noteId) =>
      'note_${StorageSecurityHelper.sanitizeSegment(noteId, fallback: 'note')}.json';

  @override
  Future<List<Note>> fetchNotes(String userId) async {
    final dir = await _notesDir();
    if (dir == null) return [];
    final notes = <Note>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('note_') || !name.endsWith('.json')) continue;
      try {
        final raw = await entity.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final note = Note.fromMap(map);
        if (note.userId == userId || note.userId.isEmpty) {
          notes.add(note.copyWith(isSynced: true));
        }
      } catch (_) {}
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<void> upsertNote(Note note) async {
    final dir = await _notesDir();
    if (dir == null) {
      throw Exception('Custom local notes folder is not configured.');
    }
    final file = LocalDirectoryConfig.resolveContainedFile(
      dir,
      [_noteFileName(note.id)],
    );
    await file.writeAsString(jsonEncode(note.toSupabaseMap()));
  }

  @override
  Future<void> deleteNote(Note note) async {
    final dir = await _notesDir();
    if (dir == null) return;
    final file = LocalDirectoryConfig.resolveContainedFile(
      dir,
      [_noteFileName(note.id)],
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async {
    try {
      final dir = await _notesDir();
      if (dir == null) return null;
      final file =
          LocalDirectoryConfig.resolveContainedFile(dir, [_styleFileName]);
      if (!await file.exists()) return null;
      return NoteStyleSettings.tryParseJsonString(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {
    final dir = await _notesDir();
    if (dir == null) return;
    final file =
        LocalDirectoryConfig.resolveContainedFile(dir, [_styleFileName]);
    await file.writeAsString(style.toJsonString());
  }
}
