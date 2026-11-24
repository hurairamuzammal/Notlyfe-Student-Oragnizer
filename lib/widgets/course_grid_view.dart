import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/widgets/courses_cards.dart';

class CoursesGridView extends ConsumerWidget {
  final List<Course> courses;
  final bool colorfulstatus;
  final Function(Course) onDeleteCourse;
  final Function(Course) onEditCourse;
  final Function(Course)? onToggleHidden;
  final bool isOffline;

  const CoursesGridView({
    super.key,
    required this.courses,
    required this.colorfulstatus,
    required this.onDeleteCourse,
    required this.onEditCourse,
    this.onToggleHidden,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Offline indicator
          if (isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.offline_bolt_rounded,
                        color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Offline mode: Browse downloaded files & offline notes.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.88, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 60)),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: CourseCard(
                  course: course,
                  colorfulstatus: colorfulstatus,
                  onDelete: () => onDeleteCourse(course),
                  onEdit: () => onEditCourse(course),
                  onToggleHidden: onToggleHidden != null
                      ? () => onToggleHidden!(course)
                      : null,
                  isOffline: isOffline,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
