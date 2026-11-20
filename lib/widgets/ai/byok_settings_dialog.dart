import 'package:flutter/material.dart';
import '../../services/ai/byok_provider.dart';
import '../../services/ai/byok_release_gate.dart';
import '../../services/ai/llm_client.dart';

/// Lets an adult learner use their own AI provider key (BYOK, FLAG-015).
///
/// The key lives only in [storageService]'s memory: it is never written to
/// the device or sent to LearningApp, and it is gone after a reload. The
/// learner must confirm they are 18 or older and that their provider's
/// terms allow this use before the key is kept (master plan v2.6 §14.7).
class ByokSettingsDialog extends StatefulWidget {
  const ByokSettingsDialog({
    super.key,
    required this.storageService,
    this.onSaved,
    this.clientFactory = LlmClient.create,
    this.releaseApproved = ByokReleaseGate.enabled,
  });

  final ByokStorageService storageService;

  /// Receives the saved settings (with the key) so the session uses them.
  final ValueChanged<ByokConfig>? onSaved;
  final LlmClient Function(ByokConfig config) clientFactory;

  /// The build-time latch; a parameter only so tests can show the ON state.
  final bool releaseApproved;

  static Future<void> show(
    BuildContext context, {
    ByokStorageService? storageService,
    ValueChanged<ByokConfig>? onSaved,
    LlmClient Function(ByokConfig config)? clientFactory,
    bool releaseApproved = ByokReleaseGate.enabled,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ByokSettingsDialog(
        storageService: storageService ?? ByokStorageService(),
        onSaved: onSaved,
        clientFactory: clientFactory ?? LlmClient.create,
        releaseApproved: releaseApproved,
      ),
    );
  }

  @override
  State<ByokSettingsDialog> createState() => _ByokSettingsDialogState();
}

/// Providers a learner can pick. The simulator is for development only.
const _choices = [AiProvider.gemini, AiProvider.openai, AiProvider.openrouter];

class _ByokSettingsDialogState extends State<ByokSettingsDialog> {
  AiProvider _provider = AiProvider.gemini;
  final _key = TextEditingController();
  String _model = AiProvider.gemini.defaultModel;
  List<String> _models = const [];
  bool _obscure = true;
  bool _loading = true;
  bool _testing = false;
  bool _adultConfirmed = false;
  String? _status;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    if (widget.releaseApproved) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final config = await widget.storageService.loadConfig();
    if (!mounted) return;
    setState(() {
      if (_choices.contains(config.provider)) {
        _provider = config.provider;
        _model = config.model;
        _key.text = config.apiKey;
        _adultConfirmed = config.apiKey.isNotEmpty;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  ByokConfig get _config =>
      ByokConfig(provider: _provider, apiKey: _key.text.trim(), model: _model);

  /// Lists the models this key can use and picks a sensible one, so a
  /// retired default never leaves the learner with a broken setting.
  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = 'Checking your key…';
      _ok = false;
    });
    try {
      final client = widget.clientFactory(_config);
      final models = await client.listModels();
      if (!mounted) return;
      final model = models.contains(_model) ? _model : _pickModel(models);
      if (model == null) {
        setState(() {
          _testing = false;
          _status = 'Your key works, but no text models are available to it.';
        });
        return;
      }
      setState(() {
        _models = models;
        _model = model;
        _testing = false;
        _ok = true;
        _status = 'Your key works.';
      });
    } on LlmException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _status = e.kind.message(_provider.shortName);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _status = LlmFailureKind.unknown.message(_provider.shortName);
      });
    }
  }

  String? _pickModel(List<String> models) {
    if (models.isEmpty) return null;
    const skip = ['embed', 'image', 'tts', 'audio', 'vision', 'live', 'aqa'];
    final usable = models
        .where((m) => !skip.any((s) => m.toLowerCase().contains(s)))
        .toList();
    final pool = usable.isEmpty ? models : usable;
    for (final hint in const ['flash-latest', 'flash', 'mini', 'auto']) {
      for (final m in pool) {
        if (m.contains(hint) && !m.contains('preview')) return m;
      }
    }
    return pool.first;
  }

  Future<void> _save() async {
    final config = _config;
    await widget.storageService.saveConfig(config);
    widget.onSaved?.call(config);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('${_provider.shortName} key ready for this tab.')),
    );
  }

  Future<void> _clear() async {
    await widget.storageService.clearConfig();
    widget.onSaved?.call(
      ByokConfig(provider: _provider, apiKey: '', model: _model),
    );
    if (!mounted) return;
    setState(() {
      _key.clear();
      _status = null;
      _ok = false;
      _adultConfirmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.releaseApproved) {
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
    final hasKey = _key.text.trim().isNotEmpty;
    final canSave = hasKey && _adultConfirmed && !_testing;

    return AlertDialog(
      key: const Key('byok-settings-dialog'),
      title: const Text('Use your own API key'),
      content: _loading
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
                      'With your own key, the app can send the lesson prompt '
                      'to your AI and check the reply for you. Your provider '
                      'bills or limits your account, not LearningApp.',
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
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Your key stays in this browser tab only. It is '
                              'never saved or sent to LearningApp, and you '
                              'enter it again after a reload. Prompts go '
                              'straight from your browser to your provider. '
                              'On free plans, some providers may have people '
                              'review prompts and use them to improve their '
                              "models, so don't put personal details in a "
                              'topic.',
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
                      value: _provider,
                      decoration: const InputDecoration(
                        labelText: 'Provider',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in _choices)
                          DropdownMenuItem(
                            value: p,
                            child: Text(p.displayName),
                          ),
                      ],
                      onChanged: (p) {
                        if (p == null) return;
                        setState(() {
                          _provider = p;
                          _model = p.defaultModel;
                          _models = const [];
                          _status = null;
                          _ok = false;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('byok-key-field'),
                      controller: _key,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => setState(() {
                        _status = null;
                        _ok = false;
                      }),
                      decoration: InputDecoration(
                        labelText: 'API key',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show key' : 'Hide key',
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_models.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: const Key('byok-model-field'),
                        value: _model,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final m in _models)
                            DropdownMenuItem(value: m, child: Text(m)),
                        ],
                        onChanged: (m) => setState(() => _model = m ?? _model),
                      )
                    else
                      Text(
                        'Model: $_model (check your key to choose another)',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      key: const Key('byok-adult-confirm'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _adultConfirmed,
                      onChanged: (v) =>
                          setState(() => _adultConfirmed = v ?? false),
                      title: const Text(
                        "I'm 18 or older, and my provider's terms let me use "
                        'my key this way.',
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _ok
                                ? Icons.check_circle
                                : (_testing
                                      ? Icons.hourglass_top
                                      : Icons.error),
                            color: _ok ? Colors.green : theme.colorScheme.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _status!,
                              key: const Key('byok-status'),
                              style: theme.textTheme.bodySmall,
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
        if (hasKey)
          TextButton(onPressed: _clear, child: const Text('Forget key')),
        TextButton(
          onPressed: _testing || !hasKey ? null : _test,
          child: _testing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Check key'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: const Text('Use this key'),
        ),
      ],
    );
  }
}
