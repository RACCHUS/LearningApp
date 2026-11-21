import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/prompt_quality_provider.dart';

/// The separate opt-in for prompt-quality telemetry (plan v2.6 §5.7.6).
/// Shown only when the switch is on and this account already shares basic
/// product analytics; otherwise nothing is rendered.
class PromptQualityOptIn extends ConsumerStatefulWidget {
  const PromptQualityOptIn({super.key});

  @override
  ConsumerState<PromptQualityOptIn> createState() => _PromptQualityOptInState();
}

class _PromptQualityOptInState extends ConsumerState<PromptQualityOptIn> {
  bool _saving = false;
  String? _error;

  Future<void> _set(bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(promptQualityApiProvider).setConsent(value);
      ref.invalidate(promptQualityStatusProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your choice. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(promptQualityStatusProvider).valueOrNull;
    if (status == null || !status.showControl) return const SizedBox.shrink();
    // Turning it on needs the switch and base consent; turning it off
    // (which deletes what was shared) is always allowed.
    final canTurnOn = status.enabled && status.available;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('prompt_quality_opt_in'),
            contentPadding: EdgeInsets.zero,
            value: status.consented,
            onChanged: _saving || (!status.consented && !canTurnOn)
                ? null
                : _set,
            title: const Text('Help improve our prompts'),
            subtitle: const Text(
              'Share how each reply checked out: which AI you picked, '
              'whether it passed, error codes and counts. Never your prompts, '
              'replies, topics or answers. Turning this off deletes what was '
              'shared.',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
