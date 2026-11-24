import 'package:flutter/material.dart';

class Shortcut {
  final String title;
  final IconData icon;
  final Widget route;

  Shortcut({
    required this.title,
   required this.route,
    required this.icon,
  });
}
