import 'dart:ui';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notlyfe/database/local/courses_local_database.dart';
import 'package:notlyfe/database/todo_database.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/providers/colorful_mode_provider.dart';
import 'package:notlyfe/providers/connection_status_provider.dart';
import 'package:notlyfe/screens/all_courses_screen.dart';
import 'package:notlyfe/screens/dragable_sheet.dart';
import 'package:notlyfe/screens/drawer.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/courses_sync_service.dart';
import 'package:notlyfe/utils/app_toast.dart';
import 'package:notlyfe/widgets/clock_shortcut_widget.dart';
import 'package:notlyfe/widgets/course_edit_bottom_sheet.dart';
import 'package:notlyfe/widgets/course_grid_view.dart';
import 'package:notlyfe/widgets/empty_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthServices _auth = AuthServices();
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 1.0;
  List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCourses();

      ref.listenManual(networkServiceProvider, (previous, current) {
        if (previous != current && mounted) {
          _loadCourses();
          AppToast.show(
            current ? 'You are back online' : 'You are now offline',
            context: context,
            backgroundColor:
                current ? Colors.green.shade700 : Colors.orange.shade700,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final nextOpacity = offset <= 0
        ? 1.0
        : (offset > 100 ? 0.7 : 1.0 - (offset / 100 * 0.3));
    if (nextOpacity != _appBarOpacity) {
      setState(() => _appBarOpacity = nextOpacity);
    }
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;
    try {
      final syncService = ref.read(autoSyncCoursesProvider).service;
      final userId = _auth.getCurrentUserId();

      final localDb = ref.read(coursesLocalDatabaseProvider);
      final localCourses = await localDb.getCourses(userId);

      if (mounted) {
        setState(() => _courses = localCourses);
      }

      final isConnected = ref.read(networkServiceProvider);
      if (isConnected) {
        final cloudCourses = await syncService.getCourses(userId);
        if (mounted && cloudCourses.isNotEmpty) {
          setState(() => _courses = cloudCourses);
        }
      }

      if (userId != 'local_user') {
        final retrievedTodos = await TodoDatabase().getTodos(userId);
        DraggableSheet.updateTodos(retrievedTodos);
      }
    } catch (e) {
      debugPrint('Error loading courses or todos: $e');
    }
  }

  Future<void> deleteCourse(Course course) async {
    try {
      await ref.read(autoSyncCoursesProvider).service.deleteCourse(course);
      await _loadCourses();

      if (_courses.length <= 4 && _scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        if (mounted) {
          setState(() => _appBarOpacity = 1.0);
        }
      }

      if (mounted) {
        AppToast.show('Course deleted', context: context);
      }
    } catch (e) {
      debugPrint('Error deleting course: $e');
      if (mounted) {
        AppToast.show(
          'Failed to delete course',
          context: context,
          backgroundColor: Colors.red.shade700,
        );
      }
    }
  }

  Future<void> _openAllCourses() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AllCoursesScreen()),
    );
    await _loadCourses();
  }

  Future<void> toggleCourseHidden(Course course) async {
    try {
      final localDb = ref.read(coursesLocalDatabaseProvider);
      final newHidden = !course.is_hidden;
      await localDb.setCourseHidden(course.id, newHidden);
      await _loadCourses();
      if (mounted) {
        AppToast.show(
          newHidden
              ? '"${course.title}" hidden from Home'
              : '"${course.title}" visible on Home',
          context: context,
        );
      }
    } catch (e) {
      debugPrint('Error toggling course visibility: $e');
    }
  }

  // this widget will display all the courses added (excluding hidden ones)
  Widget activeWidget() {
    return Consumer(
      builder: (context, ref, child) {
        final colorfulstatus = ref.watch(colorfulModeProvider);
        final isConnected = ref.watch(networkServiceProvider);
        final visibleCourses =
            _courses.where((c) => !c.is_hidden).toList();

        if (_courses.isEmpty) {
          return Center(
            child: EmptyScreenWidget(
              message: isConnected
                  ? "No course to display"
                  : "No offline courses available",
              imagePath: 'assets/elephant2.png',
              colorBool: true,
              imageSize: 200,
            ),
          );
        }

        if (visibleCourses.isEmpty) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_off_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All ${_courses.length} courses are hidden',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open All Courses to search or unhide tiles for your Home dashboard.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: _openAllCourses,
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text('All Courses'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return CoursesGridView(
          courses: visibleCourses,
          colorfulstatus: colorfulstatus,
          onDeleteCourse: isConnected
              ? deleteCourse
              : (_) {},
          onEditCourse: isConnected
              ? (course) => editCourseDialogBox(context, course)
              : (_) {
                  AppToast.show(
                    'Must be online to edit course tiles',
                    context: context,
                    backgroundColor: Colors.orange.shade700,
                  );
                },
          onToggleHidden: toggleCourseHidden,
          isOffline: !isConnected,
        );
      },
    );
  }

  Future<void> addCourse(Course newCourse) async {
    try {
      await ref.read(autoSyncCoursesProvider).service.createCourse(newCourse);
      await _loadCourses();
      if (mounted) {
        AppToast.show(
          'Course added successfully',
          context: context,
          backgroundColor: Colors.green.shade700,
        );
      }
    } catch (e) {
      debugPrint('Error adding course: $e');
      if (mounted) {
        AppToast.show(
          'Failed to add course',
          context: context,
          backgroundColor: Colors.red.shade700,
        );
      }
    }
  }

  Future<void> editCourse(Course updatedCourse) async {
    try {
      await ref.read(autoSyncCoursesProvider).service.updateCourse(updatedCourse);
      await _loadCourses();
      if (mounted) {
        AppToast.show(
          'Course updated successfully',
          context: context,
          backgroundColor: Colors.green.shade700,
        );
      }
    } catch (e) {
      debugPrint('Error updating course: $e');
      if (mounted) {
        AppToast.show(
          'Failed to update course',
          context: context,
          backgroundColor: Colors.red.shade700,
        );
      }
    }
  }

  void addCourseDialogBox(BuildContext context) {
    final isConnected = ref.read(networkServiceProvider);
    if (!isConnected) {
      AppToast.show(
        'You must be online to create courses',
        context: context,
        backgroundColor: Colors.orange.shade700,
        longDuration: true,
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
          );
          await addCourse(courseWithUser);
        },
      ),
    );
  }

  void editCourseDialogBox(BuildContext context, Course course) {
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
          await editCourse(courseWithUser);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isConnected = ref.watch(networkServiceProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            _scrollController.hasClients && _scrollController.offset > 0
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(color: Colors.transparent),
                    ),
                  )
                : null,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/monochrome_3.png',
              width: 24,
              height: 24,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'Notlyfe',
              style: GoogleFonts.caveat(
                fontSize: 35,
                fontWeight: FontWeight.w300,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            if (!isConnected)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.wifi_off,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
          size: 30,
        ),
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: _appBarOpacity),
        actions: [
          // Show add button with appropriate styling for offline/online mode
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              size: 30,
              color: isConnected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5),
            ),
            onPressed: () {
              if (isConnected) {
                addCourseDialogBox(context);
              } else {
                AppToast.show(
                  'You must be online to create courses',
                  context: context,
                  backgroundColor: Colors.orange.shade700,
                  longDuration: true,
                );
              }
            },
            tooltip:
                isConnected ? 'Add Course' : 'Must be online to add courses',
          ),
        ],
      ),
      drawer: DrawerScreen(),
      body: RefreshIndicator(
        onRefresh: _loadCourses,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: CustomScrollView(
                controller: _scrollController,
                physics:
                    const AlwaysScrollableScrollPhysics(), // Enable bounce effect
                slivers: [
                  // welcome widget
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      height: 115,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(35),
                          bottomRight: Radius.circular(35),
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: AnimatedTextKit(
                          displayFullTextOnTap: true,
                          repeatForever: true,
                          stopPauseOnTap: true,
                          pause:
                              const Duration(seconds: 3), // Add pause duration
                          isRepeatingAnimation: true,
                          animatedTexts: [
                            TyperAnimatedText("Welcome to Notlyfe!",
                                textStyle: GoogleFonts.roboto(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                speed: const Duration(milliseconds: 100)),
                            TyperAnimatedText("Make Notes, Save files",
                                textStyle: GoogleFonts.roboto(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                speed: const Duration(milliseconds: 100)),
                            TyperAnimatedText("ASK AI and much more!",
                                textStyle: GoogleFonts.roboto(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                speed: const Duration(milliseconds: 100)),
                            TyperAnimatedText(
                                '"An investment in knowledge pays the best interest."',
                                textStyle: GoogleFonts.patrickHand(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                speed: const Duration(milliseconds: 150),
                                textAlign: TextAlign.center),
                            TyperAnimatedText(
                                '"Education is not preparation for life; education is life itself."  ',
                                textStyle: GoogleFonts.patrickHandSc(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                textAlign: TextAlign.center,
                                speed: const Duration(milliseconds: 150)),
                            TyperAnimatedText(
                                '"Anyone who stops learning is old, whether at twenty or eighty" ',
                                textStyle: GoogleFonts.patrickHand(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                textAlign: TextAlign.center,
                                speed: const Duration(milliseconds: 150)),
                            TyperAnimatedText(
                                ' "Education costs money, but then so does ignorance" ',
                                textStyle: GoogleFonts.patrickHand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                textAlign: TextAlign.center,
                                curve: Curves.easeInOut,
                                speed: const Duration(milliseconds: 150)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // the clock and shortcuts
                  const SliverToBoxAdapter(child: ClockShortcutWidget()),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Your Courses",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                "Active enrolled study boards",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _openAllCourses,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 13,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${_courses.where((c) => !c.is_hidden).length} courses",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: activeWidget(),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 22)),
                ],
              ),
            ),
            const DraggableSheet(),
          ],
        ),
      ),
    );
  }
}
