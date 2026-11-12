import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/widgets/learning_support/bridge_check_card.dart';

/// "Learn more outside LearningApp" for one Bridge (master plan v2.6 §9,
/// PR-E): a link-only section pointer, a focus note in our own words and
/// independent checks. Reading outside is never tracked or counted as
/// progress, and the learner's place in the Bridge is kept while away.
///
/// Renders nothing unless `content.external_companion` is on and a valid
/// companion exists for [bridgeId].
class ExternalCompanionSection extends ConsumerWidget {
  const ExternalCompanionSection({super.key, required this.bridgeId});

  final String bridgeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(externalCompanionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final companion = ref
        .watch(externalCompanionLibraryProvider)
        .valueOrNull
        ?.forBridge(bridgeId);
    if (companion == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final r = companion.resource;
    final uri = Uri.parse(r.url);

    Future<void> open() async {
      var ok = false;
      try {
        ok = await ref.read(externalLinkLauncherProvider)(uri);
      } catch (_) {}
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't open the link. You can copy it from below, or keep "
              'going here.',
            ),
          ),
        );
      }
    }

    return Column(
      key: Key('external-companion-$bridgeId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              'Learn more outside LearningApp',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.publisher}: ${r.title}'
                  '${r.section == null ? '' : ', ${r.section}'}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.access.label} · link checked '
                  '${r.lastCheckedAt.toIso8601String().substring(0, 10)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'What to look for: ${companion.focusNote}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: Key('external-companion-open-$bridgeId'),
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open (leaves LearningApp)'),
                ),
                SelectableText(r.url, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  'Your place here is kept. Reading outside is not tracked '
                  'or counted as progress.',
                  key: Key('external-companion-not-tracked-$bridgeId'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Text(
          'Check yourself after reading (practice only):',
          style: theme.textTheme.bodyMedium,
        ),
        for (final (i, c) in companion.checks.indexed)
          BridgeCheckCard(check: c, index: i),
      ],
    );
  }
}
