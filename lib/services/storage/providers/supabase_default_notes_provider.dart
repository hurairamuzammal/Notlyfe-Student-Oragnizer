import 'package:notlyfe/database/notes_database.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Default Supabase notes storage provider (E2EE encrypted via `Note.toSupabaseMap`).
class SupabaseDefaultNotesProvider extends CustomNotesStorageProvider {
  static const String id = 'supabase_default';
  static const String _styleMetadataKey = 'notlyfe_note_style';

  final NotesDatabase _notesDb = NotesDatabase();

  @override
  String get typeId => id;

  @override
  String get displayName => 'Notlyfe Cloud (Supabase • Default)';

  @override
  String get description =>
      'Built-in E2EE cloud sync via Supabase. Ready out of the box.';

  @override
  Future<bool> isConfigured() async {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return StorageTestResult(
          success: false,
          message: 'Sign in required to test Supabase cloud notes.',
          latency: sw.elapsed,
        );
      }
      await Supabase.instance.client
          .from('notes')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      return StorageTestResult(
        success: true,
        message: 'Supabase E2EE notes endpoint reachable and authenticated.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Supabase notes test failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  @override
  Future<List<Note>> fetchNotes(String userId) {
    return _notesDb.getNotes(userId);
  }

  @override
  Future<void> upsertNote(Note note) async {
    await _notesDb.client.from('notes').upsert(note.toSupabaseMap());
  }

  @override
  Future<void> deleteNote(Note note) {
    return _notesDb.deleteNote(note);
  }

  @override
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final raw = user?.userMetadata?[_styleMetadataKey];
      if (raw is Map) {
        return NoteStyleSettings.fromJson(Map<String, dynamic>.from(raw));
      }
      if (raw is String) {
        return NoteStyleSettings.tryParseJsonString(raw);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.auth.updateUser(
        UserAttributes(data: {_styleMetadataKey: style.toJson()}),
      );
    } catch (_) {}
  }
}
