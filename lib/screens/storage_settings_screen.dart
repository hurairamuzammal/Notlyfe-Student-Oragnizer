import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/providers/notes_sync_provider.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/services/storage/providers/custom_http_providers.dart';
import 'package:notlyfe/services/storage/providers/google_drive_providers.dart';
import 'package:notlyfe/services/storage/providers/local_directory_providers.dart';
import 'package:notlyfe/services/storage/providers/webdav_providers.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';
import 'package:notlyfe/services/storage/storage_security.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

/// Settings screen for configuring and testing custom storage backends
/// for both Course Files and E2EE Notes Sync Locations.
class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState
    extends ConsumerState<StorageSettingsScreen> {
  // WebDAV form controllers
  final _webdavUrlCtrl = TextEditingController();
  final _webdavUserCtrl = TextEditingController();
  final _webdavPassCtrl = TextEditingController();
  final _webdavRootCtrl = TextEditingController(text: 'Notlyfe');

  // Custom HTTP REST form controllers
  final _httpUrlCtrl = TextEditingController();
  final _httpHeaderCtrl = TextEditingController(text: 'Authorization');
  final _httpTokenCtrl = TextEditingController();

  // Local folder paths
  String? _localFilesDir;
  String? _localNotesDir;

  bool _loadingConfigs = true;
  bool _testingFiles = false;
  bool _testingNotes = false;
  bool _migratingNotes = false;
  StorageTestResult? _fileTestResult;
  StorageTestResult? _notesTestResult;

  @override
  void initState() {
    super.initState();
    _loadSavedConfigs();
  }

  @override
  void dispose() {
    _webdavUrlCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPassCtrl.dispose();
    _webdavRootCtrl.dispose();
    _httpUrlCtrl.dispose();
    _httpHeaderCtrl.dispose();
    _httpTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfigs() async {
    await StorageBackendRegistry.instance.initialize();
    final webdav = await WebDavConfig.load();
    final httpCfg = await CustomHttpConfig.load();
    final localFiles = await LocalDirectoryConfig.getFilesDirectory();
    final localNotes = await LocalDirectoryConfig.getNotesDirectory();

    if (!mounted) return;
    setState(() {
      if (webdav != null) {
        _webdavUrlCtrl.text = webdav.baseUrl;
        _webdavUserCtrl.text = webdav.username;
        _webdavPassCtrl.text = webdav.password;
        _webdavRootCtrl.text = webdav.rootFolder;
      }
      if (httpCfg != null) {
        _httpUrlCtrl.text = httpCfg.baseUrl;
        _httpHeaderCtrl.text = httpCfg.authHeaderName;
        _httpTokenCtrl.text = httpCfg.authToken;
      }
      _localFilesDir = localFiles;
      _localNotesDir = localNotes;
      _loadingConfigs = false;
    });
  }

  Future<void> _saveWebDavConfig() async {
    final check =
        StorageSecurityHelper.validateEndpointUrl(_webdavUrlCtrl.text);
    if (!check.isValid) {
      _showSnack(check.error!, isError: true);
      return;
    }
    try {
      await WebDavConfig.save(WebDavConfig(
        baseUrl: _webdavUrlCtrl.text.trim(),
        username: _webdavUserCtrl.text.trim(),
        password: _webdavPassCtrl.text,
        rootFolder: StorageSecurityHelper.sanitizeSegment(
          _webdavRootCtrl.text.trim(),
          fallback: 'Notlyfe',
        ),
      ));
      if (mounted) setState(() {});
      _showSnack('WebDAV configuration encrypted & saved.');
    } catch (_) {
      _showSnack('Could not save WebDAV configuration.', isError: true);
    }
  }

  Future<void> _saveCustomHttpConfig() async {
    final check = StorageSecurityHelper.validateEndpointUrl(_httpUrlCtrl.text);
    if (!check.isValid) {
      _showSnack(check.error!, isError: true);
      return;
    }
    final cleanHeader =
        _httpHeaderCtrl.text.trim().replaceAll(RegExp(r'[\r\n:]'), '');
    try {
      await CustomHttpConfig.save(CustomHttpConfig(
        baseUrl: _httpUrlCtrl.text.trim(),
        authHeaderName: cleanHeader.isEmpty ? 'Authorization' : cleanHeader,
        authToken: _httpTokenCtrl.text.trim(),
      ));
      if (mounted) setState(() {});
      _showSnack('Custom REST configuration encrypted & saved.');
    } catch (_) {
      _showSnack('Could not save Custom REST configuration.', isError: true);
    }
  }

  Future<void> _pickLocalFolder({required bool forNotes}) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: forNotes
          ? 'Choose Notes Storage Folder'
          : 'Choose Files Storage Folder',
    );
    if (selected == null || selected.trim().isEmpty) return;

    if (forNotes) {
      await LocalDirectoryConfig.setNotesDirectory(selected);
      if (mounted) setState(() => _localNotesDir = selected);
    } else {
      await LocalDirectoryConfig.setFilesDirectory(selected);
      if (mounted) setState(() => _localFilesDir = selected);
    }
    _showSnack('Folder saved: $selected');
  }

  Future<void> _testActiveFileBackend() async {
    setState(() {
      _testingFiles = true;
      _fileTestResult = null;
    });
    try {
      final res = await StorageBackendRegistry.instance.activeFileProvider
          .testConnection();
      if (mounted) setState(() => _fileTestResult = res);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileTestResult = StorageTestResult(
            success: false,
            message: 'Connection test failed: $e',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _testingFiles = false);
    }
  }

  Future<void> _testActiveNotesBackend() async {
    setState(() {
      _testingNotes = true;
      _notesTestResult = null;
    });
    try {
      final res = await StorageBackendRegistry.instance.activeNotesProvider
          .testConnection();
      if (mounted) setState(() => _notesTestResult = res);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notesTestResult = StorageTestResult(
            success: false,
            message: 'Connection test failed: $e',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _testingNotes = false);
    }
  }

  Future<void> _migrateNotesToActiveBackend() async {
    setState(() => _migratingNotes = true);
    try {
      final userId = AuthServices().getCurrentUserId();
      final count = await ref
          .read(notesSyncServiceProvider)
          .pushAllLocalNotesToActiveProvider(userId);
      _showSnack('Synced $count local notes to active storage location.');
    } catch (e) {
      _showSnack('Migration failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _migratingNotes = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? cs.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final registry = ref.watch(storageRegistryProvider);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text(
          'Storage & Custom Locations',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loadingConfigs
          ? const Center(
              child: M3ShapeChangingProgressIndicator(
                size: 38,
                strokeWidth: 3.5,
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Intro Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const M3IconBadge(icon: Icons.hub_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Open-Source Freedom: Bring your own Google Drive, WebDAV/Nextcloud, custom REST/S3 server, or local synced folder for both files and E2EE notes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 1: COURSE FILES STORAGE BACKEND
                const M3SectionHeader('Course Files Storage Backend'),
                const SizedBox(height: 8),
                M3SettingsGroupCard(
                  children: [
                    for (int i = 0; i < registry.fileProviders.length; i++) ...[
                      _buildFileProviderTile(
                        theme,
                        registry.fileProviders[i],
                        registry.activeFileProviderId ==
                            registry.fileProviders[i].typeId,
                      ),
                      if (i < registry.fileProviders.length - 1)
                        const Divider(indent: 58, height: 1),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _buildTestRow(
                  theme: theme,
                  testing: _testingFiles,
                  label: 'Test File Storage Connection',
                  onTest: _testActiveFileBackend,
                  result: _fileTestResult,
                ),
                const SizedBox(height: 22),

                // SECTION 2: NOTES STORAGE LOCATION
                const M3SectionHeader('Notes Storage & Sync Location'),
                const SizedBox(height: 8),
                M3SettingsGroupCard(
                  children: [
                    for (int i = 0; i < registry.notesProviders.length; i++) ...[
                      _buildNotesProviderTile(
                        theme,
                        registry.notesProviders[i],
                        registry.activeNotesProviderId ==
                            registry.notesProviders[i].typeId,
                      ),
                      if (i < registry.notesProviders.length - 1)
                        const Divider(indent: 58, height: 1),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    M3MorphingPillButton(
                      tonal: true,
                      icon: _testingNotes ? null : Icons.science_rounded,
                      onPressed: _testingNotes ? null : _testActiveNotesBackend,
                      label: _testingNotes
                          ? const M3ShapeChangingProgressIndicator(
                              size: 16, strokeWidth: 2)
                          : const Text('Test Notes Location'),
                    ),
                    M3MorphingPillButton(
                      selected: true,
                      icon: _migratingNotes
                          ? null
                          : Icons.cloud_upload_rounded,
                      onPressed: _migratingNotes
                          ? null
                          : _migrateNotesToActiveBackend,
                      label: _migratingNotes
                          ? const M3ShapeChangingProgressIndicator(
                              size: 16,
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text('Sync Local Notes Here'),
                    ),
                  ],
                ),
                if (_notesTestResult != null) ...[
                  const SizedBox(height: 10),
                  _buildTestResultCard(theme, _notesTestResult!),
                ],
                const SizedBox(height: 24),

                // SECTION 3: BACKEND CONFIGURATION FORMS
                const M3SectionHeader('Backend Configuration'),
                const SizedBox(height: 8),

                // WebDAV Config Card
                _buildWebDavConfigCard(theme),
                const SizedBox(height: 12),

                // Custom HTTP REST Config Card
                _buildCustomHttpConfigCard(theme),
                const SizedBox(height: 12),

                // Local Folders Card
                _buildLocalFolderCard(theme),
                const SizedBox(height: 20),

                // Developer Extensibility Info
                M3SettingsGroupCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const M3IconBadge(icon: Icons.code_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add Your Own Custom Backend',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Contributors can implement CustomFileStorageProvider or CustomNotesStorageProvider and register them via StorageBackendRegistry.instance. See docs/CUSTOM_STORAGE.md and test/custom_storage_test.dart.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFileProviderTile(
    ThemeData theme,
    CustomFileStorageProvider provider,
    bool selected,
  ) {
    return ListTile(
      leading: M3IconBadge(
        icon: provider.typeId == GoogleDriveFileStorageProvider.id
            ? Icons.add_to_drive_rounded
            : provider.typeId == WebDavFileStorageProvider.id
                ? Icons.dns_rounded
                : provider.typeId == CustomHttpFileStorageProvider.id
                    ? Icons.api_rounded
                    : Icons.folder_rounded,
      ),
      title: Text(provider.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(provider.description),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      onTap: () async {
        if (provider.typeId == GoogleDriveFileStorageProvider.id &&
            !await GoogleDriveStorageService.instance.isDriveConnected()) {
          final err = await GoogleDriveStorageService.instance.connectDrive();
          if (err != null) {
            _showSnack(err, isError: true);
            return;
          }
        }
        await StorageBackendRegistry.instance
            .setActiveFileProvider(provider.typeId);
        if (mounted) setState(() => _fileTestResult = null);
      },
    );
  }

  Widget _buildNotesProviderTile(
    ThemeData theme,
    CustomNotesStorageProvider provider,
    bool selected,
  ) {
    return ListTile(
      leading: M3IconBadge(
        icon: provider.typeId == GoogleDriveNotesStorageProvider.id
            ? Icons.add_to_drive_rounded
            : provider.typeId == WebDavNotesStorageProvider.id
                ? Icons.dns_rounded
                : provider.typeId == CustomHttpNotesStorageProvider.id
                    ? Icons.api_rounded
                    : provider.typeId == LocalDirectoryNotesStorageProvider.id
                        ? Icons.folder_rounded
                        : Icons.cloud_done_rounded,
      ),
      title: Text(provider.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(provider.description),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      onTap: () async {
        if (provider.typeId == GoogleDriveNotesStorageProvider.id &&
            !await GoogleDriveStorageService.instance.isDriveConnected()) {
          final err = await GoogleDriveStorageService.instance.connectDrive();
          if (err != null) {
            _showSnack(err, isError: true);
            return;
          }
        }
        await StorageBackendRegistry.instance
            .setActiveNotesProvider(provider.typeId);
        if (mounted) setState(() => _notesTestResult = null);
      },
    );
  }

  Widget _buildTestRow({
    required ThemeData theme,
    required bool testing,
    required String label,
    required VoidCallback onTest,
    required StorageTestResult? result,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        M3MorphingPillButton(
          tonal: true,
          icon: testing ? null : Icons.science_rounded,
          onPressed: testing ? null : onTest,
          label: testing
              ? const M3ShapeChangingProgressIndicator(
                  size: 16, strokeWidth: 2)
              : Text(label),
        ),
        if (result != null) ...[
          const SizedBox(height: 10),
          _buildTestResultCard(theme, result),
        ],
      ],
    );
  }

  Widget _buildTestResultCard(ThemeData theme, StorageTestResult result) {
    final cs = theme.colorScheme;
    final bg = result.success
        ? Colors.green.withValues(alpha: 0.14)
        : cs.errorContainer.withValues(alpha: 0.55);
    final fg = result.success ? Colors.green.shade800 : cs.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (result.latency != null)
                  Text(
                    'Latency: ${result.latency!.inMilliseconds} ms',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDavConfigCard(ThemeData theme) {
    return M3SettingsGroupCard(
      children: [
        ExpansionTile(
          leading: const M3IconBadge(icon: Icons.dns_rounded),
          title: const Text('WebDAV / Nextcloud Setup',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_webdavUrlCtrl.text.isEmpty
              ? 'Not configured'
              : _webdavUrlCtrl.text),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            TextField(
              controller: _webdavUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'WebDAV Base URL',
                hintText: 'https://cloud.example.com/remote.php/dav/files/user',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _webdavUserCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _webdavPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'App Password / Token',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _webdavRootCtrl,
              decoration: const InputDecoration(
                labelText: 'Root Folder Name',
                hintText: 'Notlyfe',
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: M3MorphingPillButton(
                selected: true,
                icon: Icons.save_rounded,
                onPressed: _saveWebDavConfig,
                label: const Text('Save WebDAV'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomHttpConfigCard(ThemeData theme) {
    return M3SettingsGroupCard(
      children: [
        ExpansionTile(
          leading: const M3IconBadge(icon: Icons.api_rounded),
          title: const Text('Custom REST / Self-Hosted API Setup',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_httpUrlCtrl.text.isEmpty
              ? 'Not configured'
              : _httpUrlCtrl.text),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            TextField(
              controller: _httpUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://storage.myserver.com/notlyfe',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _httpHeaderCtrl,
              decoration: const InputDecoration(
                labelText: 'Auth Header Name',
                hintText: 'Authorization',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _httpTokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Bearer Token / API Key',
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: M3MorphingPillButton(
                selected: true,
                icon: Icons.save_rounded,
                onPressed: _saveCustomHttpConfig,
                label: const Text('Save Custom API'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocalFolderCard(ThemeData theme) {
    return M3SettingsGroupCard(
      children: [
        ListTile(
          leading: const M3IconBadge(icon: Icons.folder_copy_rounded),
          title: const Text('Custom Course Files Folder',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_localFilesDir ?? 'Not selected'),
          trailing: FilledButton.tonal(
            onPressed: () => _pickLocalFolder(forNotes: false),
            child: const Text('Choose'),
          ),
        ),
        const Divider(indent: 58, height: 1),
        ListTile(
          leading: const M3IconBadge(icon: Icons.edit_note_rounded),
          title: const Text('Custom Notes Storage Folder',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_localNotesDir ?? 'Not selected'),
          trailing: FilledButton.tonal(
            onPressed: () => _pickLocalFolder(forNotes: true),
            child: const Text('Choose'),
          ),
        ),
      ],
    );
  }
}
