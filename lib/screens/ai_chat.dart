import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:notlyfe/screens/ai_settings_screen.dart';
import 'package:notlyfe/services/multi_ai_service.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  AiProviderType _activeProvider = AiProviderType.gemini;
  String _activeModelId = 'gemini-1.5-flash';
  LlmProvider? _llmProvider;
  bool _isLoadingConfig = true;
  Key _chatKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadAiConfig();
  }

  Future<void> _loadAiConfig() async {
    if (mounted) setState(() => _isLoadingConfig = true);
    final provider = await MultiAiService.getActiveProvider();
    final modelId = await MultiAiService.getActiveModelFor(provider);
    final llm = await MultiAiService.createActiveLlmProvider();

    if (mounted) {
      setState(() {
        _activeProvider = provider;
        _activeModelId = modelId;
        _llmProvider = llm;
        _chatKey = UniqueKey();
        _isLoadingConfig = false;
      });
    }
  }

  Future<void> _promptForApiKey() async {
    final controller = TextEditingController();
    bool obscure = true;

    final hint = switch (_activeProvider) {
      AiProviderType.gemini => 'AIzaSy... (Google AI Studio Key)',
      AiProviderType.openai => 'sk-... (OpenAI API Key)',
      AiProviderType.claude => 'sk-ant-... (Anthropic Claude Key)',
    };

    try {
      final result = await showDialog<String?>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.key_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_activeProvider.displayName} API Key',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your personal ${_activeProvider.displayName} API key to start chatting. Keys are encrypted and stored locally on your device.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: hint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Save & Chat'),
              ),
            ],
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        await MultiAiService.saveApiKeyFor(_activeProvider, result);
        await _loadAiConfig();
      }
    } finally {
      controller.dispose();
    }
  }

  Widget _buildNoKeyPlaceholder(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Personal API Key Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Notlyfe does not use a shared default API key. To chat, connect your personal API key for Google Gemini, OpenAI (ChatGPT), or Anthropic (Claude).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Provider selector pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hub_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Active: ${_activeProvider.displayName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _promptForApiKey,
              icon: const Icon(Icons.key_rounded, size: 20),
              label: Text(
                'Enter ${_activeProvider.displayName} Key',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AiSettingsScreen()),
                );
                _loadAiConfig();
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Switch Provider or Model'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with ${_activeProvider.displayName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  _activeModelId,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _llmProvider != null
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _llmProvider != null ? Colors.green : Colors.orange,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _llmProvider != null ? 'Active' : 'Key Needed',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _llmProvider != null
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Model & Key Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AiSettingsScreen(),
                ),
              );
              _loadAiConfig();
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: colorScheme.surface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      body: _isLoadingConfig
          ? const Center(
              child: M3ShapeChangingProgressIndicator(size: 40, strokeWidth: 3.5),
            )
          : _llmProvider == null
              ? _buildNoKeyPlaceholder(theme)
              : LlmChatView(
                  key: _chatKey,
                  style: LlmChatViewStyle(
                    backgroundColor: colorScheme.surface,
                    progressIndicatorColor: colorScheme.primary,
                    chatInputStyle: ChatInputStyle(
                      textStyle: TextStyle(color: colorScheme.onSurface),
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      hintText: 'Ask ${_activeProvider.displayName}...',
                    ),
                  ),
                  provider: _llmProvider!,
                ),
    );
  }
}
