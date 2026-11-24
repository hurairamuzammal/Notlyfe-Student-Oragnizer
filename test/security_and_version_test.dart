import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/services/app_version_service.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    E2eeService.instance.clearActiveKey();
  });

  group('SecureStorageService v3', () {
    test('stores encrypted v3 ciphertext and rejects tampered payloads',
        () async {
      await SecureStorageService.writeSecure('drive_token', 'ya29.secret-abc');
      expect(
        await SecureStorageService.readSecure('drive_token'),
        'ya29.secret-abc',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sec_vault_drive_token');
      expect(raw, isNotNull);
      expect(raw!.startsWith('v3:'), isTrue);
      expect(raw.contains('ya29.secret-abc'), isFalse);

      // Tampering with ciphertext must fail HMAC verification and return null.
      final parts = raw.split(':');
      expect(parts.length, 4);
      final tampered = '${parts[0]}:${parts[1]}:${parts[2]}:AAAA';
      await prefs.setString('sec_vault_drive_token', tampered);

      expect(await SecureStorageService.readSecure('drive_token'), isNull);
    });

    test('binds MAC to storage key name to prevent slot-swapping', () async {
      await SecureStorageService.writeSecure('slot_a', 'secret-value');
      final prefs = await SharedPreferences.getInstance();
      final cipherA = prefs.getString('sec_vault_slot_a')!;

      // Copying ciphertext from slot_a into slot_b must fail verification.
      await prefs.setString('sec_vault_slot_b', cipherA);
      expect(await SecureStorageService.readSecure('slot_b'), isNull);
    });
  });

  group('E2eeService v2', () {
    test('fails closed when encrypt() is called without an initialized user',
        () {
      expect(
        () => E2eeService.instance.encrypt('sensitive note'),
        throwsA(isA<StateError>()),
      );
    });

    test('encrypts with enc:v2:, detects tampering, and scrubs key on sign-out',
        () async {
      await E2eeService.instance.setUser('user-vault-1');
      final encrypted = E2eeService.instance.encrypt('Exam answers');
      expect(encrypted.startsWith('enc:v2:'), isTrue);
      expect(encrypted.contains('Exam answers'), isFalse);
      expect(E2eeService.instance.decrypt(encrypted), 'Exam answers');

      // Flipping the MAC must refuse to return corrupted plaintext.
      final parts = encrypted.split(':');
      final tampered = '${parts[0]}:${parts[1]}:${parts[2]}:${parts[3]}:AAAA';
      expect(
        E2eeService.instance.decrypt(tampered),
        '[Tampered encrypted content]',
      );

      // Fingerprint is non-empty, formatted, and never exposes the raw key.
      final fingerprint = E2eeService.instance.getVaultKeyFingerprint();
      expect(fingerprint, isNotEmpty);
      expect(fingerprint.split('-').length, 3);

      E2eeService.instance.clearActiveKey();
      expect(E2eeService.instance.isInitialized, isFalse);
      expect(
        () => E2eeService.instance.encrypt('should fail'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Note model hygiene', () {
    test('copyWith(clearCourseId: true) clears courseId and toString() hides title',
        () {
      final note = Note(
        id: 'n-1',
        userId: 'u-1',
        title: 'Private Medical Info',
        content: 'Body',
        courseId: 'cs-101',
      );
      final unassigned = note.copyWith(clearCourseId: true);
      expect(unassigned.courseId, isNull);
      expect(note.toString().contains('Private Medical Info'), isFalse);
    });
  });

  group('AppVersionService force-update gate', () {
    test('compares semantic versions accurately', () {
      expect(AppVersionService.compareVersions('2.0.1', '2.1.0'), lessThan(0));
      expect(AppVersionService.compareVersions('2.1.0', '2.1.0'), 0);
      expect(
        AppVersionService.compareVersions('2.1.1', '2.1.0'),
        greaterThan(0),
      );
      expect(
        AppVersionService.compareVersions('2.1.0+3', '2.1.0'),
        0,
      );
    });

    test('blocks older builds and older versions', () {
      const policy = AppVersionPolicy(
        minSupportedVersion: '2.1.0',
        minSupportedBuild: 3,
        latestVersion: '2.1.0',
        downloadUrl: AppVersionService.releasesUrl,
        updateMessage: 'Update required',
      );

      expect(
        AppVersionService.isBlockedByPolicy(
          policy,
          runningBuild: 2,
          runningVersion: '2.0.1',
        ),
        isTrue,
      );
      expect(
        AppVersionService.isBlockedByPolicy(
          policy,
          runningBuild: 3,
          runningVersion: '2.0.9',
        ),
        isTrue,
      );
      expect(
        AppVersionService.isBlockedByPolicy(
          policy,
          runningBuild: 3,
          runningVersion: '2.1.0',
        ),
        isFalse,
      );
    });

    test('caches strictest required build offline so network toggle cannot bypass',
        () async {
      final blockingClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'min_supported_version': '3.0.0',
            'min_supported_build': 99,
            'latest_version': '3.0.0',
            'download_url': AppVersionService.releasesUrl,
            'update_message': 'Mandatory security upgrade',
          }),
          200,
        ),
      );

      final blocked = await AppVersionService.instance.checkForceUpdate(
        httpClient: blockingClient,
        skipSupabase: true,
      );
      expect(blocked, isNotNull);
      expect(blocked!.minSupportedBuild, 99);

      // Subsequent offline check must still return blocked from cached floor.
      final offlineClient = MockClient((_) async => throw Exception('offline'));
      final stillBlocked = await AppVersionService.instance.checkForceUpdate(
        httpClient: offlineClient,
        skipSupabase: true,
      );
      expect(stillBlocked, isNotNull);
      expect(stillBlocked!.minSupportedBuild, 99);
    });
  });
}
