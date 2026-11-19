import 'package:flutter/material.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:learning_pwa/widgets/lesson/ai_probe_panel.dart';

/// "Which AI chat will you use?" for the slot-based generator (master plan
/// v2.6 §5.3). Picking one is optional. The app then remembers, on this
/// device only, how that chat's replies went, and suggests a batch size.
class AiChatProfileSection extends StatelessWidget {
  const AiChatProfileSection({
    super.key,
    required this.selected,
    required this.profile,
    required this.tier,
    required this.onSelect,
    required this.onUseSuggestion,
    required this.onForget,
    required this.onCopy,
    required this.onCopyText,
    required this.onProbeResult,
  });

  final AiChatLabel? selected;

  /// The selected chat's profile, or `null` when none is selected.
  final ModelCapabilityProfile? profile;

  /// The batch size currently in use.
  final ModelSizeTier tier;
  final ValueChanged<AiChatLabel?> onSelect;
  final VoidCallback onUseSuggestion;
  final VoidCallback onForget;
  final VoidCallback onCopy;

  /// Copies the probe prompt; returns whether the clipboard allowed it.
  final Future<bool> Function(String text) onCopyText;
  final ValueChanged<bool> onProbeResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    final suggestedMode = p?.suggestedMode;
    return Column(
      key: const Key('manual_v2_ai_profile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which AI chat will you use? (optional)',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final l in AiChatLabel.values)
              ChoiceChip(
                key: Key('manual_v2_ai_${l.wire}'),
                label: Text(l.label),
                selected: selected == l,
                onSelected: (on) => onSelect(on ? l : null),
              ),
          ],
        ),
        if (p != null) ...[
          const SizedBox(height: 4),
          Text(
            '${p.explanation} Suggested size: ${p.suggestedTier.label}'
            '${suggestedMode == null ? '' : ', ${suggestedMode == ManualOutputMode.lines ? 'one item per line' : 'one JSON block'}'}.',
            key: const Key('manual_v2_ai_suggestion'),
            style: theme.textTheme.bodySmall,
          ),
          Wrap(
            spacing: 8,
            children: [
              if (p.suggestedTier != tier)
                TextButton(
                  key: const Key('manual_v2_ai_use_suggestion'),
                  onPressed: onUseSuggestion,
                  child: const Text('Use suggestion'),
                ),
              if (p.replies > 0 || p.probePassed != null) ...[
                TextButton(
                  key: const Key('manual_v2_ai_copy'),
                  onPressed: onCopy,
                  child: const Text('Copy what was learned'),
                ),
                TextButton(
                  key: const Key('manual_v2_ai_forget'),
                  onPressed: onForget,
                  child: const Text('Forget what was learned'),
                ),
              ],
            ],
          ),
          Text(
            'Only counts are kept (no reply text), on this device only.',
            style: theme.textTheme.bodySmall,
          ),
          AiProbePanel(
            key: ValueKey('probe-${p.label.wire}'),
            onCopy: onCopyText,
            onResult: onProbeResult,
          ),
        ],
      ],
    );
  }
}
