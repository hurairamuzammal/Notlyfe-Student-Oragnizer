import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/secure_storage_service.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

/// Persisted configuration for WebDAV storage (Nextcloud, OwnCloud, Synology, etc.).
@immutable
class WebDavConfig {
  final String baseUrl;
  final String username;
  final String password;
  final String rootFolder;

  const WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.rootFolder = 'Notlyfe',
  });

  static const _prefUrl = 'webdav_base_url';
  static const _prefUser = 'webdav_username';
  static const _prefRoot = 'webdav_root_folder';
  static const _secPass = 'webdav_password_v1';

  bool get isValid =>
      baseUrl.trim().isNotEmpty &&
      StorageSecurityHelper.validateEndpointUrl(baseUrl).isValid;

  static Future<WebDavConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefUrl) ?? '';
    if (url.trim().isEmpty) return null;
    final user = prefs.getString(_prefUser) ?? '';
    final root = prefs.getString(_prefRoot) ?? 'Notlyfe';
    final pass = await SecureStorageService.readSecure(_secPass) ?? '';
    return WebDavConfig(
      baseUrl: url,
      username: user,
      password: pass,
      rootFolder: root.trim().isEmpty ? 'Notlyfe' : root.trim(),
    );
  }

  static Future<void> save(WebDavConfig config) async {
    final check = StorageSecurityHelper.validateEndpointUrl(config.baseUrl);
    if (!check.isValid) {
      throw ArgumentError(check.error);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrl, check.normalizedUrl!);
    await prefs.setString(_prefUser, config.username.trim());
    await prefs.setString(
      _prefRoot,
      StorageSecurityHelper.sanitizeSegment(
        config.rootFolder,
        fallback: 'Notlyfe',
      ),
    );
    await SecureStorageService.writeSecure(_secPass, config.password);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUrl);
    await prefs.remove(_prefUser);
    await prefs.remove(_prefRoot);
    await SecureStorageService.deleteSecure(_secPass);
  }
}

/// Lightweight, testable WebDAV HTTP client supporting MKCOL, PROPFIND, PUT, GET, DELETE.
class WebDavClient {
  final WebDavConfig config;
  final http.Client httpClient;

  WebDavClient({required this.config, http.Client? client})
      : httpClient = client ?? http.Client();

  Map<String, String> get _authHeaders {
    if (config.username.isEmpty && config.password.isEmpty) {
      return const {};
    }
    final token =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {'Authorization': 'Basic $token'};
  }

