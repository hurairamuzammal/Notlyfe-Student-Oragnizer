import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:notlyfe/providers/app_font_provider.dart';

class FontSettingsScreen extends ConsumerStatefulWidget {
  const FontSettingsScreen({super.key});

  @override
  ConsumerState<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends ConsumerState<FontSettingsScreen> {
  late String _selectedFont;

  @override
  void initState() {
    super.initState();
    _selectedFont = ref.read(appFontProvider);
  }

  void _applyFont(String fontName) {
    setState(() {
      _selectedFont = fontName;
    });
    ref.read(appFontProvider.notifier).state = fontName;
    try {
      if (Hive.isBoxOpen('testBox')) {
        Hive.box('testBox').put('selected_app_font', fontName);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeFontOption = availableAppFonts.firstWhere(
      (f) => f.name == _selectedFont,
      orElse: () => availableAppFonts.first,
    );

    // Apply the active preview font to text theme
    final previewTextTheme = activeFontOption.textThemeBuilder != null
        ? activeFontOption.textThemeBuilder!(theme.textTheme)
        : theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'App Typography & Fonts',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // UPPER PART OF SCREEN: Live Interactive Preview of Heading, Body, Subtitle & Buttons
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28), // M3 expressive extra-large radius
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LIVE PREVIEW',
                        style: previewTextTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      _selectedFont,
                      style: previewTextTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Large Heading preview
                Text(
                  'Explore Ideas & Notes',
                  style: previewTextTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle preview
                Text(
                  'Organize courses, tasks, and schedules seamlessly.',
                  style: previewTextTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // Body preview
                Text(
                  'Material 3 Expressive brings dynamic geometry, fluid stretch scrolling, and bold typography alive across all screens.',
                  style: previewTextTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons preview
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text('Primary Action', style: previewTextTheme.labelLarge),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {},
                      child: Text('Secondary', style: previewTextTheme.labelLarge),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.text_fields_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Select App Font',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Lower part: Font selection list with stretch physics
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: availableAppFonts.length,
              itemBuilder: (context, index) {
                final font = availableAppFonts[index];
                final isSelected = font.name == _selectedFont;

                // Create font specific text style for preview in list tile
                final fontTextTheme = font.textThemeBuilder != null
                    ? font.textThemeBuilder!(theme.textTheme)
                    : theme.textTheme;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isSelected ? 24 : 16),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    onTap: () => _applyFont(font.name),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      child: Text(
                        'Aa',
                        style: fontTextTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? theme.colorScheme.onPrimary : null,
                        ),
                      ),
                    ),
                    title: Text(
                      font.displayName,
                      style: fontTextTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    subtitle: Text(
                      'The quick brown fox jumps over the lazy dog',
                      style: fontTextTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 26)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

