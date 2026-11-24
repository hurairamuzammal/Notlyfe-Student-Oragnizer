import 'dart:convert';
import 'dart:io';

import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';

/// Built-in Google Drive file storage provider using strict `drive.file` scope.
class GoogleDriveFileStorageProvider extends CustomFileStorageProvider {
  static const String id = 'google_drive';

  final GoogleDriveStorageService _drive = GoogleDriveStorageService.instance;

  @override
  String get typeId => id;

  @override
  String get displayName => 'Google Drive (Notlyfe Folder)';

  @override
  String get description =>
      'Stores course files privately inside your own Notlyfe/<Course> Drive folder.';

  @override
  String get pathScheme => 'gdrive';

  @override
  Future<bool> isConfigured() => _drive.isDriveConnected();

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final connected = await _drive.isDriveConnected();
      if (!connected) {
        return StorageTestResult(
          success: false,
          message: 'Google Drive is not connected yet.',
          latency: sw.elapsed,
        );
      }
      final ok = await _drive.testDriveFolderAccess();
      final email = await _drive.getConnectedEmail();
      return StorageTestResult(
        success: ok,
        message: ok
            ? 'Connected to Google Drive (${email ?? 'Notlyfe folder verified'}).'
            : 'Unable to access Notlyfe folder on Google Drive. Try reconnecting.',
        latency: sw.elapsed,
        details: {'email': email ?? ''},
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Google Drive probe failed: $e',
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
  }) {
    return _drive.uploadCourseFile(
      courseId: courseId,
      courseTitle: courseTitle,
      file: file,
      fileName: fileName,
      mimeType: mimeType,
      userId: userId,
      onProgress: onProgress,
    );
  }

  @override
  Future<List<UserFiles>> listFiles({
    required String courseId,
    required String courseTitle,
    required String userId,
  }) {
    return _drive.listCourseFiles(
      courseId: courseId,
      courseTitle: courseTitle,
      userId: userId,
    );
  }

  @override
  Future<List<UserFiles>> listAllCoursesFiles({
    required List<Course> courses,
    required String userId,
  }) {
    return _drive.listAllCoursesFiles(courses: courses, userId: userId);
  }

  @override
  Future<bool> downloadFile({
    required UserFiles file,
    required File destinationFile,
    StorageProgressCallback? onProgress,
  }) {
    return _drive.downloadDriveFile(
      driveFileId: file.driveFileId,
      destinationFile: destinationFile,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> deleteFile(UserFiles file) {
    return _drive.deleteDriveFile(file.driveFileId);
  }
}

/// Stores E2EE-encrypted notes & default note styles inside `Notlyfe/Notes`
/// on the user's own Google Drive (`drive.file` scope) — zero server cost.
class GoogleDriveNotesStorageProvider extends CustomNotesStorageProvider {
  static const String id = 'google_drive_notes';
  static const String _notesFolder = 'Notes';
  static const String _styleFileName = 'default_style.json';

  final GoogleDriveStorageService _drive = GoogleDriveStorageService.instance;

  @override
  String get typeId => id;

  @override
  String get displayName => 'Google Drive (Notlyfe/Notes)';

  @override
  String get description =>
      'Syncs E2EE-encrypted notes & default styles in your own Google Drive.';

  @override
  Future<bool> isConfigured() => _drive.isDriveConnected();

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final connected = await _drive.isDriveConnected();
      if (!connected) {
        return StorageTestResult(
          success: false,
          message: 'Connect Google Drive first to store notes there.',
          latency: sw.elapsed,
        );
      }
      final ok = await _drive.testDriveFolderAccess();
      return StorageTestResult(
        success: ok,
        message: ok
            ? 'Notlyfe/Notes folder on Google Drive is ready.'
            : 'Drive folder access check failed.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Google Drive notes test failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  String _noteFileName(String noteId) =>
      'note_${StorageSecurityHelper.sanitizeSegment(noteId, fallback: 'note')}.json';

  @override
  Future<List<Note>> fetchNotes(String userId) async {
    final docs = await _drive.readAllJsonDocuments(subfolderName: _notesFolder);
    final notes = <Note>[];
    for (final entry in docs.entries) {
      if (!entry.key.startsWith('note_') || !entry.key.endsWith('.json')) {
        continue;
      }
      try {
        final map = jsonDecode(entry.value) as Map<String, dynamic>;
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
    final payload = jsonEncode(note.toSupabaseMap());
    await _drive.upsertJsonDocument(
      subfolderName: _notesFolder,
      fileName: _noteFileName(note.id),
      jsonContent: payload,
    );
  }

  @override
  Future<void> deleteNote(Note note) async {
    await _drive.deleteNamedFileInSubfolder(
      subfolderName: _notesFolder,
      fileName: _noteFileName(note.id),
    );
  }

  @override
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async {
    try {
      final docs =
          await _drive.readAllJsonDocuments(subfolderName: _notesFolder);
      final raw = docs[_styleFileName];
      return NoteStyleSettings.tryParseJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {
    await _drive.upsertJsonDocument(
      subfolderName: _notesFolder,
      fileName: _styleFileName,
      jsonContent: style.toJsonString(),
    );
  }
}
