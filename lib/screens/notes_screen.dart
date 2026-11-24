import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/providers/courses_provider.dart';
import 'package:notlyfe/providers/note_style_provider.dart';
import 'package:notlyfe/providers/notes_providers.dart';
import 'package:notlyfe/providers/notes_sync_provider.dart';
import 'package:notlyfe/screens/note_editor_screen.dart';
import 'package:notlyfe/screens/storage_settings_screen.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/utils/note_content_codec.dart';
import 'package:notlyfe/widgets/empty_screen.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:notlyfe/widgets/note_card.dart';
import 'package:notlyfe/widgets/notes/note_style_sheet.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final AuthServices _authService = AuthServices();
  late String _userId;
  List<Course> _courses = [];
  String? _selectedCourseId;
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userId = _authService.getCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noteStyleProvider.notifier).syncFromRemote();
      _refreshNotes();
    });
  }

  Future<void> _refreshNotes() async {
    if (mounted) setState(() => _isLoading = true);

    ref.invalidate(notesProvider);
    if (_selectedCourseId != null) {
      ref.invalidate(courseNotesProvider(_selectedCourseId!));
    }
    ref.invalidate(coursesProvider);

    await Future.delayed(const Duration(milliseconds: 220));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createNewNote() async {
    final note = Note(userId: _userId, courseId: _selectedCourseId);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          isNewNote: true,
          availableCourses: _courses,
        ),
      ),
    );
    if (result == true) _refreshNotes();
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showM3ConfirmDialog(
      context,
      title: 'Delete Note',
      message:
          'Are you sure you want to delete "${note.title.isEmpty ? 'Untitled Note' : note.title}"?',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed) return;
    await ref.read(autoSyncNotesProvider).service.deleteNote(note);
    _refreshNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note "${note.title}" deleted'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openDefaultStyleSheet() {
    final current = ref.read(noteStyleProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteStyleSheet(
        initialStyle: current,
        showApplyToCurrentNote: false,
      ),
    );
  }

  String _getSortOptionName(NoteSortOption option) {
    switch (option) {
      case NoteSortOption.updatedDesc:
        return 'Last Updated (Newest First)';
      case NoteSortOption.updatedAsc:
        return 'Last Updated (Oldest First)';
      case NoteSortOption.createdDesc:
        return 'Created Date (Newest First)';
      case NoteSortOption.createdAsc:
        return 'Created Date (Oldest First)';
      case NoteSortOption.titleAsc:
        return 'Title (A-Z)';
      case NoteSortOption.titleDesc:
        return 'Title (Z-A)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final coursesAsync = ref.watch(coursesProvider);
    final sortOption = ref.watch(noteSortOptionProvider);
    final registry = ref.watch(storageRegistryProvider);
    final notesAsync = _selectedCourseId == null
        ? ref.watch(notesProvider)
        : ref.watch(courseNotesProvider(_selectedCourseId!));

    if (_isLoading && !notesAsync.isLoading && !coursesAsync.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const StorageSettingsScreen()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_rounded, size: 12, color: cs.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      registry.activeNotesProvider.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          M3ExpressiveIconButton(
            icon: Icons.style_rounded,
            tooltip: 'Default Note Style',
            onPressed: _openDefaultStyleSheet,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<NoteSortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort notes',
            onSelected: (option) {
              ref.read(noteSortOptionProvider.notifier).state = option;
            },
            itemBuilder: (_) => [
              for (final option in NoteSortOption.values)
                PopupMenuItem<NoteSortOption>(
                  value: option,
                  child: Row(
                    children: [
                      if (option == sortOption)
                        Icon(Icons.check_rounded, size: 18, color: cs.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(_getSortOptionName(option)),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshNotes,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotes,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search notes by title or content...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Course Filter Chips with M3 Shape Morphing
            coursesAsync.when(
              data: (courses) {
                if (courses.isNotEmpty && courses != _courses) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _courses = courses);
                  });
                }
                if (courses.isEmpty) {
                  return const SizedBox.shrink();
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      M3MorphingFilterChip(
                        label: 'All Notes',
                        selected: _selectedCourseId == null,
                        onTap: () => setState(() => _selectedCourseId = null),
                      ),
                      const SizedBox(width: 8),
                      for (final course in courses) ...[
                        M3MorphingFilterChip(
                          label: course.title,
                          selected: _selectedCourseId == course.id,
                          accentColor: course.color,
                          onTap: () {
                            setState(() {
                              _selectedCourseId =
                                  _selectedCourseId == course.id
                                      ? null
                                      : course.id;
                            });
                            if (_selectedCourseId != null) {
                              ref.invalidate(
                                  courseNotesProvider(_selectedCourseId!));
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              },
              error: (_, __) => const SizedBox.shrink(),
              loading: () => const LinearProgressIndicator(),
            ),

            // Notes List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: M3ShapeChangingProgressIndicator(
                        size: 38,
                        strokeWidth: 3.5,
                      ),
                    )
                  : notesAsync.when(
                      data: (notes) {
                        final filtered = _searchQuery.isEmpty
                            ? notes
                            : notes.where((n) {
                                final q = _searchQuery.toLowerCase();
                                final plain =
                                    NoteContentCodec.extractPlainText(n.content)
                                        .toLowerCase();
                                return n.title.toLowerCase().contains(q) ||
                                    plain.contains(q);
                              }).toList();

                        if (filtered.isEmpty) {
                          return EmptyScreen(
                            message: _searchQuery.isNotEmpty
                                ? 'No matching notes found.'
                                : (_selectedCourseId == null
                                    ? 'No notes yet. Tap New Note to start!'
                                    : 'No notes for this course yet.'),
                            icon: Icons.edit_note_rounded,
                          );
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final note = filtered[index];
                            Course? noteCourse;
                            if (note.courseId != null &&
                                note.courseId!.isNotEmpty) {
                              for (final c in _courses) {
                                if (c.id == note.courseId) {
                                  noteCourse = c;
                                  break;
                                }
                              }
                            }

                            return NoteCard(
                              note: note,
                              course: noteCourse,
                              onTap: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NoteEditorScreen(
                                      note: note,
                                      availableCourses: _courses,
                                    ),
                                  ),
                                );
                                if (result == true) _refreshNotes();
                              },
                              onLongPress: () => _deleteNote(note),
                              onDelete: () => _deleteNote(note),
                            );
                          },
                        );
                      },
                      error: (error, _) => Center(
                        child: Text(
                          'Error loading notes: $error',
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                      loading: () => const Center(
                        child: M3ShapeChangingProgressIndicator(
                          size: 38,
                          strokeWidth: 3.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: M3MorphingPillButton(
        selected: true,
        icon: Icons.add_rounded,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        onPressed: _createNewNote,
        label: const Text('New Note'),
      ),
    );
  }
}
