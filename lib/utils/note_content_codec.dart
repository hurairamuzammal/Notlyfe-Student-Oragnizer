import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:notlyfe/models/note_style_settings.dart';

/// Checklist summary extracted from a Quill document.
class ChecklistStats {
  final int checked;
  final int total;

  const ChecklistStats({required this.checked, required this.total});

  bool get hasChecklists => total > 0;
}

/// Decoded representation of a note's rich content & optional per-note style override.
class DecodedNoteContent {
  final Document document;
  final NoteStyleSettings? noteStyle;
  final bool isRichText;

  const DecodedNoteContent({
    required this.document,
    this.noteStyle,
    required this.isRichText,
  });
}

/// Encodes and decodes rich-text Quill Delta documents (plus optional per-note style)
/// into a portable JSON string stored in `Note.content`.
///
/// Backward-compatible with legacy plain-text notes and raw Delta JSON arrays.
/// Because `Note.toMap()` and `Note.toSupabaseMap()` encrypt `content` via `E2eeService`,
/// rich styling syncs safely across all platforms with zero database schema changes.
class NoteContentCodec {
  NoteContentCodec._();

  static const String envelopeKey = 'notlyfe_doc';

  /// Encodes a Quill [Document] and optional per-note [NoteStyleSettings] override.
  static String encode(
    Document document, {
    NoteStyleSettings? perNoteStyle,
  }) {
    final deltaJson = document.toDelta().toJson();
    final Map<String, dynamic> payload = {
      envelopeKey: 1,
      'delta': deltaJson,
      if (perNoteStyle != null) 'style': perNoteStyle.toJson(),
    };
    return jsonEncode(payload);
  }

  /// Decodes raw `Note.content` (envelope JSON, raw Delta array, or plain text).
  static DecodedNoteContent decode(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return DecodedNoteContent(
        document: Document(),
        isRichText: false,
      );
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded.containsKey('delta')) {
          final deltaList = decoded['delta'];
          if (deltaList is List) {
            final doc = Document.fromJson(deltaList);
            NoteStyleSettings? style;
            if (decoded['style'] is Map) {
              style = NoteStyleSettings.fromJson(
                Map<String, dynamic>.from(decoded['style'] as Map),
              );
            }
            return DecodedNoteContent(
              document: doc,
              noteStyle: style,
              isRichText: true,
            );
          }
        } else if (decoded is List) {
          return DecodedNoteContent(
            document: Document.fromJson(decoded),
            isRichText: true,
          );
        }
      } catch (_) {
        // Fall through to plain-text conversion
      }
    }

    final normalized = rawContent.endsWith('\n') ? rawContent : '$rawContent\n';
    final delta = Delta()..insert(normalized);
    return DecodedNoteContent(
      document: Document.fromDelta(delta),
      isRichText: false,
    );
  }

  /// Fast plain-text extraction for cards, search, and sharing without building a UI editor.
  static String extractPlainText(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        List<dynamic>? ops;
        if (decoded is Map && decoded['delta'] is List) {
          ops = decoded['delta'] as List<dynamic>;
        } else if (decoded is List &&
            decoded.isNotEmpty &&
            decoded.every((op) => op is Map && op.containsKey('insert'))) {
          ops = decoded;
        }
        if (ops != null) {
          final buf = StringBuffer();
          for (final op in ops) {
            if (op is Map && op['insert'] is String) {
              buf.write(op['insert'] as String);
            }
          }
          return buf.toString().trim();
        }
      } catch (_) {}
    }

    return rawContent.trim();
  }

  /// Extracts per-note style override if present, without constructing a Document.
  static NoteStyleSettings? extractPerNoteStyle(String rawContent) {
    final trimmed = rawContent.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['style'] is Map) {
        return NoteStyleSettings.fromJson(
          Map<String, dynamic>.from(decoded['style'] as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Counts checklist items in a rich note for card progress badges.
  static ChecklistStats extractChecklistStats(String rawContent) {
    final trimmed = rawContent.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return const ChecklistStats(checked: 0, total: 0);
    }

    try {
      final decoded = jsonDecode(trimmed);
      final List<dynamic>? ops = decoded is Map && decoded['delta'] is List
          ? decoded['delta'] as List<dynamic>
          : (decoded is List ? decoded : null);
      if (ops == null) return const ChecklistStats(checked: 0, total: 0);

      int total = 0;
      int checked = 0;
      for (final op in ops) {
        if (op is Map && op['attributes'] is Map) {
          final listAttr = (op['attributes'] as Map)['list'];
          if (listAttr == 'checked' || listAttr == 'unchecked') {
            final ins = op['insert'];
            final count =
                ins is String ? '\n'.allMatches(ins).length.clamp(1, 1000) : 1;
            total += count;
            if (listAttr == 'checked') checked += count;
          }
        }
      }
      return ChecklistStats(checked: checked, total: total);
    } catch (_) {
      return const ChecklistStats(checked: 0, total: 0);
    }
  }
}
