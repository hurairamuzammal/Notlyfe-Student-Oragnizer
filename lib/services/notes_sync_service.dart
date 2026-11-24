import 'package:flutter/foundation.dart';
import 'package:notlyfe/database/local/notes_local_database.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/providers/notes_providers.dart';
import 'package:notlyfe/services/storage/providers/local_directory_providers.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Offline-first notes synchronization service backed by the active
/// [CustomNotesStorageProvider] from [StorageBackendRegistry].
class NotesSyncService {
  final NotesLocalDatabase _localDb;
  final StorageBackendRegistry _registry;
  bool _isConnected;

  NotesSyncService(
    this._localDb,
    this._isConnected, {
    StorageBackendRegistry? registry,
  }) : _registry = registry ?? StorageBackendRegistry.instance;

  void updateConnectivityStatus(bool isConnected) {
    _isConnected = isConnected;
  }

  bool get isConnected => _isConnected;

  String? getCurrentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get _canSyncToActiveProvider {
    final active = _registry.activeNotesProvider;
    if (active.typeId == LocalDirectoryNotesStorageProvider.id) return true;
    return _isConnected;
  }

  Future<List<Note>> getNotes(
    String userId, {
    NoteSortOption? sortOption,
  }) async {
    try {
      await _registry.initialize();
      final localNotes =
          await _localDb.getNotes(userId, sortOption: sortOption);
      if (!_canSyncToActiveProvider) return localNotes;

      try {
        await _syncNotes(userId);
        return await _localDb.getNotes(userId, sortOption: sortOption);
      } catch (e) {
        debugPrint('Notes sync fallback to local: $e');
        return localNotes;
      }
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }

  Future<List<Note>> getNotesByCourse(
    String userId,
    String courseId, {
    NoteSortOption? sortOption,
  }) async {
    try {
      await _registry.initialize();
      final localNotes = await _localDb.getNotesByCourse(
        userId,
        courseId,
        sortOption: sortOption,
      );
      if (!_canSyncToActiveProvider) return localNotes;

      try {
        await _syncNotes(userId);
        return await _localDb.getNotesByCourse(
          userId,
          courseId,
          sortOption: sortOption,
        );
      } catch (e) {
        debugPrint('Course notes sync fallback to local: $e');
        return localNotes;
      }
    } catch (e) {
      debugPrint('Error getting course notes: $e');
      return [];
    }
  }

  Future<Note> createNote(Note note) async {
    await _registry.initialize();
    await _localDb.createNote(note);

    if (_canSyncToActiveProvider) {
      try {
        await _registry.activeNotesProvider.upsertNote(note);
        await _localDb.markNoteSynced(note.id);
        return note.copyWith(isSynced: true);
      } catch (e) {
        debugPrint('Error syncing created note: $e');
      }
    }
    return note;
  }

  Future<Note> updateNote(Note note) async {
    await _registry.initialize();
    await _localDb.updateNote(note);

    if (_canSyncToActiveProvider) {
      try {
        await _registry.activeNotesProvider.upsertNote(note);
        await _localDb.markNoteSynced(note.id);
        return note.copyWith(isSynced: true);
      } catch (e) {
        debugPrint('Error syncing updated note: $e');
      }
    }
    return note;
  }

  Future<void> deleteNote(Note note) async {
    await _registry.initialize();
    await _localDb.deleteNote(note.id);

    if (_canSyncToActiveProvider) {
      try {
        await _registry.activeNotesProvider.deleteNote(note);
      } catch (e) {
        debugPrint('Error deleting note from remote storage: $e');
      }
    }
  }

  Future<void> _syncNotes(String userId) async {
    if (!_canSyncToActiveProvider) return;
    final provider = _registry.activeNotesProvider;
    if (!await provider.isConfigured()) return;

    try {
      final unsyncedNotes = await _localDb.getUnsyncedNotes(userId);
      for (final note in unsyncedNotes) {
        try {
          await provider.upsertNote(note);
          await _localDb.markNoteSynced(note.id);
        } catch (e) {
          debugPrint('Failed syncing unsynced note ${note.id}: $e');
        }
      }

      final remoteNotes = await provider.fetchNotes(userId);
      if (remoteNotes.isNotEmpty) {
        await _localDb.saveNotesFromCloud(remoteNotes);
      }
    } catch (e) {
      debugPrint('Notes full sync error: $e');
    }
  }

  Future<void> syncAll(String userId) async {
    await _registry.initialize();
    await _syncNotes(userId);
  }

  /// Pushes all local notes to the currently selected notes storage location
  /// (useful after switching storage location in Settings).
  Future<int> pushAllLocalNotesToActiveProvider(String userId) async {
    await _registry.initialize();
    final provider = _registry.activeNotesProvider;
    if (!await provider.isConfigured()) {
      throw Exception('${provider.displayName} is not configured yet.');
    }
    final localNotes = await _localDb.getNotes(userId);
    var pushed = 0;
    for (final note in localNotes) {
      await provider.upsertNote(note);
      await _localDb.markNoteSynced(note.id);
      pushed++;
    }
    return pushed;
  }

  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async {
    await _registry.initialize();
    if (!_canSyncToActiveProvider) return null;
    return _registry.activeNotesProvider.fetchDefaultNoteStyle(userId);
  }

  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {
    await _registry.initialize();
    if (!_canSyncToActiveProvider) return;
    await _registry.activeNotesProvider.saveDefaultNoteStyle(userId, style);
  }
}
