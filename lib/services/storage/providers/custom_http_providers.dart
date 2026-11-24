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

/// Persisted configuration for a custom REST / self-hosted storage endpoint.
@immutable
class CustomHttpConfig {
  final String baseUrl;
  final String authHeaderName;
  final String authToken;

  const CustomHttpConfig({
    required this.baseUrl,
    this.authHeaderName = 'Authorization',
    this.authToken = '',
  });

  static const _prefUrl = 'custom_http_base_url';
  static const _prefHeader = 'custom_http_auth_header';
  static const _secToken = 'custom_http_auth_token_v1';

  bool get isValid =>
      baseUrl.trim().isNotEmpty &&
      StorageSecurityHelper.validateEndpointUrl(baseUrl).isValid;

  Map<String, String> buildHeaders({String? contentType}) {
    final headers = <String, String>{};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    if (authToken.isNotEmpty) {
      final headerName =
          authHeaderName.trim().isEmpty ? 'Authorization' : authHeaderName.trim();
      final value = (headerName.toLowerCase() == 'authorization' &&
              !authToken.toLowerCase().startsWith('bearer '))
          ? 'Bearer $authToken'
          : authToken;
      headers[headerName] = value;
    }
    return headers;
  }

  static Future<CustomHttpConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefUrl) ?? '';
    if (url.trim().isEmpty) return null;
    final header = prefs.getString(_prefHeader) ?? 'Authorization';
    final token = await SecureStorageService.readSecure(_secToken) ?? '';
    return CustomHttpConfig(
      baseUrl: url,
      authHeaderName: header.isEmpty ? 'Authorization' : header,
      authToken: token,
    );
  }

  static Future<void> save(CustomHttpConfig config) async {
    final check = StorageSecurityHelper.validateEndpointUrl(config.baseUrl);
    if (!check.isValid) {
      throw ArgumentError(check.error);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrl, check.normalizedUrl!);
    await prefs.setString(
      _prefHeader,
      config.authHeaderName.trim().isEmpty
          ? 'Authorization'
          : config.authHeaderName.trim(),
    );
    if (config.authToken.isEmpty) {
      await SecureStorageService.deleteSecure(_secToken);
    } else {
      await SecureStorageService.writeSecure(_secToken, config.authToken);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUrl);
    await prefs.remove(_prefHeader);
    await SecureStorageService.deleteSecure(_secToken);
  }
}

/// Custom REST/HTTP file storage backend following Notlyfe's open-source API contract.
///
/// Endpoints:
/// - `GET  /health` -> 200 OK
/// - `POST /files` (multipart: `file`, `courseId`, `courseTitle`, `userId`, `fileName`, `mimeType`) -> `{ "id": "...", "fileName": "...", "fileSize": 123 }`
/// - `GET  /files?courseId=<id>&userId=<uid>` -> JSON list of `{ "id", "fileName", "fileType", "fileSize", "courseId" }`
/// - `GET  /files/<id>` -> raw file bytes
/// - `DELETE /files/<id>` -> 200/204
class CustomHttpFileStorageProvider extends CustomFileStorageProvider {
  static const String id = 'custom_http';

  final Future<CustomHttpConfig?> Function()? _configLoader;
  final http.Client _client;

  CustomHttpFileStorageProvider({
    Future<CustomHttpConfig?> Function()? configLoader,
    http.Client? httpClient,
  })  : _configLoader = configLoader,
        _client = httpClient ?? http.Client();

  Future<CustomHttpConfig?> _loadConfig() =>
      _configLoader != null ? _configLoader() : CustomHttpConfig.load();

  @override
  String get typeId => id;

  @override
  String get displayName => 'Custom REST / Self-Hosted API';

  @override
  String get description =>
      'Connect your own S3 proxy, Cloudflare Worker, or self-hosted server.';

  @override
  String get pathScheme => 'customhttp';

