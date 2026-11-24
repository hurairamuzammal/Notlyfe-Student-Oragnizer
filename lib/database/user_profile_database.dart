import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:notlyfe/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and updates the signed-in user's display name across Supabase and local cache.
class UserProfileDatabase {
  SupabaseQueryBuilder get _profileTable =>
      Supabase.instance.client.from('user_profile');

  /// Normalizes raw metadata or email prefixes into a clean display name.
  static String sanitizeDisplayName(String? rawName, {String? fallbackEmail}) {
    var candidate = (rawName ?? '').trim();

    if (candidate.contains('@')) {
      candidate = candidate.split('@').first.trim();
    }

    final isGeneratedToken = candidate.isEmpty ||
        candidate.toLowerCase() == 'anonymous' ||
        candidate.toLowerCase() == 'user' ||
        RegExp(r'^[0-9a-fA-F-]{16,}$').hasMatch(candidate) ||
        RegExp(r'^[a-zA-Z0-9_-]{24,}$').hasMatch(candidate);

    if (isGeneratedToken) {
      if (fallbackEmail != null && fallbackEmail.contains('@')) {
        candidate = fallbackEmail.split('@').first.trim();
      } else {
        return 'Notlyfe User';
      }
    }

    if (candidate.contains(' ')) {
      final words = candidate
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .toList();
      if (words.isNotEmpty) return words.join(' ');
    }

    var cleaned = candidate.replaceAll(RegExp(r'\d+$'), '');
    if (cleaned.isEmpty) cleaned = candidate;

    final parts = cleaned
        .split(RegExp(r'[._\-]+'))
        .where((p) => p.trim().isNotEmpty)
        .map((p) {
      final t = p.trim();
      return t[0].toUpperCase() + t.substring(1).toLowerCase();
    }).toList();

    return parts.isEmpty ? 'Notlyfe User' : parts.join(' ');
  }

  Future<void> addUserProfile(String userId, String name) =>
      updateUserName(userId, name);

  Future<void> updateUserName(String userId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // Cache strictly under userId to avoid leaking names across accounts.
    try {
      if (Hive.isBoxOpen('testBox')) {
        await Hive.box('testBox').put('cached_user_name_$userId', trimmed);
      }
    } catch (_) {}

    try {
      final existing = await _profileTable.select().eq('user_id', userId);
      if (existing.isNotEmpty) {
        await _profileTable
            .update({'full_name': trimmed}).eq('user_id', userId);
      } else {
        await _profileTable.insert({'user_id': userId, 'full_name': trimmed});
      }
    } catch (_) {
      try {
        await _profileTable.upsert(
          {'user_id': userId, 'full_name': trimmed},
          onConflict: 'user_id',
        );
      } catch (_) {}
    }

    // Only update auth metadata when modifying the active authenticated user.
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'full_name': trimmed}),
        );
      }
    } catch (_) {}
  }

  Future<String> getUserName(String userId) async {
    if (userId.isEmpty) return '';

    final currentUser = Supabase.instance.client.auth.currentUser;
    final email = currentUser?.email;

    try {
      final response = await _profileTable.select().eq('user_id', userId);
      if (response.isNotEmpty) {
        final raw = response
            .map((userMap) => UserProfile.fromMap(userMap))
            .toList()
            .last
            .name
            .trim();
        if (raw.isNotEmpty && raw.toLowerCase() != 'anonymous') {
          final clean = sanitizeDisplayName(raw, fallbackEmail: email);
          if (Hive.isBoxOpen('testBox')) {
            await Hive.box('testBox').put('cached_user_name_$userId', clean);
          }
          return clean;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name from table: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString('gdrive_owner_user_id');
      if (owner == null || owner == userId) {
        final gdriveName = prefs.getString('gdrive_display_name');
        if (gdriveName != null && gdriveName.trim().isNotEmpty) {
          return sanitizeDisplayName(gdriveName, fallbackEmail: email);
        }
      }
    } catch (_) {}

    try {
      var metaName = currentUser?.userMetadata?['full_name']?.toString() ??
          currentUser?.userMetadata?['name']?.toString();

      if ((metaName == null || metaName.trim().isEmpty) &&
          currentUser?.identities != null) {
        for (final id in currentUser!.identities!) {
          final idName = id.identityData?['full_name']?.toString() ??
              id.identityData?['name']?.toString();
          if (idName != null && idName.trim().isNotEmpty) {
            metaName = idName;
            break;
          }
        }
      }

      if (metaName != null && metaName.trim().isNotEmpty) {
        return sanitizeDisplayName(metaName, fallbackEmail: email);
      }
    } catch (_) {}

    try {
      if (Hive.isBoxOpen('testBox')) {
        final cached = Hive.box('testBox').get('cached_user_name_$userId');
        if (cached != null && cached.toString().trim().isNotEmpty) {
          return sanitizeDisplayName(cached.toString(), fallbackEmail: email);
        }
      }
    } catch (_) {}

    if (email != null && email.isNotEmpty) {
      return sanitizeDisplayName(null, fallbackEmail: email);
    }

    return '';
  }
}
