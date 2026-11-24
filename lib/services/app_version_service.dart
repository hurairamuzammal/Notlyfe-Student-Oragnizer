import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Parsed minimum-version policy returned by Supabase or GitHub.
@immutable
class AppVersionPolicy {
  final String minSupportedVersion;
  final int minSupportedBuild;
  final String latestVersion;
  final String downloadUrl;
  final String updateMessage;

  const AppVersionPolicy({
    required this.minSupportedVersion,
    required this.minSupportedBuild,
    required this.latestVersion,
    required this.downloadUrl,
    required this.updateMessage,
  });

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    return AppVersionPolicy(
      minSupportedVersion:
          (json['min_supported_version'] ?? AppVersionService.currentVersion)
              .toString(),
      minSupportedBuild: (json['min_supported_build'] as num?)?.toInt() ??
          int.tryParse(json['min_supported_build']?.toString() ?? '') ??
          AppVersionService.currentBuildNumber,
      latestVersion:
          (json['latest_version'] ?? AppVersionService.currentVersion)
              .toString(),
      downloadUrl: (json['download_url'] ?? AppVersionService.releasesUrl)
          .toString(),
      updateMessage: (json['update_message'] ??
              'A newer version of Notlyfe is required to continue.')
          .toString(),
    );
  }
}

/// Checks whether the running build satisfies the remote minimum-version gate.
///
/// The highest required build number observed is cached locally so turning off
/// network access cannot bypass a mandatory update.
class AppVersionService {
  AppVersionService._();
  static final AppVersionService instance = AppVersionService._();

  static const String currentVersion = '2.1.0';
  static const int currentBuildNumber = 3;
  static const String repoUrl =
      'https://github.com/hurairamuzammal/Notlyfe-Student-Oragnizer';
  static const String releasesUrl = '$repoUrl/releases/latest';
  static const String _remotePolicyUrl =
      'https://raw.githubusercontent.com/hurairamuzammal/Notlyfe-Student-Oragnizer/main/version_policy.json';

  static const String _prefMinBuild = 'notlyfe_min_supported_build';
  static const String _prefMinVersion = 'notlyfe_min_supported_version';
  static const String _prefDownloadUrl = 'notlyfe_update_download_url';
  static const String _prefMessage = 'notlyfe_update_message';

  /// Custom HTTP headers sent on every Supabase request so server-side RLS
  /// policies can reject outdated binaries that lack a supported build header.
  static Map<String, String> get clientHeaders => const {
        'x-notlyfe-version': currentVersion,
        'x-notlyfe-build': '$currentBuildNumber',
      };

  /// Compares two semantic version strings (`major.minor.patch`).
  /// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
  static int compareVersions(String a, String b) {
    final pa = a.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  /// Evaluates whether [runningBuild] / [runningVersion] is blocked by [policy].
  static bool isBlockedByPolicy(
    AppVersionPolicy policy, {
    int runningBuild = currentBuildNumber,
    String runningVersion = currentVersion,
  }) {
    if (runningBuild < policy.minSupportedBuild) return true;
    return compareVersions(runningVersion, policy.minSupportedVersion) < 0;
  }

  /// Fetches policy from Supabase and GitHub, merges with cached floor, and
  /// returns the active [AppVersionPolicy] if an update is required (or null if allowed).
  Future<AppVersionPolicy?> checkForceUpdate({
    http.Client? httpClient,
    bool skipSupabase = false,
  }) async {
    AppVersionPolicy? strictest = await _loadCachedPolicy();

    if (!skipSupabase) {
      final supaPolicy = await _fetchFromSupabase();
      strictest = _pickStricter(strictest, supaPolicy);
    }

    final githubPolicy = await _fetchFromGitHub(httpClient: httpClient);
    strictest = _pickStricter(strictest, githubPolicy);

    if (strictest != null) {
      await _cachePolicy(strictest);
      if (isBlockedByPolicy(strictest)) {
        return strictest;
      }
    }
    return null;
  }

  AppVersionPolicy? _pickStricter(AppVersionPolicy? a, AppVersionPolicy? b) {
    if (a == null) return b;
    if (b == null) return a;
    if (b.minSupportedBuild > a.minSupportedBuild) return b;
    if (b.minSupportedBuild == a.minSupportedBuild &&
        compareVersions(b.minSupportedVersion, a.minSupportedVersion) > 0) {
      return b;
    }
    return a;
  }

  Future<AppVersionPolicy?> _fetchFromSupabase() async {
    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return null;
      return AppVersionPolicy.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<AppVersionPolicy?> _fetchFromGitHub({http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    final shouldClose = httpClient == null;
    try {
      final res = await client
          .get(Uri.parse(_remotePolicyUrl))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return AppVersionPolicy.fromJson(decoded);
      }
    } catch (_) {
      // Offline or unreachable; cached policy still applies.
    } finally {
      if (shouldClose) client.close();
    }
    return null;
  }

  Future<AppVersionPolicy?> _loadCachedPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minBuild = prefs.getInt(_prefMinBuild);
      if (minBuild == null) return null;
      return AppVersionPolicy(
        minSupportedVersion: prefs.getString(_prefMinVersion) ?? currentVersion,
        minSupportedBuild: minBuild,
        latestVersion: prefs.getString(_prefMinVersion) ?? currentVersion,
        downloadUrl: prefs.getString(_prefDownloadUrl) ?? releasesUrl,
        updateMessage: prefs.getString(_prefMessage) ??
            'This version of Notlyfe is no longer supported. Please update to continue.',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePolicy(AppVersionPolicy policy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingBuild = prefs.getInt(_prefMinBuild) ?? 0;
      if (policy.minSupportedBuild >= existingBuild) {
        await prefs.setInt(_prefMinBuild, policy.minSupportedBuild);
        await prefs.setString(_prefMinVersion, policy.minSupportedVersion);
        await prefs.setString(_prefDownloadUrl, policy.downloadUrl);
        await prefs.setString(_prefMessage, policy.updateMessage);
      }
    } catch (_) {}
  }
}
