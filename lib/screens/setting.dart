import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:notlyfe/providers/colorful_mode_provider.dart';
import 'package:notlyfe/providers/login_user_provider.dart';
import 'package:notlyfe/providers/seed_color_provider.dart';
import 'package:notlyfe/providers/note_style_provider.dart';
import 'package:notlyfe/screens/about.dart';
import 'package:notlyfe/screens/ai_settings_screen.dart';
import 'package:notlyfe/screens/device_settings_screen.dart';
import 'package:notlyfe/screens/font_settings_screen.dart';
import 'package:notlyfe/screens/profile.dart';
import 'package:notlyfe/screens/storage_settings_screen.dart';
import 'package:notlyfe/screens/user_agreement_screen.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/services/notification_service.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:notlyfe/widgets/notes/note_style_sheet.dart';

class SettingScreen extends ConsumerStatefulWidget {
  const SettingScreen({super.key});

  @override
  ConsumerState<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends ConsumerState<SettingScreen>
    with WidgetsBindingObserver {
  var switchValue = true;

  final AuthServices _authServices = AuthServices();
  bool _isGoogleLinked = false;
  String? _googleEmail;
  bool _isLoadingGoogle = false;
  bool _isCheckingGoogle = true;

  bool _isDriveConnected = false;
  String? _driveEmail;
  bool _isLoadingDrive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationPref();
    _checkGoogleStatus();
  }

  Future<void> _loadNotificationPref() async {
    final enabled = await NotificationService.instance.isEnabled();
    if (mounted) setState(() => switchValue = enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGoogleStatus();
    }
  }

  Future<void> _checkGoogleStatus() async {
    try {
      final isLinked = await _authServices.isGoogleLinked();
      String? email;
      if (isLinked) {
        email = await _authServices.getGoogleLinkedEmail();
      }
      final driveConnected =
          await GoogleDriveStorageService.instance.isDriveConnected();
      final driveEmail =
          await GoogleDriveStorageService.instance.getConnectedEmail();
      if (mounted) {
        setState(() {
          _isGoogleLinked = isLinked;
          _googleEmail = email;
          _isDriveConnected = driveConnected;
          _driveEmail = driveEmail;
          _isCheckingGoogle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingGoogle = false;
        });
      }
    }
  }

