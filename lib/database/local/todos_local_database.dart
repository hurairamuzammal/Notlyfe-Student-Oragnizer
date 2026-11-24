import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final todosLocalDatabaseProvider = Provider<TodosLocalDatabase>((ref) {
  return TodosLocalDatabase();
});

/// Local SQLite store for offline-first E2EE-encrypted tasks.
class TodosLocalDatabase {
  static Database? _database;
  static Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
    } catch (e, st) {
      _initCompleter!.completeError(e, st);
      rethrow;
    } finally {
      _initCompleter = null;
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'todos.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos (
            id INTEGER PRIMARY KEY,
            user_id TEXT NOT NULL,
            content TEXT NOT NULL,
            alert INTEGER NOT NULL DEFAULT 0,
            status INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            reminder_at TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> createTodo(Todo todo) async {
    final db = await database;
    await db.insert(
      'todos',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Todo?> getTodo(int id) async {
    final db = await database;
    final maps = await db.query('todos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Todo.fromMap(maps.first);
  }

  Future<List<Todo>> getTodos(String userId) async {
    final db = await database;
    final maps = await db.query(
      'todos',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map(Todo.fromMap).toList();
  }

  Future<List<Todo>> getUnsyncedTodos(String userId) async {
    final db = await database;
    final maps = await db.query(
      'todos',
      where: 'user_id = ? AND is_synced = ?',
      whereArgs: [userId, 0],
    );
    return maps.map(Todo.fromMap).toList();
  }

  Future<void> updateTodo(Todo todo) async {
    if (todo.id == null) return;
    final db = await database;
    await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [todo.id, todo.user_id],
    );
  }

  Future<void> markTodoSynced(int id) async {
    final db = await database;
    await db.update(
      'todos',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTodo(int id) async {
    final db = await database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveTodosFromCloud(List<Todo> todos) async {
    if (todos.isEmpty) return;
    final db = await database;
    final userId = todos.first.user_id;

    final unsyncedRows = await db.query(
      'todos',
      columns: ['id'],
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    final unsyncedIds = unsyncedRows.map((r) => r['id']).toSet();

    final batch = db.batch();
    for (final todo in todos) {
      if (todo.id != null && unsyncedIds.contains(todo.id)) continue;
      final map = todo.toMap()..['is_synced'] = 1;
      batch.insert(
        'todos',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
