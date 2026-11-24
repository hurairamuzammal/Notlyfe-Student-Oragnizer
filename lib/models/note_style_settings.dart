import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font option available inside the Notlyfe rich-text note editor and default note styles.
class NoteFontOption {
  final String key;
  final String displayName;
  final String category;

  const NoteFontOption({
    required this.key,
    required this.displayName,
    required this.category,
  });

  /// Resolves a [TextStyle] for this font using [GoogleFonts] when applicable.
  TextStyle toTextStyle({TextStyle? base}) {
    final fallback = base ?? const TextStyle();
    switch (key) {
      case 'sans-serif':
      case 'System':
        return fallback;
      case 'serif':
        return fallback.copyWith(fontFamily: 'serif');
      case 'monospace':
        return fallback.copyWith(fontFamily: 'monospace');
      default:
        try {
          return GoogleFonts.getFont(key, textStyle: fallback);
        } catch (_) {
          return fallback.copyWith(fontFamily: key);
        }
    }
  }
}

/// Curated fonts for note-taking (sans, serif, handwriting, monospace) —
/// portable by name across Android, iOS, Web, and Desktop.
const List<NoteFontOption> availableNoteFonts = [
  NoteFontOption(key: 'Poppins', displayName: 'Poppins', category: 'Sans'),
  NoteFontOption(key: 'Inter', displayName: 'Inter', category: 'Sans'),
  NoteFontOption(key: 'Roboto', displayName: 'Roboto', category: 'Sans'),
  NoteFontOption(key: 'Outfit', displayName: 'Outfit', category: 'Expressive'),
  NoteFontOption(key: 'Open Sans', displayName: 'Open Sans', category: 'Sans'),
  NoteFontOption(key: 'Lora', displayName: 'Lora', category: 'Serif'),
  NoteFontOption(
      key: 'Merriweather', displayName: 'Merriweather', category: 'Serif'),
  NoteFontOption(
      key: 'Caveat', displayName: 'Caveat', category: 'Handwriting'),
  NoteFontOption(
      key: 'Patrick Hand', displayName: 'Patrick Hand', category: 'Handwriting'),
  NoteFontOption(
      key: 'Space Grotesk', displayName: 'Space Grotesk', category: 'Tech'),
  NoteFontOption(
      key: 'JetBrains Mono', displayName: 'JetBrains Mono', category: 'Code'),
];

/// Resolves any stored font key (including Google Fonts or system aliases)
/// into a [TextStyle] carrying only `fontFamily` / `fontFamilyFallback` so it
/// merges cleanly with bold, italic, color, and highlight attributes.
TextStyle resolveNoteFontStyle(String fontKey) {
  final trimmed = fontKey.trim();
  if (trimmed.isEmpty || trimmed == 'System' || trimmed == 'sans-serif') {
    return const TextStyle();
  }
  if (trimmed == 'serif' || trimmed == 'monospace') {
    return TextStyle(fontFamily: trimmed);
  }
  try {
    final gf = GoogleFonts.getFont(trimmed);
    return TextStyle(
      fontFamily: gf.fontFamily,
      fontFamilyFallback: gf.fontFamilyFallback,
    );
  } catch (_) {
    return TextStyle(fontFamily: trimmed);
  }
}

/// Curated harmonious text colors for note styling.
const List<Color> noteTextPalette = [
  Color(0xFF1C1B1F),
  Color(0xFF374151),
  Color(0xFF1D4ED8),
  Color(0xFF0F766E),
  Color(0xFF15803D),
  Color(0xFFB45309),
  Color(0xFFBE123C),
  Color(0xFF7E22CE),
  Color(0xFFF3F4F6),
];

/// Curated soft highlight / background colors for note text spans.
const List<Color> noteHighlightPalette = [
  Color(0xFFFEF08A), // Soft Yellow
  Color(0xFFBBF7D0), // Mint Green
  Color(0xFFBAE6FD), // Sky Blue
  Color(0xFFE9D5FF), // Lavender
  Color(0xFFFECDD3), // Rose
  Color(0xFFFED7AA), // Peach
  Color(0xFFE2E8F0), // Cool Gray
];

/// Curated note canvas / paper tints (null = adaptive Material You surface).
const List<int?> notePaperTintPalette = [
  null, // Adaptive Surface
  0xFFFFFBF0, // Warm Cream
  0xFFF2FBF5, // Sage Mist
  0xFFF4F6FF, // Periwinkle Air
  0xFFFFF4F7, // Rose Petal
  0xFF1E222B, // Midnight Ink
];