  Future<void> _handleConnectDrive() async {
    setState(() {
      _isLoadingDrive = true;
    });
    try {
      final error =
          await GoogleDriveStorageService.instance.connectDrive();
      if (!mounted) return;
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Google Drive connected! Files will be saved in your dedicated Notlyfe folder.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not connect Google Drive: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDrive = false;
        });
        _checkGoogleStatus();
      }
    }
  }

  Future<void> _handleDisconnectDrive() async {
    final confirmed = await showM3ConfirmDialog(
      context,
      title: 'Disconnect Google Drive',
      message:
          'Disconnect Google Drive from Notlyfe? Your files inside Drive will remain untouched.',
      confirmLabel: 'Disconnect',
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isLoadingDrive = true;
    });
    try {
      await GoogleDriveStorageService.instance.disconnectDrive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Drive folder access disconnected.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to disconnect Google Drive.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDrive = false;
        });
        _checkGoogleStatus();
      }
    }
  }

  Future<void> _handleLinkGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
    });

    try {
      final error = await _authServices.linkGoogleAccount();
      if (!mounted) return;

      if (error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Google authentication to link account...'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
        _checkGoogleStatus();
      }
    }
  }

  Future<void> _handleUnlinkGoogle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Google Account'),
        content: const Text(
          'Are you sure you want to unlink your Google account? You will no longer be able to log in using Google unless you link it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isLoadingGoogle = true;
    });

    try {
      final error = await _authServices.unlinkGoogleAccount();
      if (!mounted) return;

      if (error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account unlinked successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        await _checkGoogleStatus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = ref.watch(colorSchemeProvider);
    final bool useDeviceColor = ref.watch(useDeviceColorProvider);
    final theme = Theme.of(context);
    final colorfulMode = ref.watch(colorfulModeProvider);
    final userName = ref.watch(userNameProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Profile Hero Card (Google Material You Style)
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.75),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        (userName.isNotEmpty ? userName[0] : 'U').toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.isNotEmpty ? userName : 'My Profile',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Change display name, password & account security',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // SECTION 1: Appearance & Alerts
          _buildSectionHeader(theme, 'Appearance & Alerts'),
          const SizedBox(height: 8),
          _buildSettingsGroup(
            theme,
            [
              SwitchListTile(
                value: colorfulMode,
                onChanged: (value) {
                  ref.read(colorfulModeProvider.notifier).state = value;
                  if (Hive.isBoxOpen('testBox')) {
                    Hive.box('testBox').put('colorfulMode', value);
                  }
                },
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.palette_rounded, size: 16);
                  }
                  return const Icon(Icons.close_rounded, size: 16);
                }),
                secondary: _buildIconBadge(theme, Icons.color_lens_rounded),
                title: const Text('Colorful Cards', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Divider(indent: 58, height: 1),
              SwitchListTile(
                value: switchValue,
                onChanged: (value) async {
                  setState(() => switchValue = value);
                  await NotificationService.instance.setEnabled(value);
                },
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.notifications_active_rounded, size: 16);
                  }
                  return const Icon(Icons.notifications_off_rounded, size: 16);
                }),
                secondary: _buildIconBadge(theme, Icons.notifications_rounded),
                title: const Text('Push Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.notification_important_outlined),
                title: const Text('Test Alert', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    final sent =
                        await NotificationService.instance.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? 'Test alert sent.'
                                : 'Local alerts are not supported on this platform.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Test'),
                ),
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.palette_outlined),
                title: const Text('Color Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: useDeviceColor
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wallpaper_rounded,
                              size: 15,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Device',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: createMaterialColor(selectedColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                onTap: () => _showColorPicker(context, ref),
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.font_download_outlined),
                title: const Text('Fonts', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FontSettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.style_rounded),
                title: const Text('Note Style', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final style = ref.watch(noteStyleProvider);
                    return Text('${style.fontFamily} · ${style.bodyFontSize.round()}pt');
                  },
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  final current = ref.read(noteStyleProvider);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => NoteStyleSheet(
                      initialStyle: current,
                      showApplyToCurrentNote: false,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SECTION 2: Storage & Sync
          const M3SectionHeader('Storage & Sync'),
          const SizedBox(height: 8),
          M3SettingsGroupCard(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final registry = ref.watch(storageRegistryProvider);
                  return ListTile(
                    leading: const M3IconBadge(icon: Icons.hub_rounded),
                    title: const Text(
                      'Storage Locations',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${registry.activeFileProvider.displayName} · ${registry.activeNotesProvider.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StorageSettingsScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SECTION 3: AI, Devices & Security
          _buildSectionHeader(theme, 'AI & Security'),
          const SizedBox(height: 8),
          _buildSettingsGroup(
            theme,
            [
              ListTile(
                leading: _buildIconBadge(theme, Icons.auto_awesome_rounded),
                title: const Text('AI Providers', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AiSettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.devices_rounded),
                title: const Text('Primary Device', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const DeviceSettingsScreen()),
                  );
                },
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.shield_outlined),
                title: const Text('Encryption', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'E2EE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimaryContainer,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                onTap: () => _showE2eeSecurityDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SECTION 4: Accounts
          _buildSectionHeader(theme, 'Accounts'),
          const SizedBox(height: 8),
          _buildSettingsGroup(
            theme,
            [
              ListTile(
                leading: _buildIconBadge(theme, Icons.g_mobiledata_rounded),
                title: const Text('Google Account', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _isGoogleLinked && _googleEmail != null
                    ? Text(
                        _googleEmail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: _isCheckingGoogle
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: M3ShapeChangingProgressIndicator(size: 18, strokeWidth: 2),
                      )
                    : _isGoogleLinked
                        ? TextButton(
                            onPressed: _isLoadingGoogle ? null : _handleUnlinkGoogle,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('Unlink'),
                          )
                        : FilledButton.tonal(
                            onPressed: _isLoadingGoogle ? null : _handleLinkGoogle,
                            child: Text(_isLoadingGoogle ? '...' : 'Link'),
                          ),
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.add_to_drive_rounded),
                title: const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _isDriveConnected
                    ? Text(
                        _driveEmail != null && _driveEmail!.isNotEmpty
                            ? 'Notlyfe · $_driveEmail'
                            : 'Notlyfe/<Course>',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: _isDriveConnected
                    ? TextButton(
                        onPressed: _isLoadingDrive ? null : _handleDisconnectDrive,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        child: const Text('Disconnect'),
                      )
                    : FilledButton.tonal(
                        onPressed: _isLoadingDrive ? null : _handleConnectDrive,
                        child: Text(_isLoadingDrive ? '...' : 'Connect'),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SECTION 5: About
          _buildSectionHeader(theme, 'About'),
          const SizedBox(height: 8),
          _buildSettingsGroup(
            theme,
            [
              ListTile(
                leading: _buildIconBadge(theme, Icons.info_outline_rounded),
                title: const Text('Developer & App', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'v${AboutScreen.appVersion}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
              ),
              const Divider(indent: 58, height: 1),
              ListTile(
                leading: _buildIconBadge(theme, Icons.gavel_rounded),
                title: const Text('User Agreement', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UserAgreementScreen(isMandatory: false)),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) =>
      M3SectionHeader(title);

  Widget _buildSettingsGroup(ThemeData theme, List<Widget> children) =>
      M3SettingsGroupCard(children: children);

  Widget _buildIconBadge(ThemeData theme, IconData icon) =>
      M3IconBadge(icon: icon);

  void _showE2eeSecurityDialog(BuildContext context) {
    final theme = Theme.of(context);
    final keyFingerprint = E2eeService.instance.getVaultKeyFingerprint();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Zero-Knowledge Vault',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Algorithm: AES-256-CBC + HMAC-SHA256',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Key Vault: On-Device Encrypted Vault (0600)',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Key SHA-256 Fingerprint: $keyFingerprint',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'How your privacy is protected:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '• All Note titles and bodies are encrypted before saving.\n'
              '• All To-Do tasks are encrypted before sync.\n'
              '• SQLite databases and Supabase cloud store only ciphertext.\n'
              '• Server and database administrators cannot read your content.\n'
              '• Decryption happens solely in-memory on this screen.',
              style: TextStyle(fontSize: 12, height: 1.45),
            ),
          ],
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final Color currentColor = ref.read(colorSchemeProvider);
    final bool currentUseDeviceColor = ref.read(useDeviceColorProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = currentColor;
        bool tempUseDeviceColor = currentUseDeviceColor;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select a Theme Color'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // TOP OPTION: Device Default (System Wallpaper Theme)
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setDialogState(() {
                          tempUseDeviceColor = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: tempUseDeviceColor
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: tempUseDeviceColor
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                            width: tempUseDeviceColor ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.wallpaper_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device Default',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: tempUseDeviceColor
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Match your phone system wallpaper colors',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: tempUseDeviceColor
                                          ? theme.colorScheme.onPrimaryContainer
                                              .withValues(alpha: 0.8)
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              tempUseDeviceColor
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: tempUseDeviceColor
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'OR PICK A CUSTOM SEED COLOR',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    BlockPicker(
                      availableColors: [
                        Colors.deepOrangeAccent,
                        Colors.red,
                        Colors.pink,
                        Colors.blueGrey,
                        Colors.blue,
                        Colors.lightBlue,
                        Colors.cyan,
                        Colors.yellow,
                        Colors.lime,
                        Colors.green,
                        Colors.lightGreenAccent,
                        Colors.teal,
                        Colors.indigo,
                        Colors.deepPurple,
                        Colors.purple,
                        Colors.purpleAccent,
                        Colors.amber,
                        Colors.orange,
                        Colors.brown,
                        Colors.tealAccent,
                      ],
                      pickerColor:
                          tempUseDeviceColor ? Colors.transparent : tempColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          tempColor = color;
                          tempUseDeviceColor = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                FilledButton(
                  child: const Text('Apply'),
                  onPressed: () async {
                    ref.read(useDeviceColorProvider.notifier).state =
                        tempUseDeviceColor;
                    await Hive.box('testBox')
                        .put('useDeviceColor', tempUseDeviceColor);
                    if (!tempUseDeviceColor) {
                      ref.read(colorSchemeProvider.notifier).state = tempColor;
                      await Hive.box('testBox')
                          .put('selectedColor', tempColor.toARGB32());
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  MaterialColor createMaterialColor(Color color) {
    Map<int, Color> colorSwatch = {
      50: color.withValues(alpha: 0.1),
      100: color.withValues(alpha: 0.2),
      200: color.withValues(alpha: 0.3),
      300: color.withValues(alpha: 0.4),
      400: color.withValues(alpha: 0.5),
      500: color.withValues(alpha: 0.6),
      600: color.withValues(alpha: 0.7),
      700: color.withValues(alpha: 0.8),
      800: color.withValues(alpha: 0.9),
      900: color.withValues(alpha: 1.0),
    };

    return MaterialColor(color.toARGB32(), colorSwatch);
  }
}
