import 'package:notlyfe/services/e2ee_service.dart';
import 'package:uuid/uuid.dart';

/// Represents a user note. Title and content are stored E2EE-encrypted in
/// local SQLite and remote backends, and decrypted in memory when loaded.
class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String? courseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Note({
    String? id,
    required this.userId,
    this.title = '',
    this.content = '',
    this.courseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? courseId,
    bool clearCourseId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      courseId: clearCourseId ? null : (courseId ?? this.courseId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    final e2ee = E2eeService.instance;
    return {
      'id': id,
      'user_id': userId,
      'title': e2ee.encrypt(title),
      'content': e2ee.encrypt(content),
      'course_id': courseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    final e2ee = E2eeService.instance;
    return {
      'id': id,
      'user_id': userId,
      'title': e2ee.encrypt(title),
      'content': e2ee.encrypt(content),
      'course_id': courseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final e2ee = E2eeService.instance;
    final rawTitle = map['title']?.toString() ?? '';
    final rawContent = map['content']?.toString() ?? '';

    return Note(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      title: e2ee.decrypt(rawTitle),
      content: e2ee.decrypt(rawContent),
      courseId: map['course_id']?.toString(),
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updated_at']) ?? DateTime.now(),
      isSynced: _parseBool(map['is_synced']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  // Intentionally omits decrypted title/content to prevent accidental log leaks.
  @override
  String toString() {
    return 'Note(id: $id, courseId: $courseId, updatedAt: $updatedAt, isSynced: $isSynced)';
  }
}