/// User-customizable, cross-platform syncable default style for notes.
@immutable
class NoteStyleSettings {
  final String fontFamily;
  final double bodyFontSize;
  final double lineHeight;
  final double headingScale;
  final int? defaultTextColorValue;
  final int? defaultHighlightColorValue;
  final int? paperColorValue;
  final DateTime updatedAt;

  NoteStyleSettings({
    this.fontFamily = 'Poppins',
    this.bodyFontSize = 16.0,
    this.lineHeight = 1.5,
    this.headingScale = 1.0,
    this.defaultTextColorValue,
    this.defaultHighlightColorValue,
    this.paperColorValue,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  Color? get defaultTextColor =>
      defaultTextColorValue != null ? Color(defaultTextColorValue!) : null;

  Color? get defaultHighlightColor => defaultHighlightColorValue != null
      ? Color(defaultHighlightColorValue!)
      : null;

  Color? get paperColor =>
      paperColorValue != null ? Color(paperColorValue!) : null;

  bool get isDefault =>
      fontFamily == 'Poppins' &&
      bodyFontSize == 16.0 &&
      lineHeight == 1.5 &&
      headingScale == 1.0 &&
      defaultTextColorValue == null &&
      defaultHighlightColorValue == null &&
      paperColorValue == null;

  NoteStyleSettings copyWith({
    String? fontFamily,
    double? bodyFontSize,
    double? lineHeight,
    double? headingScale,
    int? defaultTextColorValue,
    bool clearTextColor = false,
    int? defaultHighlightColorValue,
    bool clearHighlightColor = false,
    int? paperColorValue,
    bool clearPaperColor = false,
    DateTime? updatedAt,
  }) {
    return NoteStyleSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      headingScale: headingScale ?? this.headingScale,
      defaultTextColorValue: clearTextColor
          ? null
          : (defaultTextColorValue ?? this.defaultTextColorValue),
      defaultHighlightColorValue: clearHighlightColor
          ? null
          : (defaultHighlightColorValue ?? this.defaultHighlightColorValue),
      paperColorValue:
          clearPaperColor ? null : (paperColorValue ?? this.paperColorValue),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'fontFamily': fontFamily,
        'bodyFontSize': bodyFontSize,
        'lineHeight': lineHeight,
        'headingScale': headingScale,
        'defaultTextColorValue': defaultTextColorValue,
        'defaultHighlightColorValue': defaultHighlightColorValue,
        'paperColorValue': paperColorValue,
        'updatedAt': updatedAt.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory NoteStyleSettings.fromJson(Map<String, dynamic> json) {
    final size = (json['bodyFontSize'] as num?)?.toDouble() ?? 16.0;
    final lh = (json['lineHeight'] as num?)?.toDouble() ?? 1.5;
    final hs = (json['headingScale'] as num?)?.toDouble() ?? 1.0;

    return NoteStyleSettings(
      fontFamily: (json['fontFamily'] as String?)?.trim().isNotEmpty == true
          ? (json['fontFamily'] as String).trim()
          : 'Poppins',
      bodyFontSize: size.clamp(12.0, 24.0),
      lineHeight: lh.clamp(1.1, 2.2),
      headingScale: hs.clamp(0.8, 1.5),
      defaultTextColorValue: json['defaultTextColorValue'] as int?,
      defaultHighlightColorValue: json['defaultHighlightColorValue'] as int?,
      paperColorValue: json['paperColorValue'] as int?,
      updatedAt: json['updatedAt'] is String
          ? (DateTime.tryParse(json['updatedAt'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static NoteStyleSettings? tryParseJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return NoteStyleSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return NoteStyleSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteStyleSettings &&
        other.fontFamily == fontFamily &&
        other.bodyFontSize == bodyFontSize &&
        other.lineHeight == lineHeight &&
        other.headingScale == headingScale &&
        other.defaultTextColorValue == defaultTextColorValue &&
        other.defaultHighlightColorValue == defaultHighlightColorValue &&
        other.paperColorValue == paperColorValue;
  }

  @override
  int get hashCode => Object.hash(
        fontFamily,
        bodyFontSize,
        lineHeight,
        headingScale,
        defaultTextColorValue,
        defaultHighlightColorValue,
        paperColorValue,
      );
}
