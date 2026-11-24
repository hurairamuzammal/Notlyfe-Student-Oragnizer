import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordResetRateLimiter {
  static const int maxAttemptsPer24Hr = 3;
  static const String _keyPrefix = 'pw_reset_timestamps_';

  /// Normalizes email for matching
  static String _cleanEmail(String email) => email.trim().toLowerCase();

  /// Checks if an email has exceeded the 3 emails per 24 hours rate limit.
  /// Returns null if allowed, or an error message string if blocked.
  static Future<String?> checkRateLimit(String email) async {
    final clean = _cleanEmail(email);
    if (clean.isEmpty) return 'Please enter a valid email address.';

    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$clean';
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return null;

    try {
      final List<dynamic> list = jsonDecode(raw);
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      // Filter timestamps within last 24 hours
      final validTimestamps = list
          .map((item) => DateTime.parse(item.toString()))
          .where((dt) => dt.isAfter(cutoff))
          .toList();

      if (validTimestamps.length >= maxAttemptsPer24Hr) {
        // Find earliest timestamp to compute remaining wait time
        validTimestamps.sort();
        final earliest = validTimestamps.first;
        final resetTime = earliest.add(const Duration(hours: 24));
        final diff = resetTime.difference(now);
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;

        return 'Rate limit exceeded: You can only request 3 password resets per 24 hours. Please wait $hours hr $minutes min or check your inbox/spam folder.';
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Records a successful reset attempt timestamp for this email.
  static Future<void> recordResetAttempt(String email) async {
    final clean = _cleanEmail(email);
    if (clean.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$clean';
    final raw = prefs.getString(key);

    List<DateTime> validTimestamps = [];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));

    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        validTimestamps = list
            .map((item) => DateTime.parse(item.toString()))
            .where((dt) => dt.isAfter(cutoff))
            .toList();
      } catch (_) {}
    }

    validTimestamps.add(now);

    final encoded = jsonEncode(
      validTimestamps.map((dt) => dt.toIso8601String()).toList(),
    );
    await prefs.setString(key, encoded);
  }

  /// Gets remaining attempts for an email within the current 24-hour window
  static Future<int> getRemainingAttempts(String email) async {
    final clean = _cleanEmail(email);
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$clean';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return maxAttemptsPer24Hr;

    try {
      final List<dynamic> list = jsonDecode(raw);
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final count = list
          .map((item) => DateTime.parse(item.toString()))
          .where((dt) => dt.isAfter(cutoff))
          .length;
      return (maxAttemptsPer24Hr - count).clamp(0, maxAttemptsPer24Hr);
    } catch (_) {
      return maxAttemptsPer24Hr;
    }
  }
}