  Uri buildUri(List<String> segments) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final cleanSegments = segments
        .where((s) => s.trim().isNotEmpty)
        .map((s) => Uri.encodeComponent(
            StorageSecurityHelper.sanitizeSegment(s, fallback: 'item')))
        .join('/');
    return Uri.parse(cleanSegments.isEmpty ? base : '$base/$cleanSegments');
  }

  Future<void> ensureCollection(List<String> segments) async {
    final current = <String>[];
    for (final seg in segments) {
      current.add(seg);
      final req = http.Request('MKCOL', buildUri(current))
        ..headers.addAll(_authHeaders);
      final res = await httpClient.send(req);
      await res.stream.drain<void>();
      // 201 Created, 405 Already Exists, 301/200 OK are all acceptable for MKCOL
      if (res.statusCode >= 400 &&
          res.statusCode != 405 &&
          res.statusCode != 409) {
        throw HttpException(
          'WebDAV MKCOL failed (${res.statusCode}) at ${current.join('/')}',
        );
      }
    }
  }

  Future<void> putBytes(
    List<String> segments,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    if (segments.length > 1) {
      await ensureCollection(segments.sublist(0, segments.length - 1));
    }
    final res = await httpClient.put(
      buildUri(segments),
      headers: {
        ..._authHeaders,
        'Content-Type': contentType,
      },
      body: bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('WebDAV PUT failed (${res.statusCode})');
    }
  }

  Future<List<int>?> getBytes(List<String> segments) async {
    final res = await httpClient.get(buildUri(segments), headers: _authHeaders);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('WebDAV GET failed (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  Future<bool> deleteResource(List<String> segments) async {
    final res =
        await httpClient.delete(buildUri(segments), headers: _authHeaders);
    return res.statusCode == 404 ||
        (res.statusCode >= 200 && res.statusCode < 300);
  }

  Future<List<WebDavEntry>> listEntries(List<String> folderSegments) async {
    await ensureCollection(folderSegments);
    final req = http.Request('PROPFIND', buildUri(folderSegments))
      ..headers.addAll({
        ..._authHeaders,
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      })
      ..body = '<?xml version="1.0" encoding="utf-8"?>'
          '<d:propfind xmlns:d="DAV:">'
          '<d:prop><d:displayname/><d:getcontentlength/><d:getcontenttype/><d:resourcetype/></d:prop>'
          '</d:propfind>';

    final streamed = await httpClient.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException('WebDAV PROPFIND failed (${streamed.statusCode})');
    }
    return parsePropfindXml(body, folderSegments.last);
  }

  /// Parses WebDAV PROPFIND XML responses across Nextcloud/OwnCloud/Apache/Nginx namespaces.
  static List<WebDavEntry> parsePropfindXml(String xmlBody, String folderName) {
    final doc = XmlDocument.parse(xmlBody);
    final entries = <WebDavEntry>[];
    final responses = doc.findAllElements('*').where(
          (e) => e.localName == 'response',
        );

    for (final resp in responses) {
      final href = resp
              .findAllElements('*')
              .where((e) => e.localName == 'href')
              .firstOrNull
              ?.innerText ??
          '';
      final isCollection = resp
          .findAllElements('*')
          .any((e) => e.localName == 'collection');
      if (isCollection) continue;

      final decodedHref = Uri.decodeComponent(href);
      final trimmedHref = decodedHref.endsWith('/')
          ? decodedHref.substring(0, decodedHref.length - 1)
          : decodedHref;
      final nameFromHref =
          trimmedHref.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';

      final displayName = resp
          .findAllElements('*')
          .where((e) => e.localName == 'displayname')
          .firstOrNull
          ?.innerText
          .trim();

      final name =
          nameFromHref.isNotEmpty ? nameFromHref : (displayName ?? '');
      if (name.isEmpty || name == folderName) continue;

      final lenStr = resp
              .findAllElements('*')
              .where((e) => e.localName == 'getcontentlength')
              .firstOrNull
              ?.innerText
              .trim() ??
          '0';
      final contentType = resp
              .findAllElements('*')
              .where((e) => e.localName == 'getcontenttype')
              .firstOrNull
              ?.innerText
              .trim() ??
          'application/octet-stream';

      entries.add(WebDavEntry(
        name: name,
        size: int.tryParse(lenStr) ?? 0,
        contentType:
            contentType.isEmpty ? 'application/octet-stream' : contentType,
      ));
    }
    return entries;
  }
}

class WebDavEntry {
  final String name;
  final int size;
  final String contentType;

  const WebDavEntry({
    required this.name,
    required this.size,
    required this.contentType,
  });
}

/// WebDAV course file storage provider (Nextcloud, OwnCloud, Synology, Koofr, etc.).
class WebDavFileStorageProvider extends CustomFileStorageProvider {
  static const String id = 'webdav';

  final Future<WebDavConfig?> Function()? _configLoader;
  final http.Client? _httpClient;

  WebDavFileStorageProvider({
    Future<WebDavConfig?> Function()? configLoader,
    http.Client? httpClient,
  })  : _configLoader = configLoader,
        _httpClient = httpClient;

  Future<WebDavClient?> _client() async {
    final cfg = await (_configLoader != null
        ? _configLoader()
        : WebDavConfig.load());
    if (cfg == null || !cfg.isValid) return null;
    return WebDavClient(config: cfg, client: _httpClient);
  }

  @override
  String get typeId => id;

