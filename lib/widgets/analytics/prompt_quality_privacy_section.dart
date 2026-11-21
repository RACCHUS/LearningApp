import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/prompt_quality_provider.dart';

/// Prompt-quality sharing on the analytics privacy screen: what it is,
/// whether it is on, how many rows are stored, and withdraw-and-delete and
/// export controls that work even while the feature switch is off.
class PromptQualityPrivacySection extends ConsumerStatefulWidget {
  const PromptQualityPrivacySection({super.key});

  @override
  ConsumerState<PromptQualityPrivacySection> createState() =>
      _PromptQualityPrivacySectionState();
}

class _PromptQualityPrivacySectionState
    extends ConsumerState<PromptQualityPrivacySection> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } catch (_) {
      if (mounted) setState(() => _message = 'That did not work. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(promptQualityStatusProvider).valueOrNull;
    // Nothing to show or control: the feature is off and nothing is stored.
    if (status == null ||
        (!status.enabled && !status.consented && status.storedEvents == 0)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final api = ref.read(promptQualityApiProvider);
    return Card(
      key: const Key('prompt_quality_privacy_section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prompt-quality sharing', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'A separate choice from the analytics above, offered in the lesson '
              'generator. If you turn it on, each AI reply you check there shares '
              'only which AI you picked, whether the reply passed, error codes and '
              'counts. Never your prompts, replies, topics or answers. Rows are '
              'kept for up to 90 days.',
            ),
            const SizedBox(height: 8),
            Text(
              status.consented
                  ? 'On: ${status.storedEvents} row(s) stored.'
                  : status.storedEvents > 0
                      ? 'Off: ${status.storedEvents} row(s) still stored.'
                      : 'Off: nothing stored.',
              key: const Key('prompt_quality_privacy_status'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('prompt_quality_withdraw'),
                  onPressed: _busy || (!status.consented && status.storedEvents == 0)
                      ? null
                      : () => _run(() async {
                            await api.setConsent(false);
                            ref.invalidate(promptQualityStatusProvider);
                            return 'Turned off. Everything shared was deleted.';
                          }),
                  child: const Text('Turn off and delete'),
                ),
                OutlinedButton(
                  key: const Key('prompt_quality_export'),
                  onPressed: _busy || status.storedEvents == 0
                      ? null
                      : () => _run(() async {
                            await Clipboard.setData(
                              ClipboardData(text: await api.export()),
                            );
                            return 'Your prompt-quality rows were copied to the clipboard.';
                          }),
                  child: const Text('Export my rows'),
                ),
              ],
            ),
            if (_message case final message?) ...[
              const SizedBox(height: 8),
              Text(message),
            ],
          ],
        ),
      ),
    );
  }
}
