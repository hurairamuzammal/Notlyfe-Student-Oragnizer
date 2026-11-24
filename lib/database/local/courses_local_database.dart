import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/course.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final coursesLocalDatabaseProvider = Provider<CoursesLocalDatabase>((ref) {
  return CoursesLocalDatabase();
});

/// Local SQLite store for offline-first courses.
class CoursesLocalDatabase {
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
    final path = join(dbPath, 'courses.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            color TEXT NOT NULL,
            image TEXT NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0,
            is_hidden INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info(courses)');
          final hasHidden = columns.any((c) => c['name'] == 'is_hidden');
          if (!hasHidden) {
            await db.execute(
              'ALTER TABLE courses ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
      },
    );
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> createCourse(Course course) async {
    final db = await database;
    await db.insert(
      'courses',
      course.toMap()..['is_synced'] = 0,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Course?> getCourse(String id) async {
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Course.fromMap(maps.first);
  }

  Future<List<Course>> getCourses(String userId) async {
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'title ASC',
    );
    return maps.map(Course.fromMap).toList();
  }

  Future<void> updateCourse(Course course) async {
    final db = await database;
    await db.update(
      'courses',
      course.toMap()..['is_synced'] = 0,
      where: 'id = ? AND user_id = ?',
      whereArgs: [course.id, course.user_id],
    );
  }

  Future<void> deleteCourse(String id) async {
    final db = await database;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markCourseSynced(String id) async {
    final db = await database;
    await db.update(
      'courses',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Course>> getUnsyncedCourses(String userId) async {
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'user_id = ? AND is_synced = ?',
      whereArgs: [userId, 0],
    );
    return maps.map(Course.fromMap).toList();
  }

  Future<void> setCourseHidden(String id, bool isHidden) async {
    final db = await database;
    await db.update(
      'courses',
      {'is_hidden': isHidden ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Merges cloud courses while preserving local hidden flags and unsynced edits.
  Future<void> saveCoursesFromCloud(List<Course> courses) async {
    if (courses.isEmpty) return;
    final db = await database;
    final userId = courses.first.user_id;

    final existingRows = await db.query(
      'courses',
      columns: ['id', 'is_hidden', 'is_synced'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final hiddenIds = <String>{};
    final unsyncedIds = <String>{};
    for (final row in existingRows) {
      final id = row['id'].toString();
      if (row['is_hidden'] == 1) hiddenIds.add(id);
      if (row['is_synced'] == 0) unsyncedIds.add(id);
    }

    final batch = db.batch();
    for (final course in courses) {
      if (unsyncedIds.contains(course.id)) continue;
      final isHidden = hiddenIds.contains(course.id) || course.is_hidden;
      final syncedCourse = course.toMap()
        ..['is_synced'] = 1
        ..['is_hidden'] = isHidden ? 1 : 0;
      batch.insert(
        'courses',
        syncedCourse,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
