import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notlyfe/database/local/courses_local_database.dart';
import 'package:notlyfe/database/upload_file_database.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/services/storage/providers/google_drive_providers.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({super.key});

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  final UploadFile _uploadFileService = UploadFile();
  List<UserFiles> _allFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
  }

  // Load all files from all courses
  Future<void> _loadAllFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all files from Supabase regardless of course
      final files = await _getAllUserFiles();

      setState(() {
        _allFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: ${e.toString()}')),
        );
      }
    }
  }

  // Get all files from all courses (Google Drive Notlyfe folders + legacy Supabase)
  Future<List<UserFiles>> _getAllUserFiles() async {
    final uploadFileService = UploadFile();
    final supabase = uploadFileService.supabase;

    // Check if user is authenticated (still allow custom local/WebDAV if configured)
    if (supabase.auth.currentUser == null &&
        !(await StorageBackendRegistry.instance.activeFileProvider
            .isConfigured())) {
      return await _getLocalFilesOnly();
    }

    final registry = StorageBackendRegistry.instance;
    await registry.initialize();
    final activeFileProvider = registry.activeFileProvider;
    final userId = supabase.auth.currentUser?.id ?? 'local_user';
    final List<UserFiles> combinedFiles = [];
    final Set<String> seenKeys = {};

    // 1. Fetch files from active storage provider (Drive, WebDAV, Custom HTTP, Local Folder)
    try {
      final courses = await CoursesLocalDatabase().getCourses(userId);
      if (courses.isNotEmpty && await activeFileProvider.isConfigured()) {
        final providerFiles = await activeFileProvider.listAllCoursesFiles(
          courses: courses,
          userId: userId,
        );
        for (final f in providerFiles) {
          final key = '${f.courseId}:${f.fileName}';
          if (seenKeys.add(key)) {
            combinedFiles.add(f);
          }
        }
      }
    } catch (_) {}

    // 2. Also include any existing Supabase files when using Drive default
    if (activeFileProvider.typeId == GoogleDriveFileStorageProvider.id &&
        supabase.auth.currentUser != null) {
      try {
        final response = await uploadFileService.tableInstance
            .select()
            .eq('user_id', userId);

        final supaFiles = (response as List<dynamic>)
            .map((fileMap) =>
                UserFiles.fromMap(fileMap as Map<String, dynamic>))
            .toList();

        for (final f in supaFiles) {
          final key = '${f.courseId}:${f.fileName}';
          if (seenKeys.add(key)) {
            combinedFiles.add(f);
          }
        }
      } catch (_) {}
    }

    if (combinedFiles.isEmpty) {
      return await _getLocalFilesOnly();
    }

    await _updateDownloadedStatus(combinedFiles);
    return combinedFiles;
  }

  // Get only locally downloaded files when offline
  Future<List<UserFiles>> _getLocalFilesOnly() async {
    final List<UserFiles> localFiles = [];

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(directory.path, 'notlyfe_downloads'));

      if (await downloadsDir.exists()) {
        final files = await downloadsDir.list().toList();

        for (final file in files) {
          if (file is File) {
            final fileName = p.basename(file.path);
            final fileSize = await file.length();
            final mimeType = _uploadFileService.lookupMimeType(file.path);

            // Create a UserFiles object for the local file
            final userFile = UserFiles(
              id: int.tryParse(fileName.split('_').first) ?? 0,
              filePath: file.path,
              fileName: fileName.contains('_')
                  ? fileName.split('_').skip(1).join('_')
                  : fileName,
              fileType: mimeType,
              userId: '',
              courseId: '',
              fileSize: fileSize,
              isDownloaded: true,
            );

            localFiles.add(userFile);
          }
        }
      }

      return localFiles;
    } catch (e) {
      return [];
    }
  }

  // Update the download status of files
  Future<void> _updateDownloadedStatus(List<UserFiles> files) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedFiles = prefs.getStringList('downloaded_files') ?? [];

    for (var file in files) {
      file.isDownloaded = downloadedFiles.contains(file.id.toString());

      if (file.isDownloaded) {
        final dir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(p.join(dir.path, 'notlyfe_downloads'));
        final safeName = StorageSecurityHelper.sanitizeFileName(file.fileName);
        final filePath = p.join(downloadsDir.path, safeName);
        final exists = await File(filePath).exists();

        if (!exists) {
          file.isDownloaded = false;
          downloadedFiles.remove(file.id.toString());
          await prefs.setStringList('downloaded_files', downloadedFiles);
        }
      }
    }
  }

  // Filter files by search query
  List<UserFiles> _getFilteredFiles() {
    if (_searchQuery.isEmpty) {
      return _allFiles;
    }

    return _allFiles
        .where((file) =>
            file.fileName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = _getFilteredFiles();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Course Files',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'All uploaded documents & resources',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _loadAllFiles,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search course files...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: M3ShapeChangingProgressIndicator(size: 36, strokeWidth: 3.5))
                : filteredFiles.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No files found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          return FileListItem(
                            file: file,
                            uploadFileService: _uploadFileService,
                            onRefresh: _loadAllFiles,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class FileListItem extends StatefulWidget {
  final UserFiles file;
  final UploadFile uploadFileService;
  final VoidCallback onRefresh;

  const FileListItem({
    super.key,
    required this.file,
    required this.uploadFileService,
    required this.onRefresh,
  });

  @override
  State<FileListItem> createState() => _FileListItemState();
}

class _FileListItemState extends State<FileListItem> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final UserFiles file = widget.file;
    final UploadFile uploadService = widget.uploadFileService;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 0,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22.0),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: () async {
          if (file.isDownloaded) {
            await uploadService.openFile(file, context);
          } else {
            _downloadFile();
          }
        },
        borderRadius: BorderRadius.circular(22.0),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              M3IconBadge(
                icon: uploadService.getFileIcon(file.fileType),
                size: 26,
                padding: const EdgeInsets.all(11),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          uploadService.getFormattedFileSize(file.fileSize),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (file.isDownloaded)
                          Row(
                            children: [
                              Icon(
                                Icons.download_done_rounded,
                                size: 15,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Downloaded',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildActionButton(file),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(UserFiles file) {
    if (_isDownloading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: M3ShapeChangingProgressIndicator(
          size: 22,
          strokeWidth: 2.2,
        ),
      );
    }

    if (file.isDownloaded) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          if (value == 'open') {
            await widget.uploadFileService.openFile(file, context);
          } else if (value == 'delete') {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete File'),
                content: const Text(
                  'Are you sure you want to delete this file from your device?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              if (!mounted) return;
              await widget.uploadFileService
                  .deleteDownloadedFile(file, context);
              widget.onRefresh();
            }
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.open_in_new),
                SizedBox(width: 8),
                Text('Open'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete),
                SizedBox(width: 8),
                Text('Delete from device'),
              ],
            ),
          ),
        ],
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.download),
        onPressed: _downloadFile,
      );
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final success = await widget.uploadFileService.downloadFile(
        widget.file,
        context,
      );

      if (success) {
        setState(() {
          widget.file.isDownloaded = true;
        });
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }
}
