import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/prompt_cart.dart';

/// The prompt cart (master plan v2.6 §5.5 M-06): a goal's missing pieces,
/// most reusable first, bundled into the fewest chats with an "about N
/// messages" estimate for the AI size the learner picks. Each chat opens the
/// manual generator with its topics filled in; the learner still copies and
/// pastes in their own chat, and nothing is sent anywhere from here.
class PromptCartScreen extends StatefulWidget {
  const PromptCartScreen({
    super.key,
    required this.goalTitle,
    required this.needs,
  });

  final String goalTitle;
  final List<CoverageNeed> needs;

  @override
  State<PromptCartScreen> createState() => _PromptCartScreenState();
}

class _PromptCartScreenState extends State<PromptCartScreen> {
  late final Set<String> _chosen = {for (final n in widget.needs) n.row.objectiveId};
  ModelSizeTier _tier = ModelSizeTier.compact;
  final Set<int> _started = {};

  List<CoverageNeed> get _ordered => PromptCart.ordered(widget.needs);

  void _start(int index, PromptCartBatch batch) {
    setState(() => _started.add(index));
    final uri = Uri(
      path: '/manual-generation-v2',
      queryParameters: {
        'subject': widget.goalTitle,
        'ideas': batch.ideas.join('\n'),
      },
    );
    GoRouter.of(context).push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = [for (final n in _ordered) if (_chosen.contains(n.row.objectiveId)) n];
    final plan = PromptCart.plan(chosen, tier: _tier);

    return Scaffold(
      appBar: AppBar(title: const Text('Make missing pieces with my AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Missing from ${widget.goalTitle}, most useful first (topics many goals '
            'share, and ones other learners asked for). Pick what to make, then work '
            'through the chats in your own AI. What you make stays private.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text('How big is your AI chat?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<ModelSizeTier>(
            key: const Key('prompt-cart-tier'),
            segments: [
              for (final t in ModelSizeTier.values) ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_tier},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tier = s.first),
          ),
          const SizedBox(height: 12),
          for (final n in _ordered)
            CheckboxListTile(
              key: Key('prompt-cart-need-${n.row.objectiveId}'),
              contentPadding: EdgeInsets.zero,
              value: _chosen.contains(n.row.objectiveId),
              onChanged: (v) => setState(() => v == true
                  ? _chosen.add(n.row.objectiveId)
                  : _chosen.remove(n.row.objectiveId)),
              title: Text(n.row.code == null ? n.row.title : '${n.row.code} ${n.row.title}'),
              subtitle: Text('Missing: ${n.missingLabel}'),
            ),
          const Divider(),
          Text(
            plan.isEmpty
                ? 'Pick at least one topic.'
                : 'About ${plan.messages} message${plan.messages == 1 ? '' : 's'} '
                    'in ${plan.chats} chat${plan.chats == 1 ? '' : 's'}. '
                    'An estimate for a ${_tier.label.toLowerCase()} chat; replies that need '
                    'fixing add more.',
            key: const Key('prompt-cart-estimate'),
            style: theme.textTheme.titleSmall,
          ),
          for (final (i, b) in plan.batches.indexed)
            Card(
              key: Key('prompt-cart-batch-$i'),
              child: ListTile(
                title: Text('Chat ${i + 1}: ${b.ideas.join(', ')}'),
                subtitle: Text('About ${b.messages} message${b.messages == 1 ? '' : 's'}'),
                trailing: _started.contains(i)
                    ? const Text('Started')
                    : FilledButton.tonal(
                        key: Key('prompt-cart-start-$i'),
                        onPressed: () => _start(i, b),
                        child: const Text('Start'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
