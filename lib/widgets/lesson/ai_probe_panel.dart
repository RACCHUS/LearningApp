import 'package:flutter/material.dart';
import 'package:learning_pwa/services/content_generation/model_probe.dart';

/// The optional quick test of a learner's AI chat (master plan v2.6
/// Appendix A.1). Collapsed by default because it costs one message.
class AiProbePanel extends StatefulWidget {
  const AiProbePanel({super.key, required this.onCopy, required this.onResult});

  /// Copies text; returns whether it worked (the clipboard may be blocked).
  final Future<bool> Function(String text) onCopy;
  final ValueChanged<bool> onResult;

  @override
  State<AiProbePanel> createState() => _AiProbePanelState();
}

class _AiProbePanelState extends State<AiProbePanel> {
  final _reply = TextEditingController();
  ProbeOutcome? _outcome;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _check() {
    if (_reply.text.trim().isEmpty) return;
    final outcome = ModelProbe.check(_reply.text);
    setState(() => _outcome = outcome);
    widget.onResult(outcome == ProbeOutcome.passed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      key: const Key('manual_v2_probe'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Quick test of this AI (optional)'),
      subtitle: Text(
        'Uses one message in your AI chat. Checks the reply format only, '
        'not whether answers are right.',
        style: theme.textTheme.bodySmall,
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          ModelProbe.prompt,
          key: const Key('manual_v2_probe_prompt'),
          style: theme.textTheme.bodySmall,
        ),
        TextButton.icon(
          key: const Key('manual_v2_probe_copy'),
          onPressed: () => widget.onCopy(ModelProbe.prompt),
          icon: const Icon(Icons.copy),
          label: const Text('Copy test'),
        ),
        TextField(
          key: const Key('manual_v2_probe_reply'),
          controller: _reply,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Paste the AI's reply here",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('manual_v2_probe_check'),
          onPressed: _check,
          child: const Text('Check test reply'),
        ),
        if (_outcome != null)
          Semantics(
            liveRegion: true,
            child: Text(
              ModelProbe.describe(_outcome!),
              key: const Key('manual_v2_probe_result'),
            ),
          ),
      ],
    );
  }
}
