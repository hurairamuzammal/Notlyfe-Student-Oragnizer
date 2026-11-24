import 'package:notlyfe/models/todo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote CRUD operations for E2EE-encrypted tasks in Supabase.
class TodoDatabase {
  TodoDatabase._();
  static final TodoDatabase _instance = TodoDatabase._();
  factory TodoDatabase() => _instance;

  SupabaseClient get client => Supabase.instance.client;
  SupabaseQueryBuilder get _todoTable => client.from('todo');

  Future<void> createTodo(Todo newTodo) async {
    await _todoTable.insert(newTodo.toSupabaseMap());
  }

  Future<List<Todo>> getTodos(String userId) async {
    final response = await _todoTable.select().eq('user_id', userId);
    final data = response as List<dynamic>;
    return data
        .map((todoMap) => Todo.fromMap(Map<String, dynamic>.from(todoMap)))
        .toList();
  }

  Future<void> updateTodo(Todo updatedTodo) async {
    if (updatedTodo.id == null) return;
    await _todoTable
        .update(updatedTodo.toSupabaseMap())
        .eq('id', updatedTodo.id!)
        .eq('user_id', updatedTodo.user_id);
  }

  Future<void> changeStatus(Todo todo) async {
    if (todo.id == null) return;
    await _todoTable
        .update({'status': todo.status})
        .eq('id', todo.id!)
        .eq('user_id', todo.user_id);
  }

  Future<void> delete(Todo todo) async {
    if (todo.id == null) return;
    await _todoTable
        .delete()
        .eq('id', todo.id!)
        .eq('user_id', todo.user_id);
  }
}