  @override
  String get displayName => 'WebDAV / Nextcloud';

  @override
  String get description =>
      'Self-hosted Nextcloud, OwnCloud, Synology NAS, or any WebDAV server.';

  @override
  String get pathScheme => 'webdav';

  @override
  Future<bool> isConfigured() async => (await _client()) != null;

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final client = await _client();
      if (client == null) {
        return StorageTestResult(
          success: false,
          message: 'WebDAV URL/credentials are not configured.',
          latency: sw.elapsed,
        );
      }
      final probe = [client.config.rootFolder, '.notlyfe_probe.txt'];
      await client.putBytes(probe, utf8.encode('notlyfe-ok'),
          contentType: 'text/plain');
      final readBack = await client.getBytes(probe);
      await client.deleteResource(probe);
      final ok = readBack != null && utf8.decode(readBack) == 'notlyfe-ok';
      return StorageTestResult(
        success: ok,
        message: ok
            ? 'WebDAV read/write probe succeeded at ${client.config.baseUrl}.'
            : 'WebDAV probe read-back mismatch.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'WebDAV connection test failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  @override
  Future<UserFiles?> uploadFile({
    required String courseId,
    required String courseTitle,
    required File file,
    required String fileName,
    required String mimeType,
    required String userId,
    StorageProgressCallback? onProgress,
  }) async {
    final client = await _client();
    if (client == null) {
      throw Exception('WebDAV storage is not configured.');
    }
    final safeCourse =
        StorageSecurityHelper.sanitizeSegment(courseTitle, fallback: courseId);
    final safeName = StorageSecurityHelper.sanitizeFileName(fileName);
    final bytes = await file.readAsBytes();
    onProgress?.call(bytes.length, bytes.length, 0);

    await client.putBytes(
      [client.config.rootFolder, 'Files', safeCourse, safeName],
      bytes,
      contentType: mimeType,
    );

    final encodedCourse = Uri.encodeComponent(safeCourse);
    final encodedName = Uri.encodeComponent(safeName);
    final virtualPath = 'webdav://$encodedCourse/$encodedName';
    return UserFiles(
      id: virtualPath.hashCode.abs(),
      filePath: virtualPath,
      fileName: safeName,
      fileType: mimeType,
      userId: userId,
      courseId: courseId,
      fileSize: bytes.length,
    );
  }

  @override
  Future<List<UserFiles>> listFiles({
    required String courseId,
    required String courseTitle,
    required String userId,
  }) async {
    final client = await _client();
    if (client == null) return [];
    final safeCourse =
        StorageSecurityHelper.sanitizeSegment(courseTitle, fallback: courseId);
    final entries = await client.listEntries(
      [client.config.rootFolder, 'Files', safeCourse],
    );
    return entries.map((e) {
      final path =
          'webdav://${Uri.encodeComponent(safeCourse)}/${Uri.encodeComponent(e.name)}';
      return UserFiles(
        id: path.hashCode.abs(),
        filePath: path,
        fileName: e.name,
        fileType: e.contentType,
        userId: userId,
        courseId: courseId,
        fileSize: e.size,
      );
    }).toList();
  }

  List<String> _segmentsFromVirtualPath(
      WebDavClient client, String virtualPath) {
    final rest = virtualPath.substring('webdav://'.length);
    final parts = rest
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
    return [client.config.rootFolder, 'Files', ...parts];
  }

  @override
  Future<bool> downloadFile({
    required UserFiles file,
    required File destinationFile,
    StorageProgressCallback? onProgress,
  }) async {
    final client = await _client();
    if (client == null) return false;
    final segments = _segmentsFromVirtualPath(client, file.filePath);
    final bytes = await client.getBytes(segments);
    if (bytes == null) return false;
    await destinationFile.writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length, 0);
    return true;
  }

  @override
  Future<bool> deleteFile(UserFiles file) async {
    final client = await _client();
    if (client == null) return false;
    final segments = _segmentsFromVirtualPath(client, file.filePath);
    return client.deleteResource(segments);
  }
}

