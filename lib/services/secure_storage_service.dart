import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted local storage for API keys, OAuth tokens, and vault keys.
///
/// Ciphertext is stored as `v3:<iv_b64>:<cipher_b64>:<hmac_b64>` using
/// AES-256-CBC + HMAC-SHA256 with domain-separated encryption and MAC keys.
/// The master key is kept in an app-private file (`0600` on POSIX) outside
/// SharedPreferences so casual preference dumps do not expose key material.
/// Existing `v2:` and legacy XOR entries are transparently migrated on read.
class SecureStorageService {
  static const String _keyPrefix = 'sec_vault_';
  static const String _saltKey = 'sec_vault_salt_master';
  static const String _legacyAesMasterKey = 'sec_vault_aes_master_v2';
  static const String _v2Prefix = 'v2:';
  static const String _v3Prefix = 'v3:';
  static const String _masterKeyFileName = '.notlyfe_vault_master.key';

  static enc.Key? _cachedMasterKey;

  /// Clears the in-memory master key cache (useful in tests).
  @visibleForTesting
  static void resetMemoryCache() {
    _cachedMasterKey = null;
  }

  static Future<List<int>> _getMasterSalt() async {
    final prefs = await SharedPreferences.getInstance();
    var existingSalt = prefs.getString(_saltKey);
    if (existingSalt == null || existingSalt.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      existingSalt = base64Encode(bytes);
      await prefs.setString(_saltKey, existingSalt);
    }
    return base64Decode(existingSalt);
  }

  static Future<File?> _resolveMasterKeyFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, _masterKeyFileName));
    } catch (_) {
      // Unit tests or environments without path_provider fall back safely.
      return null;
    }
  }

  static Future<void> _restrictFilePermissions(File file) async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {}
  }

  static Future<enc.Key> _getOrCreateAesMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey!;

    final keyFile = await _resolveMasterKeyFile();
    if (keyFile != null && await keyFile.exists()) {
      try {
        final raw = (await keyFile.readAsString()).trim();
        final decoded = base64Decode(raw);
        if (decoded.length == 32) {
          _cachedMasterKey = enc.Key(Uint8List.fromList(decoded));
          return _cachedMasterKey!;
        }
      } catch (_) {}
    }

    // Migrate an existing SharedPreferences master key into the private key file.
    final prefs = await SharedPreferences.getInstance();
    final legacyRaw = prefs.getString(_legacyAesMasterKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      try {
        final decoded = base64Decode(legacyRaw);
        if (decoded.length == 32) {
          final key = enc.Key(Uint8List.fromList(decoded));
          if (keyFile != null) {
            await keyFile.parent.create(recursive: true);
            await keyFile.writeAsString(key.base64, flush: true);
            await _restrictFilePermissions(keyFile);
            await prefs.remove(_legacyAesMasterKey);
          }
          _cachedMasterKey = key;
          return key;
        }
      } catch (_) {}
    }

    final generated = enc.Key.fromSecureRandom(32);
    if (keyFile != null) {
      await keyFile.parent.create(recursive: true);
      await keyFile.writeAsString(generated.base64, flush: true);
      await _restrictFilePermissions(keyFile);
    } else {
      await prefs.setString(_legacyAesMasterKey, generated.base64);
    }
    _cachedMasterKey = generated;
    return generated;
  }

  static enc.Key _deriveSubkey(enc.Key master, String slotKey, String purpose) {
    final mac = Hmac(sha256, master.bytes)
        .convert(utf8.encode('$purpose:$slotKey'))
        .bytes;
    return enc.Key(Uint8List.fromList(mac));
  }

  // Legacy v2 derived a single shared key for both encryption and MAC.
  static enc.Key _deriveLegacyV2Key(enc.Key master, String slotKey) {
    final mac = Hmac(sha256, master.bytes).convert(utf8.encode(slotKey)).bytes;
    return enc.Key(Uint8List.fromList(mac));
  }

  /// Encrypts and saves a key/value pair using AES-256-CBC + HMAC-SHA256.
  static Future<void> writeSecure(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final master = await _getOrCreateAesMasterKey();
    final encKey = _deriveSubkey(master, key, 'enc');
    final macKey = _deriveSubkey(master, key, 'mac');
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(
      enc.AES(encKey, mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );

    final encrypted = encrypter.encrypt(value, iv: iv);
    final mac = Hmac(sha256, macKey.bytes)
        .convert([...utf8.encode(key), ...iv.bytes, ...encrypted.bytes])
        .bytes;

    final envelope =
        '$_v3Prefix${iv.base64}:${encrypted.base64}:${base64Encode(mac)}';
    await prefs.setString('$_keyPrefix$key', envelope);
  }

  /// Decrypts and reads a stored value, upgrading older formats to v3.
  static Future<String?> readSecure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_keyPrefix$key');
    if (encoded == null || encoded.isEmpty) return null;

    if (encoded.startsWith(_v3Prefix)) {
      return _readV3(key, encoded);
    }

    if (encoded.startsWith(_v2Prefix)) {
      final value = await _readV2(key, encoded);
      if (value != null) {
        try {
          await writeSecure(key, value);
        } catch (_) {}
      }
      return value;
    }

    final legacyValue = await _readLegacyXor(key, encoded);
    if (legacyValue != null) {
      try {
        await writeSecure(key, legacyValue);
      } catch (_) {}
    }
    return legacyValue;
  }

  static Future<String?> _readV3(String key, String envelope) async {
    try {
      final parts = envelope.split(':');
      if (parts.length != 4) return null;
      final iv = enc.IV.fromBase64(parts[1]);
      final encrypted = enc.Encrypted.fromBase64(parts[2]);
      final expectedMac = parts[3];

      final master = await _getOrCreateAesMasterKey();
      final encKey = _deriveSubkey(master, key, 'enc');
      final macKey = _deriveSubkey(master, key, 'mac');

      final actualMac = base64Encode(
        Hmac(sha256, macKey.bytes)
            .convert([...utf8.encode(key), ...iv.bytes, ...encrypted.bytes])
            .bytes,
      );
      if (!_constantTimeEquals(actualMac, expectedMac)) {
        return null;
      }

      final encrypter = enc.Encrypter(
        enc.AES(encKey, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _readV2(String key, String envelope) async {
    try {
      final parts = envelope.split(':');
      if (parts.length != 4) return null;
      final iv = enc.IV.fromBase64(parts[1]);
      final encrypted = enc.Encrypted.fromBase64(parts[2]);
      final expectedMac = parts[3];

      final master = await _getOrCreateAesMasterKey();
      final slotKey = _deriveLegacyV2Key(master, key);

      final actualMac = base64Encode(
        Hmac(sha256, slotKey.bytes)
            .convert([...iv.bytes, ...encrypted.bytes])
            .bytes,
      );
      if (!_constantTimeEquals(actualMac, expectedMac)) {
        return null;
      }

      final encrypter = enc.Encrypter(
        enc.AES(slotKey, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _readLegacyXor(String key, String encoded) async {
    try {
      final cipherBytes = base64Decode(encoded);
      final salt = await _getMasterSalt();
      final keyBytes = utf8.encode(key);

      final plainBytes = Uint8List(cipherBytes.length);
      for (int i = 0; i < cipherBytes.length; i++) {
        final s = salt[i % salt.length];
        final k = keyBytes[i % keyBytes.length];
        plainBytes[i] = cipherBytes[i] ^ (s ^ k ^ ((i * 37 + 13) & 0xFF));
      }

      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Deletes a stored key.
  static Future<void> deleteSecure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$key');
  }
}
