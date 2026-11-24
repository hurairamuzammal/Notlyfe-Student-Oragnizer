import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:notlyfe/database/user_profile_database.dart';
import 'package:notlyfe/providers/app_font_provider.dart';
import 'package:notlyfe/providers/colorful_mode_provider.dart';
import 'package:notlyfe/providers/login_user_provider.dart';
import 'package:notlyfe/providers/seed_color_provider.dart';
import 'package:notlyfe/services/app_version_service.dart';
import 'package:notlyfe/services/auth_gate.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/services/notification_service.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ldnlbuextqhnslzephpu.supabase.co',
);

const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkbmxidWV4dHFobnNsemVwaHB1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5NTM4NzEsImV4cCI6MjEwNzUyOTg3MX0.6ET6oBSNWGqKc5rIFGkTOzv1vpGV2d_EP6d-hD2mSGk',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite requires FFI initialization before any local database call.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      headers: AppVersionService.clientHeaders,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  try {
    await Hive.initFlutter();
    await Hive.openBox('testBox');
  } catch (e) {
    debugPrint('Hive init error: $e');
  }

  try {
    await E2eeService.instance.initialize();
  } catch (e) {
    debugPrint('E2EE init error: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification init notice: $e');
  }

  try {
    await StorageBackendRegistry.instance.initialize();
    await GoogleDriveStorageService.instance.ensureInitialized();
  } catch (e) {
    debugPrint('Storage init notice: $e');
  }

  final container = ProviderContainer();

  try {
    if (Hive.isBoxOpen('testBox')) {
      final box = Hive.box('testBox');
      final colorValue = box.get('selectedColor');
      if (colorValue is int) {
        container.read(colorSchemeProvider.notifier).state = Color(colorValue);
      }
      final useDeviceColor = box.get('useDeviceColor');
      container.read(useDeviceColorProvider.notifier).state =
          useDeviceColor is bool ? useDeviceColor : true;
      final colorful = box.get('colorfulMode');
      if (colorful is bool) {
        container.read(colorfulModeProvider.notifier).state = colorful;
      }
    }
  } catch (e) {
    debugPrint('Preferences load error: $e');
  }

  Future.delayed(const Duration(seconds: 2), () {
    try {
      initializeDateFormatting();
    } catch (_) {}
  });

  _fetchAndSetUserName(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedColor = ref.watch(colorSchemeProvider);
    final useDeviceColor = ref.watch(useDeviceColorProvider);
    final fontName = ref.watch(appFontProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Notlyfe',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
          ),
          theme: _buildTheme(
            seedColor,
            Brightness.light,
            fontName,
            dynamicScheme: useDeviceColor ? lightDynamic : null,
          ),
          darkTheme: _buildTheme(
            seedColor,
            Brightness.dark,
            fontName,
            dynamicScheme: useDeviceColor ? darkDynamic : null,
          ),
          themeMode: ThemeMode.system,
          supportedLocales: const [
            Locale('en', ''),
            Locale('ar', ''),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          home: const AuthGate(),
        );
      },
    );
  }

  ThemeData _buildTheme(
    Color seedColor,
    Brightness brightness,
    String fontName, {
    ColorScheme? dynamicScheme,
  }) {
    final effectiveScheme = dynamicScheme != null
        ? dynamicScheme.harmonized()
        : ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: brightness,
          );

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: effectiveScheme,
      brightness: brightness,
      splashFactory: InkSparkle.splashFactory,
    );

    final fontOption = availableAppFonts.firstWhere(
      (f) => f.name == fontName,
      orElse: () => availableAppFonts.first,
    );

    final builtTextTheme = fontOption.textThemeBuilder != null
        ? fontOption.textThemeBuilder!(baseTheme.textTheme)
        : baseTheme.textTheme;

    final textTheme = builtTextTheme.copyWith(
      headlineLarge: builtTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: builtTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineSmall: builtTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: builtTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: builtTextTheme.titleMedium?.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      titleSmall: builtTextTheme.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: baseTheme.colorScheme.onSurfaceVariant,
      ),
      bodyLarge: builtTextTheme.bodyLarge?.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: builtTextTheme.bodyMedium?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: baseTheme.colorScheme.onSurfaceVariant,
      ),
      bodySmall: builtTextTheme.bodySmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      labelLarge: builtTextTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelMedium: builtTextTheme.labelMedium?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: baseTheme.colorScheme.onSurfaceVariant,
      ),
      labelSmall: builtTextTheme.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
    );

    return baseTheme.copyWith(
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          splashFactory: InkSparkle.splashFactory,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          splashFactory: InkSparkle.splashFactory,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          splashFactory: InkSparkle.splashFactory,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: InkSparkle.splashFactory,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      listTileTheme: const ListTileThemeData(dense: true),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          splashFactory: InkSparkle.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.check_rounded, size: 16);
          }
          return const Icon(Icons.close_rounded, size: 16);
        }),
      ),
    );
  }
}

Future<void> _fetchAndSetUserName(ProviderContainer container) async {
  try {
    final userId = AuthServices().getCurrentUserId();
    if (userId.isEmpty) return;

    final name = await UserProfileDatabase().getUserName(userId);
    if (name.isNotEmpty) {
      container.read(userNameProvider.notifier).state = name;
    }
  } catch (_) {}
}
