import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notlyfe/database/upload_file_database.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final UploadFile _uploadFileService = UploadFile();
  List<UserFiles> _downloadedFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  // Load all downloaded files
  Future<void> _loadDownloadedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _getDownloadedFiles();

      setState(() {
        _downloadedFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading downloads: ${e.toString()}')),
        );
      }
    }
  }

  // Get only downloaded files
  Future<List<UserFiles>> _getDownloadedFiles() async {
    final List<UserFiles> downloadedFiles = [];

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(directory.path, 'notlyfe_downloads'));

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final files = await downloadsDir.list().toList();

      for (final fileEntity in files) {
        if (fileEntity is File) {
          final file = fileEntity;
          final fileName = p.basename(file.path);

          // Get file size
          final fileSize = await file.length();

          // Get file type - handle different file types correctly
          String fileType;
          try {
            fileType = _uploadFileService.lookupMimeType(file.path);
          } catch (e) {
            // Fallback to determine file type from extension
            if (fileName.toLowerCase().endsWith('.pdf')) {
              fileType = 'application/pdf';
            } else if (fileName.toLowerCase().endsWith('.jpg') ||
                fileName.toLowerCase().endsWith('.jpeg')) {
              fileType = 'image/jpeg';
            } else if (fileName.toLowerCase().endsWith('.png')) {
              fileType = 'image/png';
            } else if (fileName.toLowerCase().endsWith('.mp4')) {
              fileType = 'video/mp4';
            } else if (fileName.toLowerCase().endsWith('.mp3')) {
              fileType = 'audio/mp3';
            } else if (fileName.toLowerCase().endsWith('.docx')) {
              fileType =
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            } else if (fileName.toLowerCase().endsWith('.xlsx')) {
              fileType =
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            } else {
              fileType = 'application/octet-stream';
            }
          }

          // Extract ID from filename if available (for previously downloaded files)
          int fileId;
          try {
            if (fileName.contains('_')) {
              fileId = int.parse(fileName.split('_').first);
            } else {
              // Generate a unique ID based on file path
              fileId = fileName.hashCode;
            }
          } catch (e) {
            // Fallback ID generation
            fileId =
                DateTime.now().millisecondsSinceEpoch + downloadedFiles.length;
          }

          // Create a UserFiles object
          final userFile = UserFiles(
            id: fileId,
            filePath: file.path,
            fileName: fileName.contains('_')
                ? fileName.split('_').skip(1).join('_')
                : fileName,
            fileType: fileType,
            userId: '', // Local files don't need user ID
            courseId: '', // Local files don't need course ID
            fileSize: fileSize,
            isDownloaded: true, // Always true for local files
          );

          downloadedFiles.add(userFile);
        }
      }

      return downloadedFiles;
    } catch (e) {
      debugPrint('Error getting downloaded files: $e');
      return [];
    }
  }

  // Filter files by search query
  List<UserFiles> _getFilteredFiles() {
    if (_searchQuery.isEmpty) {
      return _downloadedFiles;
    }

    return _downloadedFiles
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
              'Offline Downloads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Locally cached copies for offline access',
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
            onPressed: _loadDownloadedFiles,
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
                hintText: 'Search offline files...',
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
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_for_offline,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No downloaded files yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Downloaded files will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredFiles.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          return DownloadedFileItem(
                            file: file,
                            uploadFileService: _uploadFileService,
                            onRefresh: _loadDownloadedFiles,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class DownloadedFileItem extends StatelessWidget {
  final UserFiles file;
  final UploadFile uploadFileService;
  final VoidCallback onRefresh;

  const DownloadedFileItem({
    super.key,
    required this.file,
    required this.uploadFileService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 0,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22.0),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: () => _openFile(context),
        borderRadius: BorderRadius.circular(22.0),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              M3IconBadge(
                icon: _getFileIcon(),
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
                    Text(
                      uploadFileService.getFormattedFileSize(file.fileSize),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  if (value == 'open') {
                    _openFile(context);
                  } else if (value == 'delete') {
                    _deleteFile(context);
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
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get file icon based on file type
  IconData _getFileIcon() {
    // First try using the service's getFileIcon method
    final serviceIcon = uploadFileService.getFileIcon(file.fileType);

    // If that returns the default icon and we have a file extension, try to determine from extension
    if (serviceIcon == Icons.insert_drive_file && file.fileName.contains('.')) {
      final extension = file.fileName.split('.').last.toLowerCase();

      switch (extension) {
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
        case 'webp':
          return Icons.image;
        case 'mp4':
        case 'mov':
        case 'avi':
          return Icons.video_file;
        case 'mp3':
        case 'wav':
        case 'ogg':
          return Icons.audio_file;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow;
        case 'zip':
        case 'rar':
        case '7z':
          return Icons.folder_zip;
        default:
          return serviceIcon;
      }
    }

    return serviceIcon;
  }

  Future<void> _openFile(BuildContext context) async {
    final localFile = File(file.filePath);

    if (await localFile.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Launching file...'),
          duration: Duration(seconds: 1),
        ),
      );

      await uploadFileService.openFile(file, context);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on device')),
      );
      onRefresh();
    }
  }

  Future<void> _deleteFile(BuildContext context) async {
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
      try {
        final localFile = File(file.filePath);
        if (await localFile.exists()) {
          await localFile.delete();
        }

        final prefs = await SharedPreferences.getInstance();
        final downloadedFiles = prefs.getStringList('downloaded_files') ?? [];
        downloadedFiles.remove(file.id.toString());
        await prefs.setStringList('downloaded_files', downloadedFiles);

        onRefresh();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: ${e.toString()}')),
        );
      }
    }
  }
}
