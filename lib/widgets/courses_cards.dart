import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notlyfe/data/course_icons.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/screens/course_screen.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final bool colorfulstatus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onToggleHidden;
  final bool isOffline;

  const CourseCard({
    super.key,
    required this.course,
    required this.colorfulstatus,
    required this.onDelete,
    required this.onEdit,
    this.onToggleHidden,
    this.isOffline = false,
  });

  void _showCourseOptionsSheet(BuildContext context, ThemeData theme) {
    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course editing is disabled in offline mode'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      CourseIconHelper.buildIcon(
                        course.image,
                        size: 28,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          course.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (onToggleHidden != null) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        course.is_hidden
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      course.is_hidden
                          ? 'Show Course on Home'
                          : 'Hide Course Tile',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                        'You can view or unhide it anytime in All Courses'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onToggleHidden!();
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_rounded,
                        color: theme.colorScheme.primary),
                  ),
                  title: const Text('Edit Course Tile',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Change name, icon or card color'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onEdit();
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: theme.colorScheme.error),
                  ),
                  title: Text('Delete Course',
                      style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text('Permanently remove this course'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final confirmed = await showM3ConfirmDialog(
                      context,
                      title: 'Delete Course?',
                      message:
                          'Delete "${course.title}"? Course files remain in your storage provider, but this course card will be removed.',
                      confirmLabel: 'Delete',
                      destructive: true,
                      icon: Icons.delete_outline_rounded,
                    );
                    if (confirmed) {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceWidth = MediaQuery.sizeOf(context).width;

    final isDarkCard = colorfulstatus
        ? (course.color.computeLuminance() < 0.45)
        : (theme.brightness == Brightness.dark);
    final cardContentColor = colorfulstatus
        ? (isDarkCard ? Colors.white : const Color(0xFF1E1E1E))
        : theme.colorScheme.onSurface;
    final cardIconColor = colorfulstatus
        ? (isDarkCard ? Colors.white : const Color(0xFF1E1E1E))
        : theme.colorScheme.primary.withValues(alpha: 0.85);

    return GlitterTap(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) {
              return CourseScreen(course: course);
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
      onLongPress: () => _showCourseOptionsSheet(context, theme),
      child: Card(
        color: colorfulstatus
            ? course.color.withValues(alpha: 0.82)
            : theme.colorScheme.surfaceContainerHigh,
        elevation: 2,
        shadowColor: colorfulstatus
            ? course.color.withValues(alpha: 0.35)
            : theme.colorScheme.shadow.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorfulstatus
                ? Colors.white.withValues(alpha: 0.22)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 18,
              child: Hero(
                tag: 'courseImage-${course.id}',
                child: CourseIconHelper.buildIcon(
                  course.image,
                  size: 64,
                  color: cardIconColor,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 8,
              right: 8,
              child: Hero(
                tag: 'courseTitle-${course.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    course.title,
                    style: GoogleFonts.poppins(
                      fontSize: deviceWidth > 600 ? 19 : 14,
                      fontWeight: FontWeight.w700,
                      color: cardContentColor,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
