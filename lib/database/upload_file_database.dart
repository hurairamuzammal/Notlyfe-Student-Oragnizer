import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart' as mime;
import 'package:notlyfe/database/local/courses_local_database.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/services/storage/providers/google_drive_providers.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadFile {
  final supabase = Supabase.instance.client;
  final tableInstance = Supabase.instance.client.from('user_files');
  final _driveService = GoogleDriveStorageService.instance;
  final _registry = StorageBackendRegistry.instance;

  Future<Directory> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(directory.path, 'notlyfe_downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  String lookupMimeType(String path) {
    final mimeType = mime.lookupMimeType(path);
    if (mimeType != null) return mimeType;

    switch (path.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> _resolveCourseTitle(
      String courseId, String? providedTitle) async {
    if (providedTitle != null && providedTitle.trim().isNotEmpty) {
      return providedTitle.trim();
    }
    try {
      final course = await CoursesLocalDatabase().getCourse(courseId);
      if (course != null && course.title.trim().isNotEmpty) {
        return course.title.trim();
      }
    } catch (_) {}
    return 'Course_$courseId';
  }

  /// Ensures the active file storage provider is configured (prompts Google Drive
  /// sign-in if Drive is active and disconnected, or warns for custom backends).
  Future<bool> _ensureActiveProviderReady(BuildContext context) async {
    await _registry.initialize();
    final provider = _registry.activeFileProvider;
    if (await provider.isConfigured()) return true;

    if (!context.mounted) return false;

    if (provider.typeId == GoogleDriveFileStorageProvider.id) {
      final shouldConnect = await showM3ConfirmDialog(
        context,
        title: 'Connect Google Drive',
        icon: Icons.add_to_drive_rounded,
        confirmLabel: 'Connect Drive',
        message:
            'Notlyfe stores your course files inside a dedicated "Notlyfe/<Course>" folder on your own Google Drive.\n\n'
            'Privacy Guarantee: Notlyfe only requests permission for its own folder and cannot view or access any other Google Drive files.',
      );
      if (!shouldConnect) return false;

      final err = await _driveService.connectDrive();
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
        return false;
      }
      return err == null;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${provider.displayName} is not configured yet. Open Settings > Storage & Custom Locations.',
        ),
      ),
    );
    return false;
  }

  /// Uploads a picked file into the currently active storage backend.
  Future<String?> uploadFile(
    String courseId,
    BuildContext context, {
    String? courseTitle,
  }) async {
    var progressDialogOpen = false;
    try {
      final userId = supabase.auth.currentUser?.id ?? 'local_user';
      final ready = await _ensureActiveProviderReady(context);
      if (!ready) return null;

      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return null;
      }

      final file = File(result.files.single.path!);
      final originalName =
          StorageSecurityHelper.sanitizeFileName(result.files.single.name);
      final mimeType = lookupMimeType(file.path);
      final resolvedTitle = await _resolveCourseTitle(courseId, courseTitle);
      final activeProvider = _registry.activeFileProvider;

      if (!context.mounted) return null;

      final progressController = M3TransferProgressController();
      progressDialogOpen = true;
      showM3TransferProgressDialog(
        context,
        fileName: originalName,
        icon: Icons.cloud_upload_rounded,
        controller: progressController,
        initialStatus: 'Uploading...',
      );

      final uploadedFile = await activeProvider.uploadFile(
        courseId: courseId,
        courseTitle: resolvedTitle,
        file: file,
        fileName: originalName,
        mimeType: mimeType,
        userId: userId,
        onProgress: (sent, total, speed) {
          progressController.update(
            transferred: sent,
            total: total,
            speedBytesPerSec: speed,
            fallbackVerb: 'Uploading...',
          );
        },
      );

      if (progressDialogOpen && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        progressDialogOpen = false;
      }

      if (uploadedFile == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to upload file to ${activeProvider.displayName}'),
            ),
          );
        }
        return null;
      }

      await _cacheCustomProviderFile(uploadedFile);

      if (activeProvider.typeId == GoogleDriveFileStorageProvider.id) {
        try {
          if (supabase.auth.currentUser != null) {
            await tableInstance.insert(uploadedFile.toMap());
          }
        } catch (_) {}
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved to ${activeProvider.displayName} ($resolvedTitle)',
            ),
          ),
        );
      }

      return uploadedFile.filePath;
    } catch (error) {
      if (progressDialogOpen && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      debugPrint('File upload error: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload file. Please check your storage connection.'),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _cacheCustomProviderFile(UserFiles file) async {
    try {
      if (!Hive.isBoxOpen('testBox')) return;
      final box = Hive.box('testBox');
      final key = 'custom_files_${file.courseId}';
      final rawList = box.get(key, defaultValue: <dynamic>[]) as List? ?? [];
      final updated = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['file_path'] != file.filePath)
          .toList();
      updated.insert(0, file.toMap());
      await box.put(key, updated);
    } catch (_) {}
  }

  /// Lists course files from the active file storage backend + legacy metadata.
  Future<List<UserFiles>> getFilesByUser(
    String courseId, {
    String? courseTitle,
  }) async {
    await _registry.initialize();
    final userId = supabase.auth.currentUser?.id ?? 'local_user';
    final resolvedTitle = await _resolveCourseTitle(courseId, courseTitle);
    final activeProvider = _registry.activeFileProvider;
    final Map<String, UserFiles> merged = {};

    try {
      if (await activeProvider.isConfigured()) {
        final providerFiles = await activeProvider.listFiles(
          courseId: courseId,
          courseTitle: resolvedTitle,
          userId: userId,
        );
        for (final pf in providerFiles) {
          merged[pf.filePath] = pf;
        }
      } else {
        final cached = await _driveService.getCachedFilesForCourse(courseId);
        for (final cf in cached) {
          merged[cf.filePath] = cf;
        }
      }
    } catch (e) {
      debugPrint('Active provider list notice: $e');
    }

    // Include legacy Drive cache or Supabase user_files when applicable
    if (activeProvider.typeId == GoogleDriveFileStorageProvider.id) {
      try {
        if (supabase.auth.currentUser != null) {
          final response = await tableInstance
              .select()
              .eq('user_id', supabase.auth.currentUser!.id)
              .eq('course_id', courseId);
          for (final fileMap in (response as List<dynamic>)) {
            final f = UserFiles.fromMap(fileMap as Map<String, dynamic>);
            merged.putIfAbsent(f.filePath, () => f);
          }
        }
      } catch (_) {}
    }

    final files = merged.values.toList();
    await _syncLocalDownloadedFlags(files);
    return files;
  }

  Future<void> _syncLocalDownloadedFlags(List<UserFiles> files) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedFiles = prefs.getStringList('downloaded_files') ?? [];
    final dir = await _localPath;

    for (final file in files) {
      final safeName = StorageSecurityHelper.sanitizeFileName(file.fileName);
      final filePath = p.join(dir.path, safeName);
      final exists = await File(filePath).exists();
      file.isDownloaded =
          exists || downloadedFiles.contains(file.id.toString());

      if (file.isDownloaded && !exists) {
        file.isDownloaded = false;
        downloadedFiles.remove(file.id.toString());
        await prefs.setStringList('downloaded_files', downloadedFiles);
      }
    }
  }

  /// Returns locally cached files for [courseId] in offline mode.
  Future<List<UserFiles>> getDownloadedFilesByCourse(String courseId) async {
    final List<UserFiles> downloadedFiles = [];
    try {
      final dir = await _localPath;
      if (!await dir.exists()) return [];

      final cachedCourseFiles =
          await _driveService.getCachedFilesForCourse(courseId);
      for (final cf in cachedCourseFiles) {
        final safeName = StorageSecurityHelper.sanitizeFileName(cf.fileName);
        if (await File('${dir.path}/$safeName').exists()) {
          cf.isDownloaded = true;
          downloadedFiles.add(cf);
        }
      }
      if (downloadedFiles.isNotEmpty) return downloadedFiles;

      if (Hive.isBoxOpen('testBox')) {
        final raw = Hive.box('testBox')
                .get('custom_files_$courseId', defaultValue: <dynamic>[])
            as List?;
        for (final entry in raw ?? const []) {
          final cf =
              UserFiles.fromMap(Map<String, dynamic>.from(entry as Map));
          final safeName = StorageSecurityHelper.sanitizeFileName(cf.fileName);
          if (await File('${dir.path}/$safeName').exists()) {
            cf.isDownloaded = true;
            downloadedFiles.add(cf);
          }
        }
      }
      if (downloadedFiles.isNotEmpty) return downloadedFiles;

      final prefs = await SharedPreferences.getInstance();
      final downloadedFileIds = prefs.getStringList('downloaded_files') ?? [];
      if (downloadedFileIds.isEmpty) return [];

      for (final fileEntity in await dir.list().toList()) {
        if (fileEntity is File) {
          final fileName = fileEntity.path.split('/').last;
          final matchedId = downloadedFileIds
              .where((id) => fileName.contains(id))
              .firstOrNull;
          if (matchedId != null) {
            downloadedFiles.add(UserFiles(
              id: int.tryParse(matchedId) ?? 0,
              filePath: fileEntity.path,
              fileName: fileName,
              fileType: lookupMimeType(fileEntity.path),
              userId: '',
              courseId: courseId,
              fileSize: await fileEntity.length(),
              isDownloaded: true,
            ));
          }
        }
      }
      return downloadedFiles;
    } catch (e) {
      debugPrint('Error getting downloaded files by course: $e');
      return [];
    }
  }

  /// Downloads [file] from its owning storage provider (or legacy HTTP URL).
  Future<bool> downloadFile(
    UserFiles file,
    BuildContext context, {
    Function(double)? onProgress,
  }) async {
    await _registry.initialize();
    final progressController = M3TransferProgressController();
    var progressDialogOpen = false;

    try {
      final dir = await _localPath;
      final safeName = StorageSecurityHelper.sanitizeFileName(file.fileName);
      final localFile = File(p.join(dir.path, safeName));

      if (await localFile.exists()) {
        await _markDownloadedId(file.id);
        return true;
      }

      if (context.mounted) {
        progressDialogOpen = true;
        showM3TransferProgressDialog(
          context,
          fileName: file.fileName,
          icon: Icons.download_rounded,
          controller: progressController,
          initialStatus: 'Downloading...',
        );
      }

      void reportProgress(int received, int total, double speedBytesPerSec) {
        final effectiveTotal = total > 0 ? total : file.fileSize;
        progressController.update(
          transferred: received,
          total: effectiveTotal,
          speedBytesPerSec: speedBytesPerSec,
          fallbackVerb: 'Downloading...',
        );
        if (onProgress != null && effectiveTotal > 0) {
          onProgress((received / effectiveTotal).clamp(0.0, 1.0));
        }
      }

      final owningProvider = _registry.findFileProviderForPath(file.filePath);
      if (owningProvider != null) {
        final ok = await owningProvider.downloadFile(
          file: file,
          destinationFile: localFile,
          onProgress: reportProgress,
        );
        if (progressDialogOpen && context.mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
          progressDialogOpen = false;
        }
        if (ok) {
          await _markDownloadedId(file.id);
          return true;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not download file from ${owningProvider.displayName}',
              ),
            ),
          );
        }
        return false;
      }

      // Legacy HTTP URL download (validate endpoint before sending request).
      final downloadUrl = await _resolveLegacySignedUrl(file.filePath);
      final validation =
          StorageSecurityHelper.validateEndpointUrl(downloadUrl);
      if (!validation.isValid) {
        throw Exception('Blocked unsafe download URL.');
      }

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(downloadUrl))
          ..headers['Content-Type'] = 'application/octet-stream';
        final streamedResponse = await client.send(req);

        if (streamedResponse.statusCode == 200) {
          final total = streamedResponse.contentLength ?? file.fileSize;
          var received = 0;
          final sink = localFile.openWrite();
          try {
            final stopwatch = Stopwatch()..start();
            var lastReportedTime = 0;

            await for (final chunk in streamedResponse.stream) {
              sink.add(chunk);
              received += chunk.length;
              final elapsedMs = stopwatch.elapsedMilliseconds;
              if (elapsedMs - lastReportedTime > 150 ||
                  (total > 0 && received == total)) {
                lastReportedTime = elapsedMs;
                final speed =
                    elapsedMs > 0 ? (received / (elapsedMs / 1000.0)) : 0.0;
                reportProgress(received, total, speed);
              }
            }
            await sink.flush();
          } catch (_) {
            if (await localFile.exists()) {
              try {
                await localFile.delete();
              } catch (_) {}
            }
            rethrow;
          } finally {
            await sink.close();
          }

          if (progressDialogOpen && context.mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
            progressDialogOpen = false;
          }
          await _markDownloadedId(file.id);
          return true;
        } else {
          if (progressDialogOpen && context.mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
            progressDialogOpen = false;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Download failed: HTTP ${streamedResponse.statusCode}',
                ),
              ),
            );
          }
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (progressDialogOpen && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      debugPrint('Download error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download file.')),
        );
      }
      return false;
    }
  }

  Future<void> _markDownloadedId(int fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('downloaded_files') ?? [];
    final idStr = fileId.toString();
    if (!list.contains(idStr)) {
      list.add(idStr);
      await prefs.setStringList('downloaded_files', list);
    }
  }

  Future<String> _resolveLegacySignedUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.host.toLowerCase().endsWith('.supabase.co')) {
      return rawUrl;
    }
    try {
      final segments = uri.pathSegments;
      final objectIndex = segments.indexOf('object');
      if (objectIndex != -1 && segments.length > objectIndex + 2) {
        final bucket = segments[objectIndex + 2];
        final filePathInBucket = segments.sublist(objectIndex + 3).join('/');
        if (bucket.isNotEmpty && filePathInBucket.isNotEmpty) {
          final signed = await supabase.storage
              .from(bucket)
              .createSignedUrl(filePathInBucket, 3600);
          if (signed.isNotEmpty) return signed;
        }
      }
    } catch (_) {}
    return rawUrl;
  }

  Future<void> openFile(UserFiles file, BuildContext context) async {
    try {
      if (!file.isRemoteOrVirtual) {
        if (await File(file.filePath).exists()) {
          final result = await OpenFile.open(file.filePath);
          if (result.type != ResultType.done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: ${result.message}')),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found')),
          );
        }
        return;
      }

      final dir = await _localPath;
      final safeName = StorageSecurityHelper.sanitizeFileName(file.fileName);
      final localPath = '${dir.path}/$safeName';
      if (await File(localPath).exists()) {
        final result = await OpenFile.open(localPath);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
        return;
      }

      if (!context.mounted) return;
      final downloaded = await downloadFile(file, context);
      if (downloaded && context.mounted) {
        final result = await OpenFile.open(localPath);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<bool> deleteDownloadedFile(
      UserFiles file, BuildContext context) async {
    try {
      final dir = await _localPath;
      final safeName = StorageSecurityHelper.sanitizeFileName(file.fileName);
      final localFile = File('${dir.path}/$safeName');
      if (await localFile.exists()) {
        await localFile.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      final downloadedFiles = prefs.getStringList('downloaded_files') ?? [];
      downloadedFiles.remove(file.id.toString());
      await prefs.setStringList('downloaded_files', downloadedFiles);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e')),
        );
      }
      return false;
    }
  }

  Future<bool> deleteFile(UserFiles file, BuildContext context) async {
    try {
      await _registry.initialize();
      if (context.mounted) {
        await deleteDownloadedFile(file, context);
      }

      final owningProvider = _registry.findFileProviderForPath(file.filePath);
      final userId = supabase.auth.currentUser?.id;
      if (owningProvider != null) {
        await owningProvider.deleteFile(file);
        if (Hive.isBoxOpen('testBox')) {
          final box = Hive.box('testBox');
          for (final key in [
            if (userId != null) 'gdrive_files_${userId}_${file.courseId}',
            'gdrive_files_${file.courseId}',
            'custom_files_${file.courseId}',
          ]) {
            final rawList = box.get(key, defaultValue: <dynamic>[]) as List? ?? [];
            final updated = rawList
                .map((e) => Map<String, dynamic>.from(e as Map))
                .where((m) => m['file_path'] != file.filePath)
                .toList();
            await box.put(key, updated);
          }
        }
      } else if (file.filePath.startsWith('http') && userId != null) {
        try {
          final uri = Uri.parse(file.filePath);
          final fileName = uri.pathSegments.last;
          await supabase.storage
              .from('uploaded_files')
              .remove(['public/$userId/$fileName']);
        } catch (_) {}
      }

      if (userId != null) {
        try {
          await tableInstance
              .delete()
              .eq('id', file.id)
              .eq('user_id', userId);
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete file.')),
        );
      }
      return false;
    }
  }

  IconData getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_rounded;
    if (mimeType.startsWith('video/')) return Icons.video_file_rounded;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_rounded;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_rounded;
    }
    if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return Icons.table_chart_rounded;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow_rounded;
    }
    if (mimeType.contains('zip') || mimeType.contains('compressed')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  String getFormattedFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
