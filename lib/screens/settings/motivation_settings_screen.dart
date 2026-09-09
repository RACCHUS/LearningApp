import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/motivation_preferences_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// One question, then per-mechanic control for anyone who wants it.
///
/// Streaks and daily goals stay opt-in under both presets: they are the two
/// mechanics that manufacture debt, and debt framing must be chosen, never
/// assigned. Nothing here renders on Learn under any preset.
class MotivationSettingsScreen extends ConsumerWidget {
  const MotivationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(motivationPreferencesProvider);
    final notifier = ref.read(motivationPreferencesProvider.notifier);
    final theme = Theme.of(context);

    final isMinimal = _matches(prefs, MotivationPreferences.minimal);
    final isStandard = _matches(prefs, MotivationPreferences.standard);

    return Scaffold(
      appBar: AppBar(title: const Text('Motivation')),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          Text(
            'Would you like motivational features?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: DesignTokens.space3),
          RadioListTile<MotivationPreset>(
            key: const Key('preset-minimal'),
            value: MotivationPreset.minimal,
            groupValue: isMinimal
                ? MotivationPreset.minimal
                : (isStandard ? MotivationPreset.standard : null),
            title: const Text('Minimal'),
            subtitle: const Text('Quiet. Completion confirmation only.'),
            onChanged: (_) => notifier.applyPreset(MotivationPreset.minimal),
          ),
          RadioListTile<MotivationPreset>(
            key: const Key('preset-standard'),
            value: MotivationPreset.standard,
            groupValue: isMinimal
                ? MotivationPreset.minimal
                : (isStandard ? MotivationPreset.standard : null),
            title: const Text('Standard'),
            subtitle: const Text('XP, levels and celebrations in Progress.'),
            onChanged: (_) => notifier.applyPreset(MotivationPreset.standard),
          ),
          const Divider(height: DesignTokens.space6),
          Text('Fine-tune', style: theme.textTheme.titleMedium),
          const SizedBox(height: DesignTokens.space2),
          SwitchListTile(
            key: const Key('toggle-xp'),
            title: const Text('XP'),
            subtitle: const Text('Shown in Progress and session summaries'),
            value: prefs.xp,
            onChanged: (v) => notifier.update(prefs.copyWith(xp: v)),
          ),
          SwitchListTile(
            key: const Key('toggle-levels'),
            title: const Text('Levels'),
            subtitle: const Text('Shown in Progress only'),
            value: prefs.levels,
            onChanged: (v) => notifier.update(prefs.copyWith(levels: v)),
          ),
          SwitchListTile(
            key: const Key('toggle-celebrations'),
            title: const Text('Celebrations'),
            subtitle: const Text('Milestone moments, never mid-lesson'),
            value: prefs.celebrations,
            onChanged: (v) => notifier.update(prefs.copyWith(celebrations: v)),
          ),
          SwitchListTile(
            key: const Key('toggle-streaks'),
            title: const Text('Streaks'),
            subtitle: const Text('Off by default'),
            value: prefs.streaks,
            onChanged: (v) => notifier.update(prefs.copyWith(streaks: v)),
          ),
          SwitchListTile(
            key: const Key('toggle-daily-goal'),
            title: const Text('Daily goal'),
            subtitle: const Text('Off by default'),
            value: prefs.dailyGoal,
            onChanged: (v) => notifier.update(prefs.copyWith(dailyGoal: v)),
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            'None of these appear on Learn. They live in Progress and on '
            'session summaries.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static bool _matches(MotivationPreferences a, MotivationPreferences b) {
    return a.xp == b.xp &&
        a.levels == b.levels &&
        a.streaks == b.streaks &&
        a.celebrations == b.celebrations &&
        a.dailyGoal == b.dailyGoal;
  }
}
