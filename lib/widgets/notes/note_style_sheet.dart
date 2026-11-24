import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/providers/note_style_provider.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';

/// Material 3 Expressive bottom sheet for customizing typography, spacing,
/// paper tint, and text color — with live preview and cross-platform Default Style sync.
class NoteStyleSheet extends ConsumerStatefulWidget {
  final NoteStyleSettings initialStyle;
  final ValueChanged<NoteStyleSettings>? onApplyToCurrentNote;
  final bool showApplyToCurrentNote;

  const NoteStyleSheet({
    super.key,
    required this.initialStyle,
    this.onApplyToCurrentNote,
    this.showApplyToCurrentNote = true,
  });

  @override
  ConsumerState<NoteStyleSheet> createState() => _NoteStyleSheetState();
}

class _NoteStyleSheetState extends ConsumerState<NoteStyleSheet> {
  late NoteStyleSettings _draft;
  bool _savingDefault = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialStyle;
  }

  void _updateDraft(NoteStyleSettings next) {
    setState(() => _draft = next);
    if (widget.showApplyToCurrentNote) {
      widget.onApplyToCurrentNote?.call(next);
    }
  }

  Future<void> _saveAsDefault() async {
    setState(() => _savingDefault = true);
    try {
      await ref.read(noteStyleProvider.notifier).saveDefaultStyle(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default note style saved & synced across devices.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _savingDefault = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final previewBg = _draft.paperColor ?? cs.surfaceContainerHigh;
    final previewFg = _draft.defaultTextColor ??
        (_draft.paperColor != null &&
                _draft.paperColor!.computeLuminance() < 0.4
            ? Colors.white
            : cs.onSurface);
    final fontOpt = availableNoteFonts.firstWhere(
      (f) => f.key == _draft.fontFamily,
      orElse: () => availableNoteFonts.first,
    );

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Row(
                  children: [
                    const M3IconBadge(icon: Icons.style_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Note Typography & Style',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Applies cleanly and syncs default style across platforms',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _updateDraft(NoteStyleSettings()),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Live Style Preview Card
                    AnimatedContainer(
                      duration: M3ExpressiveMotion.resolve(
                          context, M3ExpressiveMotion.standard),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: previewBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Heading Preview',
                            style: fontOpt.toTextStyle(
                              base: TextStyle(
                                fontSize: 22 * _draft.headingScale,
                                fontWeight: FontWeight.w800,
                                color: previewFg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Clean, expressive body text with customizable line height, colors, and cross-device default style sync.',
                            style: fontOpt.toTextStyle(
                              base: TextStyle(
                                fontSize: _draft.bodyFontSize,
                                height: _draft.lineHeight,
                                color: previewFg.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    const M3SectionHeader('Font Family'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in availableNoteFonts)
                          M3MorphingFilterChip(
                            label: f.displayName,
                            selected: _draft.fontFamily == f.key,
                            onTap: () =>
                                _updateDraft(_draft.copyWith(fontFamily: f.key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const M3SectionHeader('Size & Spacing'),
                    const SizedBox(height: 8),
                    M3SettingsGroupCard(
                      children: [
                        _buildSliderTile(
                          theme: theme,
                          label: 'Body Text Size',
                          valueText: '${_draft.bodyFontSize.round()} pt',
                          value: _draft.bodyFontSize,
                          min: 13,
                          max: 22,
                          divisions: 9,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(bodyFontSize: v)),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSliderTile(
                          theme: theme,
                          label: 'Line Spacing',
                          valueText: '${_draft.lineHeight.toStringAsFixed(2)}x',
                          value: _draft.lineHeight,
                          min: 1.2,
                          max: 1.9,
                          divisions: 7,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(lineHeight: v)),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSliderTile(
                          theme: theme,
                          label: 'Heading Scale',
                          valueText:
                              '${(_draft.headingScale * 100).round()}%',
                          value: _draft.headingScale,
                          min: 0.85,
                          max: 1.35,
                          divisions: 10,
                          onChanged: (v) =>
                              _updateDraft(_draft.copyWith(headingScale: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const M3SectionHeader('Paper / Canvas Tint'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final colorVal in notePaperTintPalette)
                          _buildColorCircle(
                            theme: theme,
                            color: colorVal != null
                                ? Color(colorVal)
                                : cs.surface,
                            selected: _draft.paperColorValue == colorVal,
                            label: colorVal == null ? 'Auto' : null,
                            onTap: () => _updateDraft(
                              colorVal == null
                                  ? _draft.copyWith(clearPaperColor: true)
                                  : _draft.copyWith(paperColorValue: colorVal),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const M3SectionHeader('Default Text Color'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _buildColorCircle(
                          theme: theme,
                          color: cs.onSurface,
                          selected: _draft.defaultTextColorValue == null,
                          label: 'Auto',
                          onTap: () => _updateDraft(
                            _draft.copyWith(clearTextColor: true),
                          ),
                        ),
                        for (final c in noteTextPalette)
                          _buildColorCircle(
                            theme: theme,
                            color: c,
                            selected:
                                _draft.defaultTextColorValue == c.toARGB32(),
                            onTap: () => _updateDraft(
                              _draft.copyWith(
                                  defaultTextColorValue: c.toARGB32()),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: M3MorphingPillButton(
                    selected: true,
                    icon: Icons.cloud_done_rounded,
                    onPressed: _savingDefault ? null : _saveAsDefault,
                    label: Text(
                      _savingDefault
                          ? 'Saving Default Style...'
                          : 'Save as Default Style (Sync)',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required ThemeData theme,
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                valueText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle({
    required ThemeData theme,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    String? label,
  }) {
    final cs = theme.colorScheme;
    final radius = selected ? 14.0 : 22.0;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: M3ExpressiveMotion.resolve(context, M3ExpressiveMotion.fast),
        width: label != null ? 58 : 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: label != null ? cs.surfaceContainerHigh : color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 2.5 : 1.2,
          ),
        ),
        child: label != null
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              )
            : (selected
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: color.computeLuminance() < 0.45
                        ? Colors.white
                        : Colors.black,
                  )
                : null),
      ),
    );
  }
}