/// WebDAV notes & default-style sync provider (stores E2EE note JSON on user's server).
class WebDavNotesStorageProvider extends CustomNotesStorageProvider {
  static const String id = 'webdav_notes';
  static const String _notesFolder = 'Notes';
  static const String _styleFileName = 'default_style.json';

  final Future<WebDavConfig?> Function()? _configLoader;
  final http.Client? _httpClient;

  WebDavNotesStorageProvider({
    Future<WebDavConfig?> Function()? configLoader,
    http.Client? httpClient,
  })  : _configLoader = configLoader,
        _httpClient = httpClient;

  Future<WebDavClient?> _client() async {
    final cfg = await (_configLoader != null
        ? _configLoader()
        : WebDavConfig.load());
    if (cfg == null || !cfg.isValid) return null;
    return WebDavClient(config: cfg, client: _httpClient);
  }

  @override
  String get typeId => id;

  @override
  String get displayName => 'WebDAV / Nextcloud Notes';

  @override
  String get description =>
      'Syncs E2EE-encrypted notes & styles directly to your WebDAV server.';

  @override
  Future<bool> isConfigured() async => (await _client()) != null;

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final client = await _client();
      if (client == null) {
        return StorageTestResult(
          success: false,
          message: 'Configure WebDAV server details first.',
          latency: sw.elapsed,
        );
      }
      final probe = [client.config.rootFolder, _notesFolder, '.probe.json'];
      await client.putBytes(probe, utf8.encode('{"ok":true}'),
          contentType: 'application/json');
      final got = await client.getBytes(probe);
      await client.deleteResource(probe);
      final ok = got != null && utf8.decode(got).contains('"ok":true');
      return StorageTestResult(
        success: ok,
        message: ok
            ? 'WebDAV Notes folder read/write verified.'
            : 'WebDAV Notes probe failed.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'WebDAV Notes test failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  String _noteFile(String noteId) =>
      'note_${StorageSecurityHelper.sanitizeSegment(noteId, fallback: 'note')}.json';

  @override
  Future<List<Note>> fetchNotes(String userId) async {
    final client = await _client();
    if (client == null) return [];
    final entries =
        await client.listEntries([client.config.rootFolder, _notesFolder]);
    final notes = <Note>[];
    for (final entry in entries) {
      if (!entry.name.startsWith('note_') || !entry.name.endsWith('.json')) {
        continue;
      }
      try {
        final bytes = await client
            .getBytes([client.config.rootFolder, _notesFolder, entry.name]);
        if (bytes == null) continue;
        final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final note = Note.fromMap(map);
        if (note.userId == userId || note.userId.isEmpty) {
          notes.add(note.copyWith(isSynced: true));
        }
      } catch (_) {}
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<void> upsertNote(Note note) async {
    final client = await _client();
    if (client == null) {
      throw Exception('WebDAV Notes storage is not configured.');
    }
    final bytes = utf8.encode(jsonEncode(note.toSupabaseMap()));
    await client.putBytes(
      [client.config.rootFolder, _notesFolder, _noteFile(note.id)],
      bytes,
      contentType: 'application/json',
    );
  }

  @override
  Future<void> deleteNote(Note note) async {
    final client = await _client();
    if (client == null) return;
    await client.deleteResource(
      [client.config.rootFolder, _notesFolder, _noteFile(note.id)],
    );
  }

  @override
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async {
    try {
      final client = await _client();
      if (client == null) return null;
      final bytes = await client.getBytes(
        [client.config.rootFolder, _notesFolder, _styleFileName],
      );
      if (bytes == null) return null;
      return NoteStyleSettings.tryParseJsonString(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {
    final client = await _client();
    if (client == null) return;
    await client.putBytes(
      [client.config.rootFolder, _notesFolder, _styleFileName],
      utf8.encode(style.toJsonString()),
      contentType: 'application/json',
    );
  }
}
