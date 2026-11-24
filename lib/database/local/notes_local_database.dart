import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/providers/notes_providers.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final notesLocalDatabaseProvider = Provider<NotesLocalDatabase>((ref) {
  return NotesLocalDatabase();
});

/// Local SQLite store for offline-first E2EE-encrypted notes.
class NotesLocalDatabase {
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
    final path = join(dbPath, 'notes.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            course_id TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info(notes)');
          final hasTags = columns.any((c) => c['name'] == 'tags');
          if (!hasTags) {
            await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT DEFAULT ''");
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

  String _getSortOrderBy(NoteSortOption? sortOption) {
    switch (sortOption) {
      case NoteSortOption.updatedDesc:
        return 'updated_at DESC';
      case NoteSortOption.updatedAsc:
        return 'updated_at ASC';
      case NoteSortOption.createdDesc:
        return 'created_at DESC';
      case NoteSortOption.createdAsc:
        return 'created_at ASC';
      case NoteSortOption.titleAsc:
      case NoteSortOption.titleDesc:
        // Titles are E2EE ciphertext in SQLite, so title sorting happens in Dart after decrypting.
        return 'updated_at DESC';
      default:
        return 'updated_at DESC';
    }
  }

  void _applyInMemoryTitleSort(List<Note> notes, NoteSortOption? sortOption) {
    if (sortOption == NoteSortOption.titleAsc) {
      notes.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (sortOption == NoteSortOption.titleDesc) {
      notes.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    }
  }

  Future<void> createNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Note?> getNote(String id) async {
    final db = await database;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<List<Note>> getNotes(
    String userId, {
    NoteSortOption? sortOption,
  }) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: _getSortOrderBy(sortOption),
    );
    final notes = maps.map(Note.fromMap).toList();
    _applyInMemoryTitleSort(notes, sortOption);
    return notes;
  }

  Future<List<Note>> getNotesByCourse(
    String userId,
    String courseId, {
    NoteSortOption? sortOption,
  }) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'user_id = ? AND course_id = ?',
      whereArgs: [userId, courseId],
      orderBy: _getSortOrderBy(sortOption),
    );
    final notes = maps.map(Note.fromMap).toList();
    _applyInMemoryTitleSort(notes, sortOption);
    return notes;
  }

  Future<List<Note>> getUnsyncedNotes(String userId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'user_id = ? AND is_synced = ?',
      whereArgs: [userId, 0],
    );
    return maps.map(Note.fromMap).toList();
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [note.id, note.userId],
    );
  }

  Future<void> markNoteSynced(String id) async {
    final db = await database;
    await db.update(
      'notes',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Merges remote notes without overwriting newer local unsynced edits.
  Future<void> saveNotesFromCloud(List<Note> notes) async {
    if (notes.isEmpty) return;
    final db = await database;
    final userId = notes.first.userId;

    final unsyncedRows = await db.query(
      'notes',
      columns: ['id', 'updated_at'],
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    final unsyncedUpdatedAt = <String, DateTime>{};
    for (final row in unsyncedRows) {
      final parsed = DateTime.tryParse(row['updated_at']?.toString() ?? '');
      if (parsed != null) {
        unsyncedUpdatedAt[row['id'].toString()] = parsed;
      }
    }

    final batch = db.batch();
    for (final note in notes) {
      final localTime = unsyncedUpdatedAt[note.id];
      if (localTime != null && localTime.isAfter(note.updatedAt)) {
        continue;
      }
      final syncedNote = note.copyWith(isSynced: true);
      batch.insert(
        'notes',
        syncedNote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
