import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

/// Available Google Fonts options for user customization
class AppFontOption {
  final String name;
  final String displayName;
  final TextTheme Function(TextTheme)? textThemeBuilder;

  const AppFontOption({
    required this.name,
    required this.displayName,
    this.textThemeBuilder,
  });
}

final List<AppFontOption> availableAppFonts = [
  AppFontOption(
    name: 'Poppins',
    displayName: 'Poppins (Modern & Geometric)',
    textThemeBuilder: (base) => GoogleFonts.poppinsTextTheme(base),
  ),
  AppFontOption(
    name: 'Inter',
    displayName: 'Inter (Clean & Professional)',
    textThemeBuilder: (base) => GoogleFonts.interTextTheme(base),
  ),
  AppFontOption(
    name: 'Roboto',
    displayName: 'Roboto (Google Material Default)',
    textThemeBuilder: (base) => GoogleFonts.robotoTextTheme(base),
  ),
  AppFontOption(
    name: 'Outfit',
    displayName: 'Outfit (Expressive & Rounded)',
    textThemeBuilder: (base) => GoogleFonts.outfitTextTheme(base),
  ),
  AppFontOption(
    name: 'Caveat',
    displayName: 'Caveat (Casual Handwriting)',
    textThemeBuilder: (base) => GoogleFonts.caveatTextTheme(base),
  ),
  AppFontOption(
    name: 'Open Sans',
    displayName: 'Open Sans (Neutral & Readable)',
    textThemeBuilder: (base) => GoogleFonts.openSansTextTheme(base),
  ),
  AppFontOption(
    name: 'Montserrat',
    displayName: 'Montserrat (Bold & Elegant)',
    textThemeBuilder: (base) => GoogleFonts.montserratTextTheme(base),
  ),
  AppFontOption(
    name: 'Space Grotesk',
    displayName: 'Space Grotesk (Tech & Techy)',
    textThemeBuilder: (base) => GoogleFonts.spaceGroteskTextTheme(base),
  ),
];

final appFontProvider = StateProvider<String>((ref) {
  try {
    if (Hive.isBoxOpen('testBox')) {
      return Hive.box('testBox').get('selected_app_font', defaultValue: 'Poppins');
    }
  } catch (_) {}
  return 'Poppins';
});

