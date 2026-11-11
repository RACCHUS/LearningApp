import 'package:flutter/material.dart';
import 'package:learning_pwa/data/help_visual_guides.dart';
import 'package:learning_pwa/models/help_topic.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// A scrollable, non-text-search route into the same HelpTopic catalog.
class HelpVisualDirectory extends StatelessWidget {
  final List<HelpTopic> topics;
  final ValueChanged<HelpTopic> onOpen;
  final ValueChanged<HelpTopic> onListen;

  const HelpVisualDirectory({
    super.key,
    required this.topics,
    required this.onOpen,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      key: const Key('help-visual-directory'),
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space3,
        DesignTokens.space3,
        DesignTokens.space3,
        DesignTokens.space5,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 216,
      ),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        final icon = helpIconForTopic(topic);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: InkWell(
                  key: Key('help-picture-open-${topic.id}'),
                  onTap: () => onOpen(topic),
                  child: Semantics(
                    button: true,
                    label: 'Open help: ${topic.title}',
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(DesignTokens.space2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 48,
                                color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            Text(
                              topic.title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: TextButton.icon(
                  key: Key('help-picture-listen-${topic.id}'),
                  onPressed: () => onListen(topic),
                  icon: const Icon(Icons.volume_up_rounded, size: 28),
                  label: const Text('Listen'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
