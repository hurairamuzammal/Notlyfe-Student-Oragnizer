import 'package:flutter/material.dart';
import 'package:notlyfe/services/multi_ai_service.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiProviderType _activeProvider = AiProviderType.gemini;
  final Map<AiProviderType, String?> _apiKeys = {};
  final Map<AiProviderType, String> _activeModels = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    if (mounted) setState(() => _isLoading = true);
    final activeProv = await MultiAiService.getActiveProvider();

    for (final prov in AiProviderType.values) {
      _apiKeys[prov] = await MultiAiService.getApiKeyFor(prov);
      _activeModels[prov] = await MultiAiService.getActiveModelFor(prov);
    }

    if (mounted) {
      setState(() {
        _activeProvider = activeProv;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectProvider(AiProviderType provider) async {
    await MultiAiService.setActiveProvider(provider);
    if (mounted) {
      setState(() {
        _activeProvider = provider;
      });
    }
  }

  Future<void> _selectModel(String modelId) async {
    await MultiAiService.setActiveModelFor(_activeProvider, modelId);
    if (!mounted) return;
    setState(() {
      _activeModels[_activeProvider] = modelId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Active model set to $modelId'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _editApiKey(AiProviderType provider) async {
    final hasExisting = (_apiKeys[provider] ?? '').isNotEmpty;
    final controller = TextEditingController();
    bool obscure = true;

    final hint = switch (provider) {
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
            title: Text('${provider.displayName} API Key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasExisting
                      ? 'Enter a new API key to replace the stored key, or tap Delete Key to remove it.'
                      : 'Enter your API key. It will be encrypted and stored safely on your device.',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: hasExisting ? 'New API Key' : 'API Key',
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
              if (hasExisting)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.of(ctx).pop(''),
                  child: const Text('Delete Key'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Save Key'),
              ),
            ],
          ),
        ),
      );

      if (result != null) {
        await MultiAiService.saveApiKeyFor(provider, result);
        await _loadAllSettings();
      }
    } finally {
      controller.dispose();
    }
  }

  Widget _buildProviderCard(ThemeData theme, AiProviderType provider) {
    final isSelected = _activeProvider == provider;
    final hasKey = _apiKeys[provider] != null && _apiKeys[provider]!.isNotEmpty;
    final activeModel = _activeModels[provider] ?? '';

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
          : theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 1.8,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _selectProvider(provider),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      size: 20,
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Model: $activeModel',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Key Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasKey
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasKey ? Colors.green : Colors.orange,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      hasKey ? 'Key Configured' : 'No Key',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasKey ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editApiKey(provider),
                    icon: Icon(hasKey ? Icons.edit_rounded : Icons.add_rounded, size: 16),
                    label: Text(hasKey ? 'Edit API Key' : 'Add API Key'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeModelsList = MultiAiService.availableModels
        .where((m) => m.provider == _activeProvider)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Providers & API Keys'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: M3ShapeChangingProgressIndicator(size: 40, strokeWidth: 3.5),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: theme.colorScheme.secondary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bring Your Own Key (BYOK): No default key is used. Add your personal Google, OpenAI, or Anthropic API key.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSecondaryContainer,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 1: Select Active Provider
                Text(
                  'SELECT AI PROVIDER',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                ...AiProviderType.values.map((prov) => _buildProviderCard(theme, prov)),

                const SizedBox(height: 20),

                // SECTION 2: Model Selection for Active Provider
                Text(
                  'SELECT ${_activeProvider.displayName.toUpperCase()} MODEL',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: activeModelsList.map((model) {
                      final isSelected = (_activeModels[_activeProvider] ?? '') == model.modelId;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: Radio<String>(
                          value: model.modelId,
                          groupValue: _activeModels[_activeProvider],
                          onChanged: (val) {
                            if (val != null) _selectModel(val);
                          },
                        ),
                        title: Text(
                          model.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          model.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => _selectModel(model.modelId),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