  @override
  Future<bool> isConfigured() async {
    final cfg = await _loadConfig();
    return cfg != null && cfg.isValid;
  }

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final cfg = await _loadConfig();
      if (cfg == null || !cfg.isValid) {
        return StorageTestResult(
          success: false,
          message: 'Custom REST endpoint URL is not configured.',
          latency: sw.elapsed,
        );
      }
      final res = await _client.get(
        Uri.parse('${cfg.baseUrl}/health'),
        headers: cfg.buildHeaders(),
      );
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return StorageTestResult(
        success: ok,
        message: ok
            ? 'Endpoint /health responded ${res.statusCode} OK.'
            : 'Endpoint /health returned HTTP ${res.statusCode}.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Custom HTTP health probe failed: $e',
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
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) {
      throw Exception('Custom HTTP storage is not configured.');
    }
    final safeName = StorageSecurityHelper.sanitizeFileName(fileName);
    final bytes = await file.readAsBytes();
    onProgress?.call(bytes.length, bytes.length, 0);

    final req = http.MultipartRequest('POST', Uri.parse('${cfg.baseUrl}/files'))
      ..headers.addAll(cfg.buildHeaders())
      ..fields['courseId'] = courseId
      ..fields['courseTitle'] = courseTitle
      ..fields['userId'] = userId
      ..fields['fileName'] = safeName
      ..fields['mimeType'] = mimeType
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: safeName));

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException('Custom HTTP upload failed (${streamed.statusCode})');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final remoteId = (json['id'] ?? safeName).toString();
    final virtualPath = 'customhttp://${Uri.encodeComponent(remoteId)}';
    return UserFiles(
      id: remoteId.hashCode.abs(),
      filePath: virtualPath,
      fileName: (json['fileName'] ?? safeName).toString(),
      fileType: (json['fileType'] ?? mimeType).toString(),
      userId: userId,
      courseId: courseId,
      fileSize: (json['fileSize'] as num?)?.toInt() ?? bytes.length,
    );
  }

  @override
  Future<List<UserFiles>> listFiles({
    required String courseId,
    required String courseTitle,
    required String userId,
  }) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) return [];
    final uri = Uri.parse('${cfg.baseUrl}/files').replace(queryParameters: {
      'courseId': courseId,
      'userId': userId,
    });
    final res = await _client.get(uri, headers: cfg.buildHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return [];
    final decoded = jsonDecode(res.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['files'] is List
            ? decoded['files'] as List
            : const []);
    return list.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final remoteId = (m['id'] ?? m['fileName'] ?? '').toString();
      return UserFiles(
        id: remoteId.hashCode.abs(),
        filePath: 'customhttp://${Uri.encodeComponent(remoteId)}',
        fileName: (m['fileName'] ?? 'Untitled').toString(),
        fileType: (m['fileType'] ?? 'application/octet-stream').toString(),
        userId: userId,
        courseId: (m['courseId'] ?? courseId).toString(),
        fileSize: (m['fileSize'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  String _remoteId(String virtualPath) =>
      Uri.decodeComponent(virtualPath.substring('customhttp://'.length));

  @override
  Future<bool> downloadFile({
    required UserFiles file,
    required File destinationFile,
    StorageProgressCallback? onProgress,
  }) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) return false;
    final id = Uri.encodeComponent(_remoteId(file.filePath));
    final res = await _client.get(
      Uri.parse('${cfg.baseUrl}/files/$id'),
      headers: cfg.buildHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    await destinationFile.writeAsBytes(res.bodyBytes);
    onProgress?.call(res.bodyBytes.length, res.bodyBytes.length, 0);
    return true;
  }

  @override
  Future<bool> deleteFile(UserFiles file) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) return false;
    final id = Uri.encodeComponent(_remoteId(file.filePath));
    final res = await _client.delete(
      Uri.parse('${cfg.baseUrl}/files/$id'),
      headers: cfg.buildHeaders(),
    );
    return res.statusCode == 404 ||
        (res.statusCode >= 200 && res.statusCode < 300);
  }
}

/// Custom REST/HTTP notes & default style provider (E2EE payloads over JSON).
///
/// Endpoints:
/// - `GET    /health` -> 200 OK
/// - `GET    /notes?userId=<uid>` -> JSON list of note maps
/// - `PUT    /notes/<id>` -> upsert encrypted note JSON
/// - `DELETE /notes/<id>` -> delete note
/// - `GET    /notes/style/<uid>` -> default style JSON
/// - `PUT    /notes/style/<uid>` -> save default style JSON
class CustomHttpNotesStorageProvider extends CustomNotesStorageProvider {
  static const String id = 'custom_http_notes';

