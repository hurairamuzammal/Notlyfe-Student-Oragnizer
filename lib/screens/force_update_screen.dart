import 'package:flutter/material.dart';
import 'package:notlyfe/services/app_version_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Blocking screen displayed when the running app build is below the remote
/// minimum supported version.
class ForceUpdateScreen extends StatelessWidget {
  final AppVersionPolicy policy;
  final VoidCallback? onRetry;

  const ForceUpdateScreen({
    super.key,
    required this.policy,
    this.onRetry,
  });

  Future<void> _openDownload(BuildContext context) async {
    final uri = Uri.tryParse(policy.downloadUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open download link automatically.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
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
                        color: cs.errorContainer.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 52,
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Update Required',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      policy.updateMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Installed: v${AppVersionService.currentVersion}  •  Required: v${policy.minSupportedVersion}+',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openDownload(context),
                        icon: const Icon(Icons.download_rounded),
                        label: Text('Download v${policy.latestVersion}'),
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Check Again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
