import 'package:notlyfe/database/local/todos_local_database.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches scheduled reminder items for the Calendar view.
class CalanderDatabase {
  Future<List<Map<String, dynamic>>> getEvents() async {
    final userId = AuthServices().getCurrentUserId();

    // Local guest accounts only exist in SQLite, not Supabase.
    if (userId == 'local_user') {
      final todos = await TodosLocalDatabase().getTodos(userId);
      return todos
          .where((t) => t.reminder_at != null)
          .map((t) => t.toSupabaseMap())
          .toList();
    }

    final response = await Supabase.instance.client
        .from('todo')
        .select()
        .eq('user_id', userId)
        .not('reminder_at', 'is', null);

    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
