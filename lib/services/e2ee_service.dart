import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/secure_storage_service.dart';

/// Client-side End-to-End Encryption (E2EE) for Notes and Todos.
///
/// New writes use `enc:v2:<iv_b64>:<cipher_b64>:<hmac_b64>` with separate
/// AES-256-CBC and HMAC-SHA256 subkeys derived from the user's 256-bit vault key.
/// Legacy `enc:v1:` envelopes and unencrypted strings remain readable.
class E2eeService {
  E2eeService._internal();
  static final E2eeService instance = E2eeService._internal();
  factory E2eeService() => instance;

  static const String _vaultKeyPrefix = 'e2ee_vault_key_';
  static const String _v1Prefix = 'enc:v1:';
  static const String _v2Prefix = 'enc:v2:';

  enc.Key? _cachedMasterKey;
  enc.Key? _cachedEncKey;
  enc.Key? _cachedMacKey;
  enc.Encrypter? _cachedV2Encrypter;
  enc.Encrypter? _cachedV1Encrypter;
  String? _activeUserId;

  bool get isInitialized => _cachedMasterKey != null && _cachedV2Encrypter != null;
  String? get activeUserId => _activeUserId;

  Future<void> initialize([String? userId]) async {
    try {
      var uid = userId ?? '';
      if (uid.isEmpty) {
        try {
          uid = AuthServices().getCurrentUserId();
        } catch (_) {}
      }
      await setUser(uid);
    } catch (e) {
      debugPrint('E2EE initialize error: $e');
    }
  }

  /// Loads or creates the 256-bit vault key for [userId]. Passing null clears
  /// in-memory keys on sign-out so a previous user's key is never reused.
  Future<void> setUser([String? userId]) async {
    if (userId == null) {
      clearActiveKey();
      return;
    }

    try {
      var uid = userId;
      if (uid.isEmpty) {
        try {
          uid = AuthServices().getCurrentUserId();
        } catch (_) {}
      }
      _activeUserId = uid;
      final storageKey = '$_vaultKeyPrefix${uid.isNotEmpty ? uid : 'default'}';

      var base64Key = await SecureStorageService.readSecure(storageKey);
      if (base64Key == null || base64Key.isEmpty) {
        final randomKey = enc.Key.fromSecureRandom(32);
        base64Key = randomKey.base64;
        await SecureStorageService.writeSecure(storageKey, base64Key);
      }

      _installMasterKey(enc.Key.fromBase64(base64Key));
    } catch (e) {
      debugPrint('E2EE setUser error: $e');
    }
  }

  /// Clears cached keys from memory (called on sign-out).
  void clearActiveKey() {
    _cachedMasterKey = null;
    _cachedEncKey = null;
    _cachedMacKey = null;
    _cachedV2Encrypter = null;
    _cachedV1Encrypter = null;
    _activeUserId = null;
  }

  void _installMasterKey(enc.Key master) {
    final encBytes = Hmac(sha256, master.bytes)
        .convert(utf8.encode('notlyfe-e2ee-v2-enc'))
        .bytes;
    final macBytes = Hmac(sha256, master.bytes)
        .convert(utf8.encode('notlyfe-e2ee-v2-mac'))
        .bytes;

    _cachedMasterKey = master;
    _cachedEncKey = enc.Key(Uint8List.fromList(encBytes));
    _cachedMacKey = enc.Key(Uint8List.fromList(macBytes));
    _cachedV2Encrypter = enc.Encrypter(
      enc.AES(_cachedEncKey!, mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );
    _cachedV1Encrypter = enc.Encrypter(
      enc.AES(master, mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );
  }

  /// Encrypts [plainText] into an authenticated `enc:v2:` envelope.
  /// Fails closed if the vault key has not been initialized.
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    if (plainText.startsWith(_v2Prefix) || plainText.startsWith(_v1Prefix)) {
      return plainText;
    }

    final encrypter = _cachedV2Encrypter;
    final macKey = _cachedMacKey;
    if (encrypter == null || macKey == null) {
      throw StateError('E2EE vault key is not initialized.');
    }

    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final mac = Hmac(sha256, macKey.bytes)
        .convert([...utf8.encode(_v2Prefix), ...iv.bytes, ...encrypted.bytes])
        .bytes;

    return '$_v2Prefix${iv.base64}:${encrypted.base64}:${base64Encode(mac)}';
  }

  /// Decrypts `enc:v2:` or legacy `enc:v1:` envelopes. Plaintext strings without
  /// an envelope prefix are returned as-is for backward compatibility.
  String decrypt(String cipherOrPlainText) {
    if (cipherOrPlainText.isEmpty) return '';

    if (cipherOrPlainText.startsWith(_v2Prefix)) {
      return _decryptV2(cipherOrPlainText);
    }
    if (cipherOrPlainText.startsWith(_v1Prefix)) {
      return _decryptV1(cipherOrPlainText);
    }
    return cipherOrPlainText;
  }

  String _decryptV2(String envelope) {
    final encrypter = _cachedV2Encrypter;
    final macKey = _cachedMacKey;
    if (encrypter == null || macKey == null) return '[Encrypted content]';

    try {
      final parts = envelope.split(':');
      if (parts.length != 5) return '[Encrypted content]';

      final iv = enc.IV.fromBase64(parts[2]);
      final encrypted = enc.Encrypted.fromBase64(parts[3]);
      final expectedMac = parts[4];

      final computedMac = base64Encode(
        Hmac(sha256, macKey.bytes)
            .convert([...utf8.encode(_v2Prefix), ...iv.bytes, ...encrypted.bytes])
            .bytes,
      );

      if (!_constantTimeEquals(computedMac, expectedMac)) {
        return '[Tampered encrypted content]';
      }

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return '[Encrypted content]';
    }
  }

  String _decryptV1(String envelope) {
    final encrypter = _cachedV1Encrypter;
    final masterKey = _cachedMasterKey;
    if (encrypter == null || masterKey == null) return '[Encrypted content]';

    try {
      final parts = envelope.split(':');
      if (parts.length != 5) return '[Encrypted content]';

      final iv = enc.IV.fromBase64(parts[2]);
      final encrypted = enc.Encrypted.fromBase64(parts[3]);
      final expectedMac = parts[4];

      final computedMac = base64Encode(
        Hmac(sha256, masterKey.bytes)
            .convert([...iv.bytes, ...encrypted.bytes])
            .bytes,
      );

      if (!_constantTimeEquals(computedMac, expectedMac)) {
        return '[Tampered encrypted content]';
      }

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return '[Encrypted content]';
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

  /// Returns a non-reversible SHA-256 fingerprint of the active vault key for UI display.
  String getVaultKeyFingerprint() {
    final master = _cachedMasterKey;
    if (master == null) return 'Not initialized';
    final hash = sha256.convert(master.bytes).toString().toUpperCase();
    return '${hash.substring(0, 8)}-${hash.substring(8, 16)}-${hash.substring(16, 24)}';
  }
}
