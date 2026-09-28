import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_context.dart';
import '../../providers/learning_context_provider.dart';
import '../../theme/design_tokens.dart';

class StartLearningScreen extends ConsumerStatefulWidget {
  final String title;
  final ContextRootType rootType;
  final String rootId;
  final String? emoji;
  final String? targetVersionId;

  const StartLearningScreen({
    super.key,
    required this.title,
    required this.rootType,
    required this.rootId,
    this.emoji,
    this.targetVersionId,
  });

  @override
  ConsumerState<StartLearningScreen> createState() => _StartLearningScreenState();
}

class _StartLearningScreenState extends ConsumerState<StartLearningScreen> {
  ScopeMode _scopeMode = ScopeMode.coreAndPrerequisites;
  bool _includeCalculations = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Configure ${widget.title}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize Learning Scope',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'Choose what material to include in your daily learning and review loops.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),

            // Scope Mode options
            Text(
              'Scope Coverage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            RadioListTile<ScopeMode>(
              value: ScopeMode.coreAndPrerequisites,
              groupValue: _scopeMode,
              title: const Text('Core + Prerequisites (Recommended)'),
              subtitle: const Text('Includes foundational concepts required for mastery.'),
              onChanged: (val) => setState(() => _scopeMode = val!),
            ),
            RadioListTile<ScopeMode>(
              value: ScopeMode.coreOnly,
              groupValue: _scopeMode,
              title: const Text('Core Requirements Only'),
              subtitle: const Text('Exclusively targets exam domains without foundational refresher items.'),
              onChanged: (val) => setState(() => _scopeMode = val!),
            ),
            RadioListTile<ScopeMode>(
              value: ScopeMode.custom,
              groupValue: _scopeMode,
              title: const Text('Custom Configuration'),
              subtitle: const Text('Tailor calculation intensity and topic filters.'),
              onChanged: (val) => setState(() => _scopeMode = val!),
            ),

            if (_scopeMode == ScopeMode.custom) ...[
              const SizedBox(height: DesignTokens.space3),
              SwitchListTile(
                title: const Text('Include Mathematical Calculations'),
                subtitle: const Text('Practice formula-based questions and numerical problems.'),
                value: _includeCalculations,
                onChanged: (val) => setState(() => _includeCalculations = val),
              ),
            ],

            const SizedBox(height: DesignTokens.space5),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('start-learning-confirm-button'),
                onPressed: () async {
                  final userId = ref.read(learnerIdProvider);

                  await ref.read(learningContextsProvider.notifier).createOrSwitch(
                        userId: userId,
                        label: widget.title,
                        rootType: widget.rootType,
                        rootId: widget.rootId,
                        emoji: widget.emoji,
                        targetVersionId: widget.targetVersionId,
                        scopeMode: _scopeMode,
                        scopeConfig: {
                          'includeCalculations': _includeCalculations,
                        },
                      );

                  if (context.mounted) {
                    context.go('/learn');
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Start Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
