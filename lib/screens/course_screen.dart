import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notlyfe/data/course_icons.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/database/upload_file_database.dart';
import 'package:notlyfe/models/upload_file.dart';
import 'package:notlyfe/providers/colorful_mode_provider.dart';
import 'package:notlyfe/providers/connection_status_provider.dart';
import 'package:notlyfe/widgets/empty_screen.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({super.key, required this.course});
  final Course course;

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  final inst = UploadFile();

  final ScrollController _scrollController = ScrollController();
  final Map<int, bool> _downloadingFiles = {};
  late Future<List<UserFiles>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = inst.getFilesByUser(
      widget.course.id,
      courseTitle: widget.course.title,
    );
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = inst.getFilesByUser(
        widget.course.id,
        courseTitle: widget.course.title,
      );
    });
  }

  void uploadFileLocal() async {
    final res = await inst.uploadFile(
      widget.course.id,
      context,
      courseTitle: widget.course.title,
    );
    if (res != null) {
      _refreshFiles();
    }
  }

  Future<void> _downloadFile(UserFiles file) async {
    if (_downloadingFiles[file.id] == true) return; // Already downloading

    setState(() {
      _downloadingFiles[file.id] = true;
    });

    try {
      final success = await inst.downloadFile(file, context);
      if (success && mounted) {
        setState(() {
          file.isDownloaded = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingFiles.remove(file.id);
        });
      }
    }
  }

  Future<void> _openFile(UserFiles file) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Launching file...'),
        duration: Duration(seconds: 1),
      ),
    );
    await inst.openFile(file, context);
  }

  Future<void> _deleteDownloadedFile(UserFiles file) async {
    final success = await inst.deleteDownloadedFile(file, context);
    if (success && mounted) {
      setState(() {
        file.isDownloaded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloaded file deleted')),
      );
    }
  }

  Future<void> _deleteFile(UserFiles file) async {
    final confirmed = await showM3ConfirmDialog(
      context,
      title: 'Delete File',
      message:
          'Are you sure you want to delete "${file.fileName}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed && mounted) {
      final success = await inst.deleteFile(file, context);
      if (success && mounted) {
        _refreshFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted successfully')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Display list of files uploaded by the user
  Widget displayList(bool instanceConnectivity) {
    // if internet is not available, show downloaded files instead of the empty screen
    if (!instanceConnectivity) {
      return FutureBuilder<List<UserFiles>>(
        future: inst.getDownloadedFilesByCourse(widget.course.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: M3ShapeChangingProgressIndicator(size: 36, strokeWidth: 3.5));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Center(
              child: EmptyScreenWidget(
                message: 'Offline files can be viewed from download screen.',
                imagePath: 'assets/koala3.png',
                colorBool: true,
                imageSize: 200,
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.offline_bolt,
                          color: Colors.orange.shade800, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Offline mode: Only displaying downloaded files',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final theme = Theme.of(context);

                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openFile(file),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                inst.getFileIcon(file.fileType),
                                size: 28,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              file.fileName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text(file.fileType, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 2),
                                Text(
                                  inst.getFormattedFileSize(
                                      file.fileSize.toInt()),
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.secondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteDownloadedFile(file),
                              tooltip: 'Delete local copy',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }
    return FutureBuilder<List<UserFiles>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: M3ShapeChangingProgressIndicator(size: 36, strokeWidth: 3.5));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final files = snapshot.data ?? const <UserFiles>[];
        if (files.isEmpty) {
          return Center(
              child: EmptyScreenWidget(
            message: 'No files uploaded yet.',
            imagePath: 'assets/koala3.png',
            colorBool: true,
            imageSize: 200,
          ));
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final theme = Theme.of(context);
            final isDownloading = _downloadingFiles[file.id] == true;

            return Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openFile(file),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            inst.getFileIcon(file.fileType),
                            size: 28,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          file.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(file.fileType, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              inst.getFormattedFileSize(file.fileSize.toInt()),
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (file.isDownloaded) ...[
                              // Downloaded indicator
                              const Icon(Icons.download_done,
                                  color: Colors.green),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteDownloadedFile(file),
                                tooltip: 'Delete local copy',
                              ),
                            ] else if (isDownloading) ...[
                              // Download in progress indicator
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: M3ShapeChangingProgressIndicator(
                                  size: 22,
                                  strokeWidth: 2.2,
                                ),
                              ),
                            ] else ...[
                              // Download button
                              IconButton(
                                icon: const Icon(Icons.download_outlined),
                                onPressed: () => _downloadFile(file),
                                tooltip: 'Download',
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined),
                              onPressed: () => _deleteFile(file),
                              tooltip: 'Delete file',
                            ),
                          ],
                        ),
                      ),
                      // Progress indicator for downloading files
                      if (isDownloading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorfulstatus = ref.watch(colorfulModeProvider);
    final instanceConnectivity = ref.watch(networkServiceProvider);
    final theme = Theme.of(context);

    // Dynamic background color for top header:
    // Samsung One UI / M3 Style: surface container for top header, pure surface/background for content
    final Color topBgColor = theme.colorScheme.surfaceContainerLowest;
    final Color contrastColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Hero(
          tag: 'courseTitle-${widget.course.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              widget.course.title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: contrastColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        // Show connectivity status in the app bar
        actions: [
          if (!instanceConnectivity)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Icon(
                Icons.wifi_off,
                color: contrastColor,
              ),
            ),
        ],
        iconTheme: IconThemeData(color: contrastColor),
        backgroundColor: topBgColor,
        elevation: 0,
      ),
      backgroundColor: topBgColor,
      body: Column(
        children: [
          // Top header container with prominent course icon
          Container(
            height: 120,
            color: topBgColor,
            alignment: Alignment.center,
            child: Hero(
              tag: 'courseImage-${widget.course.id}',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorfulstatus
                      ? widget.course.color.withValues(alpha: 0.18)
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: CourseIconHelper.buildIcon(
                  widget.course.image,
                  size: 64,
                  color: colorfulstatus
                      ? widget.course.color
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          // Rounded container with list inside
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: displayList(instanceConnectivity),
            ),
          ),
        ],
      ),
      // Only show the upload button when online
      floatingActionButton: instanceConnectivity
          ? M3MorphingPillButton(
              selected: true,
              icon: Icons.upload_file_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              onPressed: uploadFileLocal,
              label: const Text('Upload File'),
            )
          : null,
    );
  }
}
