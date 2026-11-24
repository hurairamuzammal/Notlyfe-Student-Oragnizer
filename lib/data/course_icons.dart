import 'package:flutter/material.dart';

class CourseIconOption {
  final String key;
  final String label;
  final IconData? iconData;
  final String? assetPath;

  const CourseIconOption({
    required this.key,
    required this.label,
    this.iconData,
    this.assetPath,
  });

  bool get isAsset => assetPath != null;
}

class CourseIconHelper {
  static const List<CourseIconOption> allIcons = [
    // Original 4 asset icons
    CourseIconOption(
      key: 'assets/cardImages/cn.png',
      label: 'Networks',
      assetPath: 'assets/cardImages/cn.png',
    ),
    CourseIconOption(
      key: 'assets/cardImages/db.png',
      label: 'Database',
      assetPath: 'assets/cardImages/db.png',
    ),
    CourseIconOption(
      key: 'assets/cardImages/web.png',
      label: 'Web Dev',
      assetPath: 'assets/cardImages/web.png',
    ),
    CourseIconOption(
      key: 'assets/cardImages/ds.png',
      label: 'Data Struct',
      assetPath: 'assets/cardImages/ds.png',
    ),
    // 20 Material 3 Expressive academic & course icons (Total: 24 icons)
    CourseIconOption(
      key: 'icon:code',
      label: 'Coding',
      iconData: Icons.terminal_rounded,
    ),
    CourseIconOption(
      key: 'icon:ai',
      label: 'AI & ML',
      iconData: Icons.psychology_rounded,
    ),
    CourseIconOption(
      key: 'icon:math',
      label: 'Mathematics',
      iconData: Icons.functions_rounded,
    ),
    CourseIconOption(
      key: 'icon:science',
      label: 'Chemistry',
      iconData: Icons.science_rounded,
    ),
    CourseIconOption(
      key: 'icon:physics',
      label: 'Physics',
      iconData: Icons.bolt_rounded,
    ),
    CourseIconOption(
      key: 'icon:biology',
      label: 'Biology',
      iconData: Icons.biotech_rounded,
    ),
    CourseIconOption(
      key: 'icon:cloud',
      label: 'Cloud & Ops',
      iconData: Icons.cloud_done_rounded,
    ),
    CourseIconOption(
      key: 'icon:security',
      label: 'CyberSec',
      iconData: Icons.security_rounded,
    ),
    CourseIconOption(
      key: 'icon:mobile',
      label: 'Mobile App',
      iconData: Icons.smartphone_rounded,
    ),
    CourseIconOption(
      key: 'icon:hardware',
      label: 'Hardware',
      iconData: Icons.memory_rounded,
    ),
    CourseIconOption(
      key: 'icon:robotics',
      label: 'Robotics',
      iconData: Icons.smart_toy_rounded,
    ),
    CourseIconOption(
      key: 'icon:analytics',
      label: 'Data Science',
      iconData: Icons.insights_rounded,
    ),
    CourseIconOption(
      key: 'icon:design',
      label: 'UI / Design',
      iconData: Icons.palette_rounded,
    ),
    CourseIconOption(
      key: 'icon:architecture',
      label: 'Architecture',
      iconData: Icons.architecture_rounded,
    ),
    CourseIconOption(
      key: 'icon:business',
      label: 'Business',
      iconData: Icons.business_center_rounded,
    ),
    CourseIconOption(
      key: 'icon:economics',
      label: 'Economics',
      iconData: Icons.trending_up_rounded,
    ),
    CourseIconOption(
      key: 'icon:literature',
      label: 'Literature',
      iconData: Icons.menu_book_rounded,
    ),
    CourseIconOption(
      key: 'icon:language',
      label: 'Languages',
      iconData: Icons.translate_rounded,
    ),
    CourseIconOption(
      key: 'icon:law',
      label: 'Law & Ethics',
      iconData: Icons.gavel_rounded,
    ),
    CourseIconOption(
      key: 'icon:medicine',
      label: 'Medicine',
      iconData: Icons.medical_services_rounded,
    ),
    CourseIconOption(
      key: 'icon:music',
      label: 'Music & Art',
      iconData: Icons.music_note_rounded,
    ),
    CourseIconOption(
      key: 'icon:globe',
      label: 'Geography',
      iconData: Icons.public_rounded,
    ),
  ];

  static CourseIconOption? findOptionOrNull(String key) {
    for (final option in allIcons) {
      if (option.key == key) return option;
    }
    return null;
  }

  static CourseIconOption findOption(String key) {
    return findOptionOrNull(key) ?? allIcons.first;
  }

  static Widget buildIcon(
    String imageKey, {
    double size = 48,
    Color? color,
  }) {
    final matched = findOptionOrNull(imageKey);
    if (matched != null) {
      if (matched.isAsset && matched.assetPath != null) {
        return Image.asset(
          matched.assetPath!,
          width: size,
          height: size,
          color: color,
          fit: BoxFit.contain,
        );
      }
      return Icon(
        matched.iconData ?? Icons.school_rounded,
        size: size * 0.85,
        color: color,
      );
    }

    if (imageKey.startsWith('assets/')) {
      return Image.asset(
        imageKey,
        width: size,
        height: size,
        color: color,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.school_rounded,
          size: size * 0.85,
          color: color,
        ),
      );
    }

    return Icon(
      Icons.school_rounded,
      size: size * 0.85,
      color: color,
    );
  }
}
