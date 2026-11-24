// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

/// Represents an enrolled course board with display color, icon key, and sync state.
class Course {
  final String id;
  final String title;
  final Color color;
  final String image;
  final String user_id;
  final bool is_synced;
  final bool is_hidden;

  Course({
    required this.id,
    required this.title,
    required this.color,
    required this.image,
    this.is_synced = false,
    this.is_hidden = false,
    required this.user_id,
  });

  Course copyWith({
    String? id,
    String? title,
    Color? color,
    String? image,
    String? user_id,
    bool? is_synced,
    bool? is_hidden,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      image: image ?? this.image,
      user_id: user_id ?? this.user_id,
      is_synced: is_synced ?? this.is_synced,
      is_hidden: is_hidden ?? this.is_hidden,
    );
  }

  static String _formatColorHex(Color c) {
    final hex = c.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'color': _formatColorHex(color),
      'image': image,
      'is_synced': is_synced ? 1 : 0,
      'is_hidden': is_hidden ? 1 : 0,
      'user_id': user_id,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'title': title,
      'color': _formatColorHex(color),
      'image': image,
      'is_synced': is_synced,
      'user_id': user_id,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Course',
      color: _hexToColor(map['color']?.toString() ?? '#4F46E5'),
      image: map['image']?.toString() ?? 'assets/cardImages/cn.png',
      is_synced: _parseBool(map['is_synced']),
      is_hidden: _parseBool(map['is_hidden']),
      user_id: map['user_id']?.toString() ?? '',
    );
  }

  static Color _hexToColor(String hexString) {
    final cleaned = hexString.trim().replaceFirst('#', '');
    final normalized = cleaned.length == 6 ? 'ff$cleaned' : cleaned;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed != null ? Color(parsed) : const Color(0xFF4F46E5);
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }
}
