import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/achievement.dart';
import 'package:learning_pwa/models/user_xp.dart';
import 'package:learning_pwa/providers/motivation_preferences_provider.dart';
import 'package:learning_pwa/providers/xp_achievements_provider.dart';
import 'package:learning_pwa/services/xp_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// XP, level and achievements for Progress §4 (UI_ARCHITECTURE_LOCKED.md §9).
///
/// [showXp] and [showLevels] mirror the learner's motivation switches. XP is
/// activity, not knowledge, so nothing here is phrased as mastery.
class MotivationXpRows extends ConsumerWidget {
  const MotivationXpRows({
    super.key,
    required this.showXp,
    required this.showLevels,
  });

  final bool showXp;
  final bool showLevels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showXp && !showLevels) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!ref.watch(xpAchievementsEnabledProvider)) {
      return Text('XP and levels are not tracked yet.', style: muted);
    }

    final summary = ref.watch(userXpSummaryProvider);
    return summary.when(
      loading: () => Text('Loading XP…', style: muted),
      error: (_, __) => Text('XP is unavailable right now.', style: muted),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showXp) _Row(label: 'Total XP', value: '${s.totalXp}'),
          if (showLevels) ...[
            _Row(label: 'Level', value: '${s.level}'),
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              child: LinearProgressIndicator(
                value: s.progressToNextLevel,
                minHeight: 6,
                semanticsLabel: 'Progress to level ${s.level + 1}',
              ),
            ),
            const SizedBox(height: DesignTokens.space1),
            Text('${s.xpToNextLevel} XP to level ${s.level + 1}', style: muted),
            const SizedBox(height: DesignTokens.space3),
          ],
          if (s.totalXp == 0)
            Text('Finish a lesson or a review session to earn XP.',
                style: muted),
          if (showXp) const _AchievementList(),
        ],
      ),
    );
  }
}

class _AchievementList extends ConsumerWidget {
  const _AchievementList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final earned = ref.watch(userAchievementsProvider).valueOrNull ?? const [];
    final known = [
      for (final record in earned)
        if (AchievementCatalog.byKey(record.key) case final def?) def,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DesignTokens.space3),
        Text('Achievements', style: theme.textTheme.titleSmall),
        const SizedBox(height: DesignTokens.space1),
        if (known.isEmpty)
          Text(
            'None yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final def in known)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(def.icon, color: theme.colorScheme.primary),
              title: Text(def.title),
              subtitle: Text(def.description),
            ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// XP line for an end-of-session summary. Renders nothing when the claim was
/// refused or the learner has XP switched off; never shows "+0 XP".
class SessionXpSummary extends ConsumerWidget {
  const SessionXpSummary({super.key, required this.result});

  final ActivityXpResult? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(motivationPreferencesProvider);
    final r = result;
    if (r == null || !prefs.xp) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final achievements = [
      for (final key in r.newAchievements)
        if (AchievementCatalog.byKey(key) case final def?) def,
    ];
    final leveledUp = prefs.levels &&
        r.awarded &&
        XpConstants.levelFromXp(r.totalXp) >
            XpConstants.levelFromXp(r.totalXp - r.awardedXp);
    if (!r.awarded && achievements.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('session-xp-summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.awarded)
          Text('+${r.awardedXp} XP',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        if (leveledUp)
          Text('Level ${XpConstants.levelFromXp(r.totalXp)} reached',
              style: theme.textTheme.bodyMedium),
        if (prefs.celebrations)
          for (final def in achievements)
            Padding(
              padding: const EdgeInsets.only(top: DesignTokens.space1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(def.icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: DesignTokens.space2),
                  Flexible(child: Text('Achievement: ${def.title}')),
                ],
              ),
            ),
      ],
    );
  }
}
