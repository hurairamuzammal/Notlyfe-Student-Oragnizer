import 'package:flutter/material.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

/// One-time onboarding step shown after initial sign-in so users can connect
/// their Google Drive folder once and have it persist securely across sessions.
class DriveSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const DriveSetupScreen({super.key, required this.onComplete});

  @override
  State<DriveSetupScreen> createState() => _DriveSetupScreenState();
}

class _DriveSetupScreenState extends State<DriveSetupScreen> {
  bool _connecting = false;
  String? _error;

  Future<void> _connectOnce() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final err = await GoogleDriveStorageService.instance.connectDrive();
    if (!mounted) return;

    if (err == null) {
      await GoogleDriveStorageService.instance.markInitialSetupHandled();
      if (!mounted) return;
      widget.onComplete();
    } else {
      setState(() {
        _connecting = false;
        _error = err;
      });
    }
  }

  Future<void> _skip() async {
    await GoogleDriveStorageService.instance.markInitialSetupHandled();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_to_drive_rounded,
                      size: 52,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connect Google Drive Once',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Store your course files privately inside your own Notlyfe/<Course> Drive folder. Your connection is encrypted on-device and restored automatically on future launches.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_rounded,
                            size: 20, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Folder-only permission (drive.file). Notlyfe cannot read other files in your Drive.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: M3MorphingPillButton(
                      selected: true,
                      icon: _connecting ? null : Icons.add_to_drive_rounded,
                      onPressed: _connecting ? null : _connectOnce,
                      label: _connecting
                          ? const M3ShapeChangingProgressIndicator(
                              size: 18,
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text('Connect Google Drive'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _connecting ? null : _skip,
                    child: const Text('Skip for now (configure in Settings)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
