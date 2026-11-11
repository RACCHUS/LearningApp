import 'package:flutter/material.dart';
import 'package:learning_pwa/data/help_visual_guides.dart';
import 'package:learning_pwa/models/help_topic.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// The same Help topic can be read, heard, or followed through picture steps.
/// Speech is managed by the parent HelpCenter, which owns the shared narration
/// provider; this view never creates a second speech engine.
class HelpTopicView extends StatefulWidget {
  final HelpTopic topic;
  final VoidCallback onBack;
  final VoidCallback? onAction;
  final VoidCallback? onListen;
  final ValueChanged<int>? onListenStep;
  final bool autoSpeakOnOpen;
  final bool pictureFirst;

  const HelpTopicView({
    super.key,
    required this.topic,
    required this.onBack,
    this.onAction,
    this.onListen,
    this.onListenStep,
    this.autoSpeakOnOpen = false,
    this.pictureFirst = false,
  });

  @override
  State<HelpTopicView> createState() => _HelpTopicViewState();
}

class _HelpTopicViewState extends State<HelpTopicView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.autoSpeakOnOpen) widget.onListen?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = widget.topic;
    final guide = helpVisualGuideFor(topic);

    return ListView(
      key: Key('help-topic-${topic.id}'),
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space4,
        DesignTokens.space2,
        DesignTokens.space4,
        DesignTokens.space5,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('help-topic-back'),
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('All help'),
          ),
        ),
        if (widget.pictureFirst) ...[
          const SizedBox(height: DesignTokens.space2),
          Center(
            child: Icon(
              guide.icon,
              size: 64,
              color: theme.colorScheme.primary,
              semanticLabel: topic.title,
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.space2),
        Text(
          topic.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DesignTokens.space2),
        Text(
          topic.summary,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Written Help keeps its article and route action above the visual
        // tutorial so existing readable guidance remains immediately usable.
        if (!widget.pictureFirst) ...[
          const SizedBox(height: DesignTokens.space3),
          Text(topic.body, style: theme.textTheme.bodyLarge),
        ],
        if (!widget.pictureFirst &&
            topic.actionLabel != null &&
            widget.onAction != null) ...[
          const SizedBox(height: DesignTokens.space3),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: Key('help-topic-action-${topic.id}'),
              onPressed: widget.onAction,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(topic.actionLabel!),
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.space3),
        SizedBox(
          height: 58,
          child: FilledButton.tonalIcon(
            key: const Key('help-topic-listen'),
            onPressed: widget.onListen,
            icon: const Icon(Icons.volume_up_rounded, size: 30),
            label: const Text('Hear this help'),
          ),
        ),
        if (widget.pictureFirst &&
            topic.actionLabel != null &&
            widget.onAction != null) ...[
          const SizedBox(height: DesignTokens.space3),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: Key('help-topic-action-${topic.id}'),
              onPressed: widget.onAction,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(topic.actionLabel!),
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.space3),
        ...guide.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: DesignTokens.space2),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space2),
              child: Row(
                children: [
                  Icon(step.icon, size: 38, color: theme.colorScheme.primary),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          step.spokenInstruction,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('help-topic-step-listen-$index'),
                    onPressed: widget.onListenStep == null
                        ? null
                        : () => widget.onListenStep!(index),
                    tooltip: 'Hear this step',
                    icon: const Icon(Icons.volume_up_rounded),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (widget.pictureFirst) ...[
          const SizedBox(height: DesignTokens.space3),
          Text(topic.body, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }
}
