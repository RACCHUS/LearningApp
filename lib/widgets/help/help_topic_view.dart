import 'package:flutter/material.dart';
import 'package:learning_pwa/models/help_topic.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

class HelpTopicView extends StatelessWidget {
  final HelpTopic topic;
  final VoidCallback onBack;
  final VoidCallback? onAction;

  const HelpTopicView({
    super.key,
    required this.topic,
    required this.onBack,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('All help'),
          ),
        ),
        const SizedBox(height: DesignTokens.space2),
        Text(
          topic.title,
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
        const SizedBox(height: DesignTokens.space5),
        Text(topic.body, style: theme.textTheme.bodyLarge),
        if (topic.actionLabel != null && onAction != null) ...[
          const SizedBox(height: DesignTokens.space5),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: Key('help-topic-action-${topic.id}'),
              onPressed: onAction,
              child: Text(topic.actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
