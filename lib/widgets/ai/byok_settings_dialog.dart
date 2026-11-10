import 'package:flutter/material.dart';
import '../../services/ai/byok_provider.dart';
import '../../services/ai/byok_release_gate.dart';
import '../../services/ai/llm_client.dart';

/// Modal dialog allowing learners to configure their Bring-Your-Own-Key (BYOK) AI provider (ARCH-4).
class ByokSettingsDialog extends StatefulWidget {
  final ByokStorageService storageService;

  const ByokSettingsDialog({
    super.key,
    required this.storageService,
  });

  static Future<void> show(BuildContext context,
      {ByokStorageService? storageService}) {
    return showDialog(
      context: context,
      builder: (ctx) => ByokSettingsDialog(
        storageService: storageService ?? ByokStorageService(),
      ),
    );
  }

  @override
  State<ByokSettingsDialog> createState() => _ByokSettingsDialogState();
}

class _ByokSettingsDialogState extends State<ByokSettingsDialog> {
  late AiProvider _selectedProvider;
  late TextEditingController _keyController;
  late TextEditingController _modelController;
  late TextEditingController _endpointController;
  bool _obscureKey = true;
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testStatus;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = AiProvider.gemini;
    _keyController = TextEditingController();
    _modelController = TextEditingController();
    _endpointController = TextEditingController();
    // Do not load an existing secret into UI controllers while suspended.
    if (ByokReleaseGate.enabled) {
      _loadCurrentConfig();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadCurrentConfig() async {
    final config = await widget.storageService.loadConfig();
    setState(() {
      _selectedProvider = config.provider;
      _keyController.text = config.apiKey;
      _modelController.text = config.model;
      _endpointController.text = config.customEndpoint ?? '';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  void _onProviderChanged(AiProvider? provider) {
    if (provider == null) return;
    setState(() {
      _selectedProvider = provider;
      _modelController.text = provider.defaultModel;
      _endpointController.text = '';
      _testStatus = null;
    });
  }

  Future<void> _testConnection() async {
    ByokReleaseGate.requireEnabled();
    setState(() {
      _isTesting = true;
      _testStatus = 'Testing provider connection...';
      _testSuccess = false;
    });

    try {
      final config = ByokConfig(
        provider: _selectedProvider,
        apiKey: _keyController.text.trim(),
        model: _modelController.text.trim().isNotEmpty
            ? _modelController.text.trim()
            : _selectedProvider.defaultModel,
        customEndpoint: _endpointController.text.trim().isNotEmpty
            ? _endpointController.text.trim()
            : null,
      );

      final client = LlmClient.create(config);
      await client.generateStructuredJson(
        prompt: 'Return a JSON object with key "status" equal to "ok".',
        jsonSchema: {
          'type': 'object',
          'properties': {
            'status': {'type': 'string'}
          },
          'required': ['status']
        },
      );

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testStatus = 'Connection successful! Provider is ready.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testStatus = 'Connection failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _save() async {
    ByokReleaseGate.requireEnabled();
    final config = ByokConfig(
      provider: _selectedProvider,
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim().isNotEmpty
          ? _modelController.text.trim()
          : _selectedProvider.defaultModel,
      customEndpoint: _endpointController.text.trim().isNotEmpty
          ? _endpointController.text.trim()
          : null,
    );

    await widget.storageService.saveConfig(config);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI settings saved successfully.')),
      );
    }
  }

  Future<void> _clear() async {
    await widget.storageService.clearConfig();
    setState(() {
      _keyController.clear();
      _endpointController.clear();
      _testStatus = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ByokReleaseGate.enabled) {
      return AlertDialog(
        key: const Key('byok-unavailable-dialog'),
        title: const Text('AI key integration unavailable'),
        content: const Text(ByokReleaseGate.unavailableMessage),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.storageService.clearConfig();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Clear saved local key'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('AI Generation & Keys (BYOK)')),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bring Your Own Key (BYOK) allows you to generate personalized practice questions and study plans directly using your preferred LLM provider.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 18, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Keys are stored strictly in local browser storage and never uploaded to the server.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AiProvider>(
                      value: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: 'Provider',
                        border: OutlineInputBorder(),
                      ),
                      items: AiProvider.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p.displayName),
                        );
                      }).toList(),
                      onChanged: _onProviderChanged,
                    ),
                    const SizedBox(height: 14),
                    if (_selectedProvider != AiProvider.mock) ...[
                      TextField(
                        controller: _keyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Paste personal API key here',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureKey
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model Name / ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _endpointController,
                      decoration: InputDecoration(
                        labelText: 'Custom Endpoint (Optional)',
                        hintText: _selectedProvider.defaultEndpoint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_testStatus != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            _testSuccess ? Icons.check_circle : Icons.error,
                            color: _testSuccess
                                ? Colors.green
                                : theme.colorScheme.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testStatus!,
                              style: TextStyle(
                                color: _testSuccess
                                    ? Colors.green
                                    : theme.colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        if (_selectedProvider != AiProvider.mock &&
            _keyController.text.isNotEmpty)
          TextButton(
            onPressed: _clear,
            child: const Text('Clear Key'),
          ),
        TextButton(
          onPressed: _isTesting ? null : _testConnection,
          child: _isTesting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Test Connection'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}

