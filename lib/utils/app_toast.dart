import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Cross-platform toast helper.
///
/// Uses native [Fluttertoast] on Android/iOS and falls back to [SnackBar]
/// on desktop/web where fluttertoast has no native implementation.
class AppToast {
  AppToast._();

  static void show(
    String message, {
    BuildContext? context,
    Color? backgroundColor,
    bool longDuration = false,
  }) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: longDuration ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: backgroundColor ?? Colors.grey.shade800,
        textColor: Colors.white,
      );
      return;
    }

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: longDuration ? 4 : 2),
        ),
      );
    }
  }
}
