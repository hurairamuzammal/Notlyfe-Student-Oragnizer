import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notlyfe/models/note_style_settings.dart';

/// Material 3 Expressive rich-text formatting toolbar for Notlyfe's note editor.
///
/// Wraps [QuillSimpleToolbar] in a soft pill container with curated Google Fonts,
/// text/highlight color pickers, headings (H1–H3), lists, checklists, quotes,
/// code blocks, alignment, and undo/redo.
class NoteFormatToolbar extends StatelessWidget {
  final QuillController controller;

  const NoteFormatToolbar({
    super.key,
    required this.controller,
  });

  static Map<String, String> get _fontMenuItems => {
        for (final f in availableNoteFonts) f.displayName: f.key,
        'Default': 'Clear',
      };

  static String _toHexRgba(Color color) {
    final argb = color.toARGB32();
    final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#$hex';
  }

  Future<void> _showColorSheet(
    BuildContext context,
    QuillController ctrl,
    bool isBackground,
  ) async {
    final swatches = isBackground ? noteHighlightPalette : noteTextPalette;
    final theme = Theme.of(context);
    Color customColor = swatches.first;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBackground ? 'Highlight Color' : 'Text Color',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ctrl.formatSelection(
                        isBackground
                            ? const BackgroundAttribute(null)
                            : const ColorAttribute(null),
                      );
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.format_color_reset_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in swatches)
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        final hex = _toHexRgba(color);
                        ctrl.formatSelection(
                          isBackground
                              ? BackgroundAttribute(hex)
                              : ColorAttribute(hex),
                        );
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _showCustomColorPickerDialog(
                        context,
                        ctrl,
                        isBackground,
                        customColor,
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.colorize_rounded,
                        color: theme.colorScheme.primary,
                      ),
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

  Future<void> _showCustomColorPickerDialog(
    BuildContext context,
    QuillController ctrl,
    bool isBackground,
    Color initial,
  ) async {
    Color picked = initial;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          isBackground ? 'Custom Highlight' : 'Custom Text Color',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final hex = _toHexRgba(picked);
              ctrl.formatSelection(
                isBackground
                    ? BackgroundAttribute(hex)
                    : ColorAttribute(hex),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: QuillSimpleToolbar(
        controller: controller,
        config: QuillSimpleToolbarConfig(
          multiRowsDisplay: false,
          showAlignmentButtons: true,
          showLineHeightButton: true,
          showSubscript: true,
          showSuperscript: true,
          showInlineCode: true,
          showStrikeThrough: true,
          showListCheck: true,
          showSearchButton: true,
          showFontFamily: true,
          showFontSize: true,
          showColorButton: true,
          showBackgroundColorButton: true,
          showHeaderStyle: true,
          showCodeBlock: true,
          showQuote: true,
          showIndent: true,
          showLink: true,
          showClearFormat: true,
          color: Colors.transparent,
          sectionDividerColor: cs.outlineVariant.withValues(alpha: 0.4),
          buttonOptions: QuillSimpleToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              iconTheme: QuillIconTheme(
                iconButtonSelectedData: IconButtonData(
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                iconButtonUnselectedData: IconButtonData(
                  style: IconButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            fontFamily: QuillToolbarFontFamilyButtonOptions(
              items: _fontMenuItems,
              defaultDisplayText: 'Font',
            ),
            fontSize: const QuillToolbarFontSizeButtonOptions(
              items: {
                'Small': 'small',
                'Normal': '0',
                'Large': 'large',
                'Huge': 'huge',
                '14': '14',
                '18': '18',
                '22': '22',
                '28': '28',
              },
              defaultDisplayText: 'Size',
            ),
            color: QuillToolbarColorButtonOptions(
              customOnPressedCallback: (ctrl, isBg) =>
                  _showColorSheet(context, ctrl, isBg),
            ),
            backgroundColor: QuillToolbarColorButtonOptions(
              customOnPressedCallback: (ctrl, isBg) =>
                  _showColorSheet(context, ctrl, isBg),
            ),
          ),
        ),
      ),
    );
  }
}
