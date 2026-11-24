import 'package:flutter/material.dart';
import 'package:notlyfe/models/shorcut.dart';
import 'package:notlyfe/screens/about.dart';
import 'package:notlyfe/screens/ai_chat.dart';
import 'package:notlyfe/screens/calender.dart';
import 'package:notlyfe/screens/calculate_cgpa.dart';
import 'package:notlyfe/screens/download_screen.dart';
import 'package:notlyfe/screens/notes_screen.dart';
import 'package:notlyfe/screens/profile.dart';
import 'package:notlyfe/screens/setting.dart';

var shortcuts = [
  Shortcut(
    title: "Download",
    icon: Icons.download_outlined,
    route: const DownloadsScreen(),
  ),
  Shortcut(
    title: "Notes",
    icon: Icons.notes_outlined,
    route: const NotesScreen(),
  ),
  Shortcut(
    title: "Calendar",
    icon: Icons.calendar_month_outlined,
    route: const CalenderScreen(),
  ),
  Shortcut(
    title: "CGPA Calculator",
    icon: Icons.calculate_outlined,
    route: const CalculateCgpa(),
  ),
  Shortcut(
    title: "AI",
    icon: Icons.chat_bubble_outline_outlined,
    route: const ChatPage(),
  ),
  Shortcut(
    title: "Profile",
    icon: Icons.person_3_outlined,
    route: const ProfilePage(),
  ),
  Shortcut(
    title: "Settings",
    icon: Icons.settings_outlined,
    route: const SettingScreen(),
  ),
  Shortcut(
    title: "About",
    icon: Icons.info_outline,
    route: const AboutScreen(),
  ),
];
