// ignore_for_file: non_constant_identifier_names

import 'package:notlyfe/services/e2ee_service.dart';

/// Represents a scheduled task or reminder. Content is stored E2EE-encrypted.
class Todo {
  int? id;
  String user_id;
  String content;
  bool alert;
  bool status;
  DateTime created_at;
  DateTime? reminder_at;
  bool isSynced;

  Todo({
    this.id,
    required this.user_id,
    required this.content,
    required this.alert,
    this.reminder_at,
    required this.created_at,
    this.status = false,
    this.isSynced = false,
  });

  factory Todo.fromMap(Map<String, dynamic> map) {
    final e2ee = E2eeService.instance;
    final rawContent = map['content']?.toString() ?? '';

    return Todo(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse(map['id']?.toString() ?? ''),
      user_id: map['user_id']?.toString() ?? '',
      content: e2ee.decrypt(rawContent),
      alert: _parseBool(map['alert']),
      status: _parseBool(map['status']),
      created_at: _parseDate(map['created_at']) ?? DateTime.now(),
      reminder_at: _parseDate(map['reminder_at']),
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

  Map<String, dynamic> toMap() {
    final e2ee = E2eeService.instance;
    return {
      'id': id,
      'user_id': user_id,
      'content': e2ee.encrypt(content),
      'alert': alert ? 1 : 0,
      'status': status ? 1 : 0,
      'created_at': created_at.toIso8601String(),
      'reminder_at': reminder_at?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    final e2ee = E2eeService.instance;
    return {
      if (id != null) 'id': id,
      'user_id': user_id,
      'content': e2ee.encrypt(content),
      'alert': alert,
      'status': status,
      'created_at': created_at.toIso8601String(),
      'reminder_at': reminder_at?.toIso8601String(),
    };
  }

  Todo copyWith({
    int? id,
    String? user_id,
    String? content,
    bool? alert,
    bool? status,
    DateTime? created_at,
    DateTime? reminder_at,
    bool clearReminderAt = false,
    bool? isSynced,
  }) {
    return Todo(
      id: id ?? this.id,
      user_id: user_id ?? this.user_id,
      content: content ?? this.content,
      alert: alert ?? this.alert,
      status: status ?? this.status,
      created_at: created_at ?? this.created_at,
      reminder_at: clearReminderAt ? null : (reminder_at ?? this.reminder_at),
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
