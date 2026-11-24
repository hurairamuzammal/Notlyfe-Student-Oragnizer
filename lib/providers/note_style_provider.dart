import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/providers/notes_sync_provider.dart';
import 'package:notlyfe/services/auth_services.dart';

const String _hiveStyleKeyPrefix = 'note_default_style_v1';

/// Manages the user's default note style with Hive persistence and remote sync.
class NoteStyleNotifier extends StateNotifier<NoteStyleSettings> {
  final Ref _ref;

  NoteStyleNotifier(this._ref) : super(_loadInitial());

  static String _storageKeyForUser(String? userId) {
    if (userId == null || userId.isEmpty) return _hiveStyleKeyPrefix;
    return '${_hiveStyleKeyPrefix}_$userId';
  }

  static NoteStyleSettings _loadInitial() {
    try {
      if (!Hive.isBoxOpen('testBox')) return NoteStyleSettings();
      String? uid;
      try {
        uid = AuthServices().getCurrentUserId();
      } catch (_) {}

      final box = Hive.box('testBox');
      final raw = box.get(_storageKeyForUser(uid)) ?? box.get(_hiveStyleKeyPrefix);
      if (raw is String) {
        return NoteStyleSettings.tryParseJsonString(raw) ?? NoteStyleSettings();
      }
      if (raw is Map) {
        return NoteStyleSettings.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return NoteStyleSettings();
  }

  Future<void> _persistLocal(NoteStyleSettings style, String? userId) async {
    try {
      if (Hive.isBoxOpen('testBox')) {
        await Hive.box('testBox')
            .put(_storageKeyForUser(userId), style.toJsonString());
      }
    } catch (_) {}
  }

  Future<void> saveDefaultStyle(NoteStyleSettings style) async {
    final stamped = style.copyWith(updatedAt: DateTime.now().toUtc());
    state = stamped;

    String? userId;
    try {
      userId = AuthServices().getCurrentUserId();
    } catch (_) {}
    await _persistLocal(stamped, userId);

    if (userId != null && userId.isNotEmpty) {
      try {
        await _ref
            .read(notesSyncServiceProvider)
            .saveDefaultNoteStyle(userId, stamped);
      } catch (_) {}
    }
  }

  Future<void> syncFromRemote() async {
    try {
      final userId = AuthServices().getCurrentUserId();
      final remote = await _ref
          .read(notesSyncServiceProvider)
          .fetchDefaultNoteStyle(userId);
      if (!mounted) return;
      if (remote != null && remote.updatedAt.isAfter(state.updatedAt)) {
        state = remote;
        await _persistLocal(remote, userId);
      }
    } catch (_) {}
  }

  Future<void> resetToDefault() => saveDefaultStyle(NoteStyleSettings());
}

final noteStyleProvider =
    StateNotifierProvider<NoteStyleNotifier, NoteStyleSettings>(
  (ref) => NoteStyleNotifier(ref),
);
