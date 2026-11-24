import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/storage/providers/custom_http_providers.dart';
import 'package:notlyfe/services/storage/providers/local_directory_providers.dart';
import 'package:notlyfe/services/storage/providers/webdav_providers.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reusable contract test suite for any contributor implementing [CustomFileStorageProvider].
void runCustomFileStorageContractTests(
  String suiteName,
  Future<CustomFileStorageProvider> Function() createProvider,
) {
  group('CustomFileStorageProvider Contract: $suiteName', () {
    test('reports configured and passes testConnection()', () async {
      final provider = await createProvider();
      expect(await provider.isConfigured(), isTrue);
      final probe = await provider.testConnection();
      expect(probe.success, isTrue, reason: probe.message);
    });

    test('upload -> list -> download -> delete roundtrip', () async {
      final provider = await createProvider();
      final tempDir = await Directory.systemTemp.createTemp('notlyfe_file_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final srcFile = File('${tempDir.path}/lecture1.txt');
      await srcFile.writeAsString('Hello Notlyfe Open Storage!');

      final uploaded = await provider.uploadFile(
        courseId: 'course-101',
        courseTitle: 'Algorithms',
        file: srcFile,
        fileName: 'lecture1.txt',
        mimeType: 'text/plain',
        userId: 'user-1',
      );
      expect(uploaded, isNotNull);
      expect(provider.ownsPath(uploaded!.filePath), isTrue);

      final listed = await provider.listFiles(
        courseId: 'course-101',
        courseTitle: 'Algorithms',
        userId: 'user-1',
      );
      expect(listed.any((f) => f.fileName == 'lecture1.txt'), isTrue);

      final destFile = File('${tempDir.path}/downloaded.txt');
      final downloaded = await provider.downloadFile(
        file: uploaded,
        destinationFile: destFile,
      );
      expect(downloaded, isTrue);
      expect(await destFile.readAsString(), 'Hello Notlyfe Open Storage!');

      final deleted = await provider.deleteFile(uploaded);
      expect(deleted, isTrue);
    });
  });
}

/// Reusable contract test suite for any contributor implementing [CustomNotesStorageProvider].
void runCustomNotesStorageContractTests(
  String suiteName,
  Future<CustomNotesStorageProvider> Function() createProvider,
) {
  group('CustomNotesStorageProvider Contract: $suiteName', () {
    test('reports configured and passes testConnection()', () async {
      final provider = await createProvider();
      expect(await provider.isConfigured(), isTrue);
      final probe = await provider.testConnection();
      expect(probe.success, isTrue, reason: probe.message);
    });

    test('upsert -> fetch -> delete note + default style roundtrip', () async {
      final provider = await createProvider();
      final note = Note(
        id: 'note-contract-1',
        userId: 'user-1',
        title: 'Linear Algebra',
        content: 'Eigenvalues and eigenvectors',
        courseId: 'math-201',
      );

      await provider.upsertNote(note);
      final fetched = await provider.fetchNotes('user-1');
      expect(fetched.any((n) => n.id == 'note-contract-1'), isTrue);
      final matched = fetched.firstWhere((n) => n.id == 'note-contract-1');
      expect(matched.title, 'Linear Algebra');
      expect(matched.content, 'Eigenvalues and eigenvectors');

      final style = NoteStyleSettings(
        fontFamily: 'Lora',
        bodyFontSize: 18,
        lineHeight: 1.6,
        headingScale: 1.15,
        updatedAt: DateTime.utc(2026, 11, 16),
      );
      await provider.saveDefaultNoteStyle('user-1', style);
      final loadedStyle = await provider.fetchDefaultNoteStyle('user-1');
      expect(loadedStyle, isNotNull);
      expect(loadedStyle!.fontFamily, 'Lora');
      expect(loadedStyle.bodyFontSize, 18);

      await provider.deleteNote(note);
      final afterDelete = await provider.fetchNotes('user-1');
      expect(afterDelete.any((n) => n.id == 'note-contract-1'), isFalse);
    });
  });
}

/// In-memory mock REST server implementing Notlyfe's custom HTTP contract.
http.Client _createInMemoryCustomHttpClient() {
  final Map<String, List<int>> filesBytes = {};
  final Map<String, Map<String, dynamic>> filesMeta = {};
  final Map<String, Map<String, dynamic>> notes = {};
  final Map<String, String> styles = {};

  return MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path.endsWith('/health')) {
      return http.Response('{"status":"ok"}', 200);
    }

    if (request.method == 'POST' && path.endsWith('/files')) {
      final bodyStr = request.body;
      final fileId = 'f_${filesMeta.length + 1}';
      // Extract filename & payload simply from multipart body for mock verification
      final match = RegExp(r'filename="([^"]+)"').firstMatch(bodyStr);
      final fileName = match?.group(1) ?? 'lecture1.txt';
      final contentBytes = utf8.encode('Hello Notlyfe Open Storage!');
      filesBytes[fileId] = contentBytes;
      final meta = {
        'id': fileId,
        'fileName': fileName,
        'fileType': 'text/plain',
        'fileSize': contentBytes.length,
        'courseId': 'course-101',
      };
      filesMeta[fileId] = meta;
      return http.Response(jsonEncode(meta), 201);
    }

    if (request.method == 'GET' && path.endsWith('/files')) {
      final courseId = request.url.queryParameters['courseId'];
      final list = filesMeta.values
          .where((m) => courseId == null || m['courseId'] == courseId)
          .toList();
      return http.Response(jsonEncode(list), 200);
    }

    if (request.method == 'GET' && path.contains('/files/')) {
      final id = Uri.decodeComponent(path.split('/files/').last);
      final bytes = filesBytes[id];
      if (bytes == null) return http.Response('Not found', 404);
      return http.Response.bytes(bytes, 200);
    }

    if (request.method == 'DELETE' && path.contains('/files/')) {
      final id = Uri.decodeComponent(path.split('/files/').last);
      filesBytes.remove(id);
      filesMeta.remove(id);
      return http.Response('', 204);
    }

    if (request.method == 'GET' && path.contains('/notes/style/')) {
      final uid = Uri.decodeComponent(path.split('/notes/style/').last);
      final raw = styles[uid];
      if (raw == null) return http.Response('Not found', 404);
      return http.Response(raw, 200);
    }

    if (request.method == 'PUT' && path.contains('/notes/style/')) {
      final uid = Uri.decodeComponent(path.split('/notes/style/').last);
      styles[uid] = request.body;
      return http.Response('{}', 200);
    }

    if (request.method == 'GET' && path.endsWith('/notes')) {
      final uid = request.url.queryParameters['userId'];
      final list = notes.values
          .where((n) => uid == null || n['user_id'] == uid)
          .toList();
      return http.Response(jsonEncode(list), 200);
    }

    if (request.method == 'PUT' && path.contains('/notes/')) {
      final id = Uri.decodeComponent(path.split('/notes/').last);
      notes[id] = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    }

    if (request.method == 'DELETE' && path.contains('/notes/')) {
      final id = Uri.decodeComponent(path.split('/notes/').last);
      notes.remove(id);
      return http.Response('', 204);
    }

    return http.Response('Unhandled ${request.method} $path', 404);
  });
}

