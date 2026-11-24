import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/database/local/todos_local_database.dart';
import 'package:notlyfe/database/todo_database.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:notlyfe/providers/connection_status_provider.dart';
import 'package:notlyfe/services/notification_service.dart';

final todosSyncServiceProvider = Provider<TodosSyncService>((ref) {
  final localDb = ref.watch(todosLocalDatabaseProvider);
  final service = TodosSyncService(
    localDb,
    TodoDatabase(),
    ref.read(networkServiceProvider),
  );

  ref.listen<bool>(networkServiceProvider, (previous, current) {
    service.updateConnectivityStatus(current);
    if (previous == false && current == true) {
      final userId = service.getCurrentUserId();
      if (userId != null) {
        unawaited(service.syncAll(userId));
      }
    }
  });

  return service;
});

final autoSyncTodosProvider = Provider<AutoSyncTodosService>((ref) {
  return AutoSyncTodosService(ref.watch(todosSyncServiceProvider));
});

class AutoSyncTodosService {
  final TodosSyncService _syncService;
  AutoSyncTodosService(this._syncService);
  TodosSyncService get service => _syncService;
}

/// Offline-first sync layer for E2EE tasks and local notification reminders.
class TodosSyncService {
  final TodosLocalDatabase _localDb;
  final TodoDatabase _supabaseDb;
  bool _isConnected;

  TodosSyncService(this._localDb, this._supabaseDb, this._isConnected);

  void updateConnectivityStatus(bool isConnected) {
    _isConnected = isConnected;
  }

  bool get isConnected => _isConnected;

  String? getCurrentUserId() {
    try {
      return _supabaseDb.client.auth.currentUser?.id;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  Future<List<Todo>> getTodos(String userId) async {
    try {
      final localTodos = await _localDb.getTodos(userId);
      if (!_isConnected || userId == 'local_user') return localTodos;

      try {
        await _syncTodos(userId);
        return await _localDb.getTodos(userId);
      } catch (e) {
        debugPrint('Todos cloud sync fallback: $e');
        return localTodos;
      }
    } catch (e) {
      debugPrint('Error getting todos: $e');
      return [];
    }
  }

  Future<Todo> createTodo(Todo todo) async {
    await _localDb.createTodo(todo);
    await NotificationService.instance.scheduleTodoReminder(todo);

    if (_isConnected && todo.user_id != 'local_user') {
      try {
        await _supabaseDb.createTodo(todo);
        if (todo.id != null) await _localDb.markTodoSynced(todo.id!);
      } catch (e) {
        debugPrint('Error syncing new todo: $e');
      }
    }
    return todo;
  }

  Future<Todo> updateTodo(Todo todo) async {
    await _localDb.updateTodo(todo);
    await NotificationService.instance.scheduleTodoReminder(todo);

    if (_isConnected && todo.user_id != 'local_user') {
      try {
        await _supabaseDb.updateTodo(todo);
        if (todo.id != null) await _localDb.markTodoSynced(todo.id!);
      } catch (e) {
        debugPrint('Error syncing updated todo: $e');
      }
    }
    return todo;
  }

  Future<Todo> changeStatus(Todo todo) async {
    await _localDb.updateTodo(todo);
    if (todo.status) {
      if (todo.id != null) {
        await NotificationService.instance.cancelReminder(todo.id!);
      }
    } else {
      await NotificationService.instance.scheduleTodoReminder(todo);
    }

    if (_isConnected && todo.user_id != 'local_user') {
      try {
        await _supabaseDb.changeStatus(todo);
        if (todo.id != null) await _localDb.markTodoSynced(todo.id!);
      } catch (e) {
        debugPrint('Error syncing todo status: $e');
      }
    }
    return todo;
  }

  Future<void> deleteTodo(Todo todo) async {
    if (todo.id != null) {
      await _localDb.deleteTodo(todo.id!);
      await NotificationService.instance.cancelReminder(todo.id!);
    }

    if (_isConnected && todo.user_id != 'local_user') {
      try {
        await _supabaseDb.delete(todo);
      } catch (e) {
        debugPrint('Error deleting todo remotely: $e');
      }
    }
  }

  Future<void> _syncTodos(String userId) async {
    if (!_isConnected || userId == 'local_user') return;

    try {
      final unsyncedTodos = await _localDb.getUnsyncedTodos(userId);
      for (final todo in unsyncedTodos) {
        try {
          await _supabaseDb.updateTodo(todo);
          if (todo.id != null) await _localDb.markTodoSynced(todo.id!);
        } catch (_) {
          try {
            await _supabaseDb.createTodo(todo);
            if (todo.id != null) await _localDb.markTodoSynced(todo.id!);
          } catch (createError) {
            debugPrint('Failed to sync todo ${todo.id}: $createError');
          }
        }
      }

      final cloudTodos = await _supabaseDb.getTodos(userId);
      if (cloudTodos.isNotEmpty) {
        await _localDb.saveTodosFromCloud(cloudTodos);
        await NotificationService.instance.syncAllReminders(cloudTodos);
      }
    } catch (e) {
      debugPrint('Error during full todos sync: $e');
    }
  }

  Future<void> syncAll(String userId) async {
    if (_isConnected) {
      await _syncTodos(userId);
    }
  }
}
