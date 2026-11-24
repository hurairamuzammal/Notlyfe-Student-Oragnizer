import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/data/course_icons.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/providers/courses_provider.dart';
import 'package:notlyfe/providers/note_style_provider.dart';
import 'package:notlyfe/providers/notes_sync_provider.dart';
import 'package:notlyfe/utils/note_content_codec.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:notlyfe/widgets/notes/note_format_toolbar.dart';
import 'package:notlyfe/widgets/notes/note_style_sheet.dart';
import 'package:uuid/uuid.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note note;
  final List<Course> availableCourses;
  final bool isNewNote;

  const NoteEditorScreen({
    super.key,
    required this.note,
    required this.availableCourses,
    this.isNewNote = false,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  StreamSubscription<DocChange>? _documentChangesSub;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  late Note _note;
  late bool _isEditing;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _didReturnSave = false;
  NoteStyleSettings? _perNoteStyle;
  List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _courses = widget.availableCourses;

    if (widget.isNewNote && _note.id.isEmpty) {
      _note = _note.copyWith(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    _titleController = TextEditingController(text: _note.title);
    final decoded = NoteContentCodec.decode(_note.content);
    _perNoteStyle = decoded.noteStyle;
    _quillController = QuillController(
      document: decoded.document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _isEditing = widget.isNewNote;
    _quillController.readOnly = !_isEditing;
    _documentChangesSub = _quillController.document.changes.listen((_) {
      if (mounted && !_hasChanges) {
        setState(() => _hasChanges = true);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _documentChangesSub?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  NoteStyleSettings _readEffectiveStyle() =>
      _perNoteStyle ?? ref.read(noteStyleProvider);

  Future<void> _handlePopAttempt(bool didPop) async {
    if (didPop) return;
    if (!_hasChanges) {
      if (mounted) Navigator.of(context).pop(_didReturnSave);
      return;
    }

    final discard = await showM3ConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved edits in this note.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (discard && mounted) {
      Navigator.of(context).pop(_didReturnSave);
    }
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final syncService = ref.read(autoSyncNotesProvider).service;
      final encodedContent = NoteContentCodec.encode(
        _quillController.document,
        perNoteStyle: _perNoteStyle,
      );

      final updatedNote = _note.copyWith(
        title: _titleController.text.trim(),
        content: encodedContent,
        updatedAt: DateTime.now(),
      );

      if (widget.isNewNote && !_didReturnSave) {
        await syncService.createNote(updatedNote);
      } else {
        await syncService.updateNote(updatedNote);
      }

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _quillController.readOnly = true;
        _hasChanges = false;
        _didReturnSave = true;
        _note = updatedNote;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isNewNote ? 'Note saved & encrypted!' : 'Note updated!'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _quillController.readOnly = !_isEditing;
    });
    if (_isEditing) {
      _editorFocusNode.requestFocus();
    }
  }

  void _showStyleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteStyleSheet(
        initialStyle: _readEffectiveStyle(),
        onApplyToCurrentNote: (nextStyle) {
          setState(() {
            _perNoteStyle = nextStyle;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  void _showCourseSelectionDialog() {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No courses available. Create a course first.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Assign Course',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(ctx).height * 0.5,
          child: ListView.builder(
            itemCount: _courses.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('No Course'),
                  selected: _note.courseId == null,
                  onTap: () {
                    setState(() {
                      _note = _note.copyWith(clearCourseId: true);
                      _hasChanges = true;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }
              final course = _courses[index - 1];
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: CourseIconHelper.buildIcon(
                  course.image,
                  size: 24,
                  color: course.color,
                ),
                title: Text(course.title),
                selected: _note.courseId == course.id,
                onTap: () {
                  setState(() {
                    _note = _note.copyWith(courseId: course.id);
                    _hasChanges = true;
                  });
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showE2eeInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Row(
          children: [
            M3IconBadge(icon: Icons.lock_outline_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'End-to-End Encrypted',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your note title, rich formatting, and text styles are encrypted on-device with AES-256 + HMAC-SHA256 before syncing to Supabase, Google Drive, WebDAV, or any custom storage backend.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  DefaultStyles _buildEditorStyles(
    BuildContext context,
    NoteStyleSettings style,
    Color textColor,
  ) {
    final base = DefaultStyles.getInstance(context);
    final font = resolveNoteFontStyle(style.fontFamily);
    final cs = Theme.of(context).colorScheme;

    TextStyle apply(TextStyle? orig, {double? fontSize, FontWeight? weight}) {
      return (orig ?? const TextStyle())
          .merge(font)
          .copyWith(
            fontSize: fontSize,
            height: style.lineHeight,
            fontWeight: weight,
            color: textColor,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          );
    }

    return DefaultStyles(
      h1: base.h1?.copyWith(
        style: apply(
          base.h1?.style,
          fontSize: 28 * style.headingScale,
          weight: FontWeight.w800,
        ),
      ),
      h2: base.h2?.copyWith(
        style: apply(
          base.h2?.style,
          fontSize: 23 * style.headingScale,
          weight: FontWeight.w700,
        ),
      ),
      h3: base.h3?.copyWith(
        style: apply(
          base.h3?.style,
          fontSize: 19 * style.headingScale,
          weight: FontWeight.w700,
        ),
      ),
      h4: base.h4?.copyWith(
        style: apply(
          base.h4?.style,
          fontSize: 17 * style.headingScale,
          weight: FontWeight.w700,
        ),
      ),
      paragraph: base.paragraph?.copyWith(
        style: apply(base.paragraph?.style, fontSize: style.bodyFontSize),
      ),
      quote: DefaultTextBlockStyle(
        apply(
          base.quote?.style,
          fontSize: style.bodyFontSize,
        ).copyWith(
          color: textColor.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
        ),
        base.quote!.horizontalSpacing,
        base.quote!.verticalSpacing,
        base.quote!.lineSpacing,
        BoxDecoration(
          border: Border(
            left: BorderSide(color: cs.primary, width: 4),
          ),
        ),
      ),
      lists: base.lists?.copyWith(
        style: apply(base.lists?.style, fontSize: style.bodyFontSize),
      ),
      bold: base.bold,
      italic: base.italic,
      underline: base.underline,
      strikeThrough: base.strikeThrough,
      subscript: base.subscript,
      superscript: base.superscript,
      inlineCode: base.inlineCode,
      code: base.code?.copyWith(
        style: (base.code?.style ?? const TextStyle()).copyWith(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
      ),
      link: base.link?.copyWith(color: cs.primary),
      color: textColor,
      placeHolder: base.placeHolder?.copyWith(
        style: apply(
          base.placeHolder?.style,
          fontSize: style.bodyFontSize,
        ).copyWith(color: textColor.withValues(alpha: 0.42)),
      ),
      lineHeightNormal: base.lineHeightNormal,
      lineHeightTight: base.lineHeightTight,
      lineHeightOneAndHalf: base.lineHeightOneAndHalf,
      lineHeightDouble: base.lineHeightDouble,
      sizeSmall: base.sizeSmall,
      sizeLarge: base.sizeLarge,
      sizeHuge: base.sizeHuge,
      indent: base.indent,
      align: base.align,
      leading: base.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    coursesAsync.whenData((courses) {
      if (courses.isNotEmpty && _courses.isEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _courses = courses);
        });
      }
    });

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final defaultStyle = ref.watch(noteStyleProvider);
    final style = _perNoteStyle ?? defaultStyle;
    final paperColor = style.paperColor ?? cs.surfaceContainerLowest;
    final isDarkPaper = style.paperColor != null
        ? style.paperColor!.computeLuminance() < 0.4
        : theme.brightness == Brightness.dark;
    final effectiveTextColor = style.defaultTextColor ??
        (style.paperColor != null
            ? (isDarkPaper ? Colors.white : const Color(0xFF1C1B1F))
            : cs.onSurface);

    final plainText = _quillController.document.toPlainText().trim();
    final wordCount = plainText.isEmpty
        ? 0
        : plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    Course? selectedCourse;
    if (_note.courseId != null && _note.courseId!.isNotEmpty) {
      for (final c in _courses) {
        if (c.id == _note.courseId) {
          selectedCourse = c;
          break;
        }
      }
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) => _handlePopAttempt(didPop),
      child: Scaffold(
        backgroundColor: paperColor,
        appBar: AppBar(
          toolbarHeight: 48,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          foregroundColor: effectiveTextColor,
          titleSpacing: 0,
          title: Text(
            _isEditing ? 'Edit Note' : 'Note',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: effectiveTextColor.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _isEditing
                  ? M3MorphingPillButton(
                      selected: true,
                      icon: _isSaving ? null : Icons.check_rounded,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      onPressed: _isSaving ? null : _saveNote,
                      label: _isSaving
                          ? const M3ShapeChangingProgressIndicator(
                              size: 15,
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text('Save'),
                    )
                  : M3MorphingPillButton(
                      tonal: true,
                      icon: Icons.edit_rounded,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      onPressed: _toggleEditMode,
                      label: const Text('Edit'),
                    ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: effectiveTextColor),
              onSelected: (value) async {
                if (value == 'style') {
                  _showStyleSheet();
                } else if (value == 'course') {
                  _showCourseSelectionDialog();
                } else if (value == 'e2ee') {
                  _showE2eeInfoDialog();
                } else if (value == 'copy') {
                  final messenger = ScaffoldMessenger.of(context);
                  final text =
                      '${_titleController.text.trim()}\n\n$plainText'.trim();
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Note copied to clipboard')),
                    );
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'style',
                  child: Row(
                    children: [
                      Icon(Icons.style_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Typography & Style'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'course',
                  child: Row(
                    children: [
                      Icon(Icons.book_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Assign Course'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_all_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Copy plain text'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'e2ee',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Encryption Info'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Title + optional assigned Course pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditing)
                    TextField(
                      controller: _titleController,
                      style: resolveNoteFontStyle(style.fontFamily).copyWith(
                        fontSize: 20 * style.headingScale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: effectiveTextColor,
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Untitled Note',
                        hintStyle: TextStyle(
                          color: effectiveTextColor.withValues(alpha: 0.4),
                          decoration: TextDecoration.none,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                    )
                  else
                    Text(
                      _note.title.isEmpty ? 'Untitled Note' : _note.title,
                      style: resolveNoteFontStyle(style.fontFamily).copyWith(
                        fontSize: 20 * style.headingScale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: effectiveTextColor,
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                    ),
                  if (selectedCourse != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: selectedCourse.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CourseIconHelper.buildIcon(
                            selectedCourse.image,
                            size: 13,
                            color: selectedCourse.color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            selectedCourse.title,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: effectiveTextColor,
                            ),
                          ),
                          if (_isEditing) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() {
                                _note = _note.copyWith(clearCourseId: true);
                                _hasChanges = true;
                              }),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: effectiveTextColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Animated Rich Text Formatting Toolbar
            AnimatedSwitcher(
              duration: M3ExpressiveMotion.resolve(
                  context, M3ExpressiveMotion.standard),
              switchInCurve: M3ExpressiveMotion.emphasized,
              child: _isEditing
                  ? NoteFormatToolbar(controller: _quillController)
                  : const SizedBox.shrink(),
            ),

            // Quill Rich Text Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 2, 10, 4),
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                decoration: BoxDecoration(
                  color: style.paperColor != null
                      ? style.paperColor!.withValues(alpha: 0.92)
                      : cs.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: DefaultTextStyle(
                    style: resolveNoteFontStyle(style.fontFamily).copyWith(
                      fontSize: style.bodyFontSize,
                      height: style.lineHeight,
                      color: effectiveTextColor,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                    ),
                    child: QuillEditor(
                      controller: _quillController,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: QuillEditorConfig(
                        scrollable: true,
                        expands: true,
                        placeholder: _isEditing
                            ? 'Write your note, add headings, colors, highlights, checklists...'
                            : 'Empty note — tap Edit to start writing.',
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        customStyles: _buildEditorStyles(
                            context, style, effectiveTextColor),
                        customStyleBuilder: (attr) {
                          if (attr.key == Attribute.font.key &&
                              attr.value != null) {
                            return resolveNoteFontStyle(attr.value.toString());
                          }
                          return const TextStyle();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Status Pill (Word Count, Font, Sync state)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$wordCount words • ${style.fontFamily} ${style.bodyFontSize.round()}pt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: effectiveTextColor.withValues(alpha: 0.65),
                    ),
                  ),
                  AnimatedContainer(
                    duration: M3ExpressiveMotion.resolve(
                        context, M3ExpressiveMotion.fast),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasChanges
                          ? cs.tertiaryContainer
                          : cs.secondaryContainer,
                      borderRadius:
                          BorderRadius.circular(_hasChanges ? 12 : 20),
                    ),
                    child: Text(
                      _hasChanges ? 'Unsaved changes' : 'Saved',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _hasChanges
                            ? cs.onTertiaryContainer
                            : cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
