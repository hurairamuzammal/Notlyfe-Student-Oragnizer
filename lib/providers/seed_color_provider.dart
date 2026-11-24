// This file provides state for the app color scheme (Device Default vs Custom Seed Color)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether to use the Android 12+ Material You system wallpaper dynamic color scheme.
/// Enabled (`true`) by default as requested.
final useDeviceColorProvider = StateProvider<bool>((ref) => true);

/// Fallback / custom manual seed color when [useDeviceColorProvider] is false.
final colorSchemeProvider = StateProvider<Color>((ref) => Colors.teal);
