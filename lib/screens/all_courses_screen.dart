import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/data/course_icons.dart';
import 'package:notlyfe/database/local/courses_local_database.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/providers/colorful_mode_provider.dart';
import 'package:notlyfe/providers/connection_status_provider.dart';
import 'package:notlyfe/screens/course_screen.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/courses_sync_service.dart';
import 'package:notlyfe/utils/app_toast.dart';
import 'package:notlyfe/widgets/course_edit_bottom_sheet.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

enum _CourseVisibilityFilter { all, visible, hidden }

class AllCoursesScreen extends ConsumerStatefulWidget {
  const AllCoursesScreen({super.key});

  @override
  ConsumerState<AllCoursesScreen> createState() => _AllCoursesScreenState();
}

class _AllCoursesScreenState extends ConsumerState<AllCoursesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthServices _auth = AuthServices();

  List<Course> _courses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  _CourseVisibilityFilter _filter = _CourseVisibilityFilter.all;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final userId = _auth.getCurrentUserId();
      final localDb = ref.read(coursesLocalDatabaseProvider);
      final localCourses = await localDb.getCourses(userId);
      if (mounted) {
        setState(() {
          _courses = localCourses;
          _isLoading = false;
        });
      }

      final isConnected = ref.read(networkServiceProvider);
      if (isConnected) {
        final syncService = ref.read(autoSyncCoursesProvider).service;
        final synced = await syncService.getCourses(userId);
        if (mounted && synced.isNotEmpty) {
          setState(() {
            _courses = synced;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleCourseHidden(Course course) async {
    final newHidden = !course.is_hidden;
    final localDb = ref.read(coursesLocalDatabaseProvider);
    await localDb.setCourseHidden(course.id, newHidden);
    if (!mounted) return;

    setState(() {
      final idx = _courses.indexWhere((c) => c.id == course.id);
      if (idx != -1) {
        _courses[idx] = _courses[idx].copyWith(is_hidden: newHidden);
      }
    });

    AppToast.show(
      newHidden
          ? '"${course.title}" hidden from Home screen'
          : '"${course.title}" is now visible on Home screen',
      context: context,
    );
  }

  Future<void> _showAllCourses() async {
    final localDb = ref.read(coursesLocalDatabaseProvider);
    for (final c in _courses.where((c) => c.is_hidden)) {
      await localDb.setCourseHidden(c.id, false);
    }
    await _loadCourses();
    if (mounted) {
      AppToast.show(
        'All courses are now visible on Home screen',
        context: context,
      );
    }
  }

  void _openAddCourseSheet() {
    final isConnected = ref.read(networkServiceProvider);
    if (!isConnected) {
      AppToast.show(
        'You must be online to create courses',
        context: context,
        backgroundColor: Colors.orange.shade700,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CourseEditBottomSheet(
        onSave: (newCourse) async {
          final courseWithUser = Course(
            id: newCourse.id,
            title: newCourse.title,
            color: newCourse.color,
            image: newCourse.image,
            user_id: _auth.getCurrentUserId(),
            is_synced: false,
            is_hidden: false,
          );
          await ref
              .read(autoSyncCoursesProvider)
              .service
              .createCourse(courseWithUser);
          await _loadCourses();
        },
      ),
    );
  }

  void _openEditCourseSheet(Course course) {
    final isConnected = ref.read(networkServiceProvider);
    if (!isConnected) {
      AppToast.show(
        'Must be online to edit course tiles',
        context: context,
        backgroundColor: Colors.orange.shade700,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CourseEditBottomSheet(
        course: course,
        onSave: (updated) async {
          final courseWithUser = course.copyWith(
            title: updated.title,
            color: updated.color,
            image: updated.image,
            is_synced: false,
          );
          await ref
              .read(autoSyncCoursesProvider)
              .service
              .updateCourse(courseWithUser);
          await _loadCourses();
        },
      ),
    );
  }

  Future<void> _deleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'Are you sure you want to permanently delete "${course.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(autoSyncCoursesProvider).service.deleteCourse(course);
      await _loadCourses();
    }
  }

  List<Course> get _filteredCourses {
    return _courses.where((course) {
      final matchesQuery = _searchQuery.trim().isEmpty ||
          course.title
              .toLowerCase()
              .contains(_searchQuery.trim().toLowerCase());
      if (!matchesQuery) return false;

      switch (_filter) {
        case _CourseVisibilityFilter.all:
          return true;
        case _CourseVisibilityFilter.visible:
          return !course.is_hidden;
        case _CourseVisibilityFilter.hidden:
          return course.is_hidden;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorfulMode = ref.watch(colorfulModeProvider);
    final filtered = _filteredCourses;
    final visibleCount = _courses.where((c) => !c.is_hidden).length;
    final hiddenCount = _courses.where((c) => c.is_hidden).length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Courses',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Search, open, or hide/view tiles on Home',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          if (hiddenCount > 0)
            TextButton.icon(
              onPressed: _showAllCourses,
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Unhide All'),
            ),
          IconButton(
            tooltip: 'Add Course',
            icon: const Icon(Icons.add_rounded, size: 26),
            onPressed: _openAddCourseSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Top Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search courses by title...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 21),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),

          // Filter Chips (All / Visible / Hidden)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(
                  theme: theme,
                  label: 'All (${_courses.length})',
                  selected: _filter == _CourseVisibilityFilter.all,
                  onSelected: () =>
                      setState(() => _filter = _CourseVisibilityFilter.all),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  theme: theme,
                  label: 'Visible ($visibleCount)',
                  icon: Icons.visibility_rounded,
                  selected: _filter == _CourseVisibilityFilter.visible,
                  onSelected: () =>
                      setState(() => _filter = _CourseVisibilityFilter.visible),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  theme: theme,
                  label: 'Hidden ($hiddenCount)',
                  icon: Icons.visibility_off_rounded,
                  selected: _filter == _CourseVisibilityFilter.hidden,
                  onSelected: () =>
                      setState(() => _filter = _CourseVisibilityFilter.hidden),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Courses List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: M3ShapeChangingProgressIndicator(
                      size: 36,
                      strokeWidth: 3.5,
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.school_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No courses match "$_searchQuery"'
                                    : (_filter == _CourseVisibilityFilter.hidden
                                        ? 'No hidden courses'
                                        : 'No courses found'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCourses,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final course = filtered[index];
                            return _buildCourseTile(
                              context: context,
                              theme: theme,
                              course: course,
                              colorfulMode: colorfulMode,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required ThemeData theme,
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            )
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onSelected: (_) => onSelected(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildCourseTile({
    required BuildContext context,
    required ThemeData theme,
    required Course course,
    required bool colorfulMode,
  }) {
    final isHidden = course.is_hidden;
    final accentColor =
        colorfulMode ? course.color : theme.colorScheme.primary;

    return Opacity(
      opacity: isHidden ? 0.72 : 1.0,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: isHidden
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isHidden
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.35)
                : accentColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CourseScreen(course: course),
              ),
            );
            _loadCourses();
          },
          onLongPress: () => _openEditCourseSheet(course),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Course Icon Badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: CourseIconHelper.buildIcon(
                    course.image,
                    size: 32,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 14),

                // Course Title & Visibility Status Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration:
                              isHidden ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 13,
                            color: isHidden
                                ? theme.colorScheme.outline
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isHidden ? 'Hidden on Home' : 'Visible on Home',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isHidden
                                  ? theme.colorScheme.outline
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hide / View Toggle Button
                FilledButton.tonalIcon(
                  onPressed: () => _toggleCourseHidden(course),
                  style: FilledButton.styleFrom(
                    backgroundColor: isHidden
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isHidden
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: Icon(
                    isHidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isHidden ? 'View' : 'Hide',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // More options (Edit / Delete)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditCourseSheet(course);
                    } else if (value == 'delete') {
                      _deleteCourse(course);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Edit Course'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

