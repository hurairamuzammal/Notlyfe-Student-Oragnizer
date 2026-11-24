/// Security validation and path sanitization helpers for custom storage backends.
class StorageSecurityHelper {
  StorageSecurityHelper._();

  static final RegExp _unsafePathChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final RegExp _ipv4Regex =
      RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  /// Sanitizes a single path segment (e.g., course title or folder name) to
  /// prevent path traversal (`..`), hidden dotfiles, or control characters.
  static String sanitizeSegment(String input, {String fallback = 'item'}) {
    var cleaned = input.trim().replaceAll(_unsafePathChars, '_');
    cleaned = cleaned.replaceAll('..', '_');
    while (cleaned.startsWith('.')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.trim();
    if (cleaned.isEmpty ||
        cleaned.replaceAll('_', '').replaceAll('.', '').isEmpty) {
      return fallback;
    }
    if (cleaned.length > 120) {
      cleaned = cleaned.substring(0, 120);
    }
    return cleaned;
  }

  /// Sanitizes a file name while preserving its extension when possible.
  static String sanitizeFileName(String fileName,
      {String fallback = 'file.bin'}) {
    final base = fileName.trim().split(RegExp(r'[/\\]')).last;
    if (base.isEmpty || base == '.' || base == '..') {
      return fallback;
    }
    final sanitized = sanitizeSegment(base, fallback: fallback);
    return sanitized.isEmpty ? fallback : sanitized;
  }

  /// Validates a remote storage endpoint URL.
  ///
  /// - Requires `https://` for public remote hosts.
  /// - Allows `http://` only for loopback (`localhost`, `127.0.0.1`, `::1`)
  ///   or private RFC1918 LAN hosts (e.g., `192.168.x.x`, `10.x.x.x`, `.local`)
  ///   when [allowPrivateHttp] is true (useful for self-hosted NAS/Nextcloud).
  static EndpointValidationResult validateEndpointUrl(
    String rawUrl, {
    bool allowPrivateHttp = true,
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const EndpointValidationResult(
        isValid: false,
        error: 'Endpoint URL cannot be empty.',
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return const EndpointValidationResult(
        isValid: false,
        error: 'Please enter a valid URL including https:// and host name.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      return const EndpointValidationResult(
        isValid: false,
        error: 'Only HTTPS (or local/LAN HTTP) endpoints are supported.',
      );
    }

    final host = uri.host.toLowerCase();
    final isLocalOrPrivate = _isLocalOrPrivateHost(host);

    if (scheme == 'http') {
      if (!allowPrivateHttp || !isLocalOrPrivate) {
        return const EndpointValidationResult(
          isValid: false,
          error:
              'HTTPS is required for public endpoints. Plain HTTP is only allowed for localhost or private LAN servers.',
        );
      }
      return EndpointValidationResult(
        isValid: true,
        isPrivateHttp: true,
        normalizedUrl: _stripTrailingSlash(trimmed),
      );
    }

    return EndpointValidationResult(
      isValid: true,
      isPrivateHttp: false,
      normalizedUrl: _stripTrailingSlash(trimmed),
    );
  }

  static bool _isLocalOrPrivateHost(String host) {
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.local')) {
      return true;
    }
    final match = _ipv4Regex.firstMatch(host);
    if (match == null) return false;
    final a = int.tryParse(match.group(1)!) ?? -1;
    final b = int.tryParse(match.group(2)!) ?? -1;
    if (a == 10) return true; // 10.0.0.0/8
    if (a == 127) return true; // 127.0.0.0/8
    if (a == 192 && b == 168) return true; // 192.168.0.0/16
    if (a == 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
    return false;
  }

  static String _stripTrailingSlash(String url) {
    var result = url;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Masks secrets for safe UI display or logging.
  static String maskSecret(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length <= 6) return '••••••';
    return '${value.substring(0, 2)}••••${value.substring(value.length - 2)}';
  }
}

class EndpointValidationResult {
  final bool isValid;
  final String? error;
  final bool isPrivateHttp;
  final String? normalizedUrl;

  const EndpointValidationResult({
    required this.isValid,
    this.error,
    this.isPrivateHttp = false,
    this.normalizedUrl,
  });
}