  final Future<CustomHttpConfig?> Function()? _configLoader;
  final http.Client _client;

  CustomHttpNotesStorageProvider({
    Future<CustomHttpConfig?> Function()? configLoader,
    http.Client? httpClient,
  })  : _configLoader = configLoader,
        _client = httpClient ?? http.Client();

  Future<CustomHttpConfig?> _loadConfig() =>
      _configLoader != null ? _configLoader() : CustomHttpConfig.load();

  @override
  String get typeId => id;

  @override
  String get displayName => 'Custom REST / Self-Hosted Notes';

  @override
  String get description =>
      'Store E2EE-encrypted notes on your own server or Supabase proxy.';

  @override
  Future<bool> isConfigured() async {
    final cfg = await _loadConfig();
    return cfg != null && cfg.isValid;
  }

  @override
  Future<StorageTestResult> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      final cfg = await _loadConfig();
      if (cfg == null || !cfg.isValid) {
        return StorageTestResult(
          success: false,
          message: 'Custom REST endpoint URL is not configured.',
          latency: sw.elapsed,
        );
      }
      final res = await _client.get(
        Uri.parse('${cfg.baseUrl}/health'),
        headers: cfg.buildHeaders(),
      );
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return StorageTestResult(
        success: ok,
        message: ok
            ? 'Custom Notes API /health returned ${res.statusCode} OK.'
            : 'Custom Notes API returned HTTP ${res.statusCode}.',
        latency: sw.elapsed,
      );
    } catch (e) {
      return StorageTestResult(
        success: false,
        message: 'Custom Notes API probe failed: $e',
        latency: sw.elapsed,
      );
    }
  }

  @override
  Future<List<Note>> fetchNotes(String userId) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) return [];
    final uri = Uri.parse('${cfg.baseUrl}/notes')
        .replace(queryParameters: {'userId': userId});
    final res = await _client.get(uri, headers: cfg.buildHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Custom HTTP fetchNotes failed (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['notes'] is List
            ? decoded['notes'] as List
            : const []);
    return list
        .map((m) =>
            Note.fromMap(Map<String, dynamic>.from(m as Map)).copyWith(
              isSynced: true,
            ))
        .toList();
  }

  @override
  Future<void> upsertNote(Note note) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) {
      throw Exception('Custom HTTP notes storage is not configured.');
    }
    final safeId = Uri.encodeComponent(note.id);
    final res = await _client.put(
      Uri.parse('${cfg.baseUrl}/notes/$safeId'),
      headers: cfg.buildHeaders(contentType: 'application/json'),
      body: jsonEncode(note.toSupabaseMap()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Custom HTTP upsertNote failed (${res.statusCode})');
    }
  }

  @override
  Future<void> deleteNote(Note note) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) return;
    final safeId = Uri.encodeComponent(note.id);
    await _client.delete(
      Uri.parse('${cfg.baseUrl}/notes/$safeId'),
      headers: cfg.buildHeaders(),
    );
  }

  @override
  Future<NoteStyleSettings?> fetchDefaultNoteStyle(String userId) async {
    try {
      final cfg = await _loadConfig();
      if (cfg == null || !cfg.isValid) return null;
      final res = await _client.get(
        Uri.parse('${cfg.baseUrl}/notes/style/${Uri.encodeComponent(userId)}'),
        headers: cfg.buildHeaders(),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return NoteStyleSettings.tryParseJsonString(res.body);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDefaultNoteStyle(
    String userId,
    NoteStyleSettings style,
  ) async {
    final cfg = await _loadConfig();
    if (cfg == null || !cfg.isValid) return;
    await _client.put(
      Uri.parse('${cfg.baseUrl}/notes/style/${Uri.encodeComponent(userId)}'),
      headers: cfg.buildHeaders(contentType: 'application/json'),
      body: style.toJsonString(),
    );
  }
}
