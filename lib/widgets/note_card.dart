import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notlyfe/data/course_icons.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/utils/note_content_codec.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final Course? course;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.course,
    this.onLongPress,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final formattedDate =
        DateFormat('MMM d, yyyy • h:mm a').format(note.updatedAt);

    final plainPreview = NoteContentCodec.extractPlainText(note.content);
    final perNoteStyle = NoteContentCodec.extractPerNoteStyle(note.content);
    final checklist = NoteContentCodec.extractChecklistStats(note.content);

    final cardBg = perNoteStyle?.paperColor ?? cs.surfaceContainerHigh;
    final isDarkCard = perNoteStyle?.paperColor != null
        ? perNoteStyle!.paperColor!.computeLuminance() < 0.4
        : theme.brightness == Brightness.dark;
    final titleColor = perNoteStyle?.paperColor != null
        ? (isDarkCard ? Colors.white : const Color(0xFF1C1B1F))
        : cs.onSurface;
    final subtitleColor = titleColor.withValues(alpha: 0.72);
    final fontStyle = perNoteStyle != null
        ? resolveNoteFontStyle(perNoteStyle.fontFamily)
        : const TextStyle();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: GlitterTap(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Untitled Note' : note.title,
                        style: fontStyle.copyWith(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!note.isSynced)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message: 'Pending sync',
                          child: Icon(
                            Icons.cloud_off_rounded,
                            size: 16,
                            color: cs.error,
                          ),
                        ),
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: cs.error,
                        ),
                        onPressed: onDelete,
                        tooltip: 'Delete Note',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                if (plainPreview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    plainPreview,
                    style: fontStyle.copyWith(
                      fontSize: 13.5,
                      height: 1.4,
                      color: subtitleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (checklist.hasChecklists) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.checklist_rounded,
                                  size: 13,
                                  color: cs.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${checklist.checked}/${checklist.total}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (course != null && course!.id.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: course!.color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CourseIconHelper.buildIcon(
                                  course!.image,
                                  size: 14,
                                  color: course!.color,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  course!.title,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: course!.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