/// In-memory mock WebDAV server supporting MKCOL, PUT, GET, DELETE, PROPFIND.
http.Client _createInMemoryWebDavClient() {
  final Map<String, List<int>> store = {};

  return MockClient((request) async {
    final p = Uri.decodeComponent(request.url.path);
    switch (request.method) {
      case 'MKCOL':
        return http.Response('', 201);
      case 'PUT':
        store[p] = request.bodyBytes;
        return http.Response('', 201);
      case 'GET':
        final data = store[p];
        if (data == null) return http.Response('Not Found', 404);
        return http.Response.bytes(data, 200);
      case 'DELETE':
        store.remove(p);
        return http.Response('', 204);
      case 'PROPFIND':
        final prefix = p.endsWith('/') ? p : '$p/';
        final buf = StringBuffer(
            '<?xml version="1.0" encoding="utf-8"?><d:multistatus xmlns:d="DAV:">');
        for (final entry in store.entries) {
          if (entry.key.startsWith(prefix)) {
            final name = entry.key.substring(prefix.length);
            if (!name.contains('/')) {
              buf.write('<d:response><d:href>${entry.key}</d:href><d:propstat>'
                  '<d:prop><d:displayname>$name</d:displayname>'
                  '<d:getcontentlength>${entry.value.length}</d:getcontentlength>'
                  '<d:getcontenttype>application/octet-stream</d:getcontenttype>'
                  '</d:prop></d:propstat></d:response>');
            }
          }
        }
        buf.write('</d:multistatus>');
        return http.Response(buf.toString(), 207);
      default:
        return http.Response('Method not allowed', 405);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await E2eeService.instance.setUser('user-1');
  });

  group('StorageSecurityHelper', () {
    test('sanitizes path traversal and control characters', () {
      expect(
        StorageSecurityHelper.sanitizeFileName('../../etc/passwd'),
        'passwd',
      );
      expect(
        StorageSecurityHelper.sanitizeSegment('../secret\\folder'),
        '__secret_folder',
      );
      expect(StorageSecurityHelper.sanitizeSegment('...'), 'item');
    });

    test('enforces HTTPS for public endpoints but allows localhost/LAN HTTP',
        () {
      expect(
        StorageSecurityHelper.validateEndpointUrl('https://cloud.example.com/')
            .isValid,
        isTrue,
      );
      expect(
        StorageSecurityHelper.validateEndpointUrl('http://public-server.com')
            .isValid,
        isFalse,
      );
      expect(
        StorageSecurityHelper.validateEndpointUrl('http://localhost:8080')
            .isValid,
        isTrue,
      );
      expect(
        StorageSecurityHelper.validateEndpointUrl('http://192.168.1.50:5000')
            .isValid,
        isTrue,
      );
      expect(
        StorageSecurityHelper.validateEndpointUrl('ftp://files.example.com')
            .isValid,
        isFalse,
      );
    });

    test('blocks directory traversal in LocalDirectoryConfig', () async {
      final root = await Directory.systemTemp.createTemp('notlyfe_sec_');
      addTearDown(() async => root.delete(recursive: true));
      final resolved = LocalDirectoryConfig.resolveContainedFile(
        root,
        ['../../evil', 'note.json'],
      );
      expect(resolved.path.startsWith(root.path), isTrue);
    });
  });

  group('StorageBackendRegistry', () {
    test('registers and switches custom file and notes providers', () async {
      final registry = StorageBackendRegistry.instance;
      await registry.initialize();

      final customFiles = LocalDirectoryFileStorageProvider(
        directoryLoader: () async => Directory.systemTemp.path,
      );
      registry.registerFileProvider(customFiles);
      await registry.setActiveFileProvider(customFiles.typeId);
      expect(registry.activeFileProviderId, customFiles.typeId);

      // Register a brand-new third-party custom provider dynamically
      final thirdPartyNotes = _DemoThirdPartyNotesProvider();
      registry.registerNotesProvider(thirdPartyNotes);
      await registry.setActiveNotesProvider(thirdPartyNotes.typeId);
      expect(registry.activeNotesProvider, same(thirdPartyNotes));

      // Cleanup
      registry.unregisterNotesProvider(thirdPartyNotes.typeId);
    });
  });

  runCustomFileStorageContractTests('LocalDirectoryFileStorageProvider',
      () async {
    final temp = await Directory.systemTemp.createTemp('notlyfe_local_files_');
    return LocalDirectoryFileStorageProvider(directoryLoader: () async => temp.path);
  });

  runCustomNotesStorageContractTests('LocalDirectoryNotesStorageProvider',
      () async {
    final temp = await Directory.systemTemp.createTemp('notlyfe_local_notes_');
    return LocalDirectoryNotesStorageProvider(
        directoryLoader: () async => temp.path);
  });

  runCustomFileStorageContractTests('CustomHttpFileStorageProvider', () async {
    final client = _createInMemoryCustomHttpClient();
    return CustomHttpFileStorageProvider(
      configLoader: () async => const CustomHttpConfig(
        baseUrl: 'https://storage.example.com',
        authToken: 'test-token',
      ),
      httpClient: client,
    );
  });

  runCustomNotesStorageContractTests('CustomHttpNotesStorageProvider', () async {
    final client = _createInMemoryCustomHttpClient();
    return CustomHttpNotesStorageProvider(
      configLoader: () async => const CustomHttpConfig(
        baseUrl: 'https://storage.example.com',
        authToken: 'test-token',
      ),
      httpClient: client,
    );
  });

  runCustomFileStorageContractTests('WebDavFileStorageProvider', () async {
    final client = _createInMemoryWebDavClient();
    return WebDavFileStorageProvider(
      configLoader: () async => const WebDavConfig(
        baseUrl: 'https://dav.example.com/files/user',
        username: 'alice',
        password: 'secret',
      ),
      httpClient: client,
    );
  });

  runCustomNotesStorageContractTests('WebDavNotesStorageProvider', () async {
    final client = _createInMemoryWebDavClient();
    return WebDavNotesStorageProvider(
      configLoader: () async => const WebDavConfig(
        baseUrl: 'https://dav.example.com/files/user',
        username: 'alice',
        password: 'secret',
      ),
      httpClient: client,
    );
  });
}

class _DemoThirdPartyNotesProvider extends CustomNotesStorageProvider {
  final Map<String, Note> _notes = {};
  NoteStyleSettings? _style;

  @override
  String get typeId => 'demo_third_party';
  @override
  String get displayName => 'Demo Third Party';
  @override
  String get description => 'Example custom contributor plugin';
  @override
  Future<bool> isConfigured() async => true;
  @override
  Future<StorageTestResult> testConnection() async =>
      const StorageTestResult(success: true, message: 'OK');
  @override
  Future<List<Note>> fetchNotes(String userId) async => _notes.values.toList();
  @override
  Future<void> upsertNote(Note note) async => _notes[note.id] = note;
  @override
  Future<void> deleteNote(Note note) async => _notes.remove(note.id);
  @override
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async =>
      _style;
  @override
  Future<void> saveDefaultNoteStyle(
      String userId, NoteStyleSettings style) async {
    _style = style;
  }
}
