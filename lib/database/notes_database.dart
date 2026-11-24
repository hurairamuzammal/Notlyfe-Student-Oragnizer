import 'package:flutter/foundation.dart';
import 'package:notlyfe/models/note.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote CRUD operations for E2EE-encrypted notes in Supabase.
class NotesDatabase {
  SupabaseClient get client => Supabase.instance.client;

  Future<List<Note>> getNotes(String userId) async {
    try {
      final response = await client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return response.map<Note>((json) => Note.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching notes: $e');
      return [];
    }
  }

  Future<List<Note>> getNotesByCourse(String userId, String courseId) async {
    try {
      final response = await client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .order('updated_at', ascending: false);

      return response.map<Note>((json) => Note.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching course notes: $e');
      return [];
    }
  }

  Future<void> upsertNote(Note note) async {
    await client.from('notes').upsert(note.toSupabaseMap());
  }

  Future<void> deleteNote(Note note) async {
    await client
        .from('notes')
        .delete()
        .eq('id', note.id)
        .eq('user_id', note.userId);
  }
}
