import 'package:flutter/material.dart';

final allowedcolors = [
  Colors.red,
  Colors.blue,
  Colors.teal,
  Colors.orange,
  Colors.green,
  Colors.pink,
  Colors.blueGrey,
  Colors.amber,
  Colors.cyan,
];

extension ColorExtension on Color {
  Color darker({double factor = 0.7}) {
    return Color.fromARGB(
      (a * 255).round(),
      ((r * 255) * factor).round(),
      ((g * 255) * factor).round(),
      ((b * 255) * factor).round(),
    );
  }
}
