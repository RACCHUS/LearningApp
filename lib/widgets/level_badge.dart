import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/user_xp.dart';
import 'package:learning_pwa/services/xp_service.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';

class _TierPalette {
  static Color color(LevelTier tier) {
    switch (tier) {
      case LevelTier.bronze:
        return const Color(0xFFCD7F32);
      case LevelTier.silver:
        return const Color(0xFFC0C0C0);
      case LevelTier.gold:
        return const Color(0xFFFFD700);
      case LevelTier.platinum:
        return const Color(0xFFE5E4E2);
      case LevelTier.diamond:
        return const Color(0xFF00CED1);
      case LevelTier.master:
        return const Color(0xFF9400D3);
    }
  }

  static LinearGradient gradient(LevelTier tier) {
    switch (tier) {
      case LevelTier.bronze:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFFA0522D)],
        );
      case LevelTier.silver:
        return const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
        );
      case LevelTier.gold:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
        );
      case LevelTier.platinum:
        return const LinearGradient(
          colors: [Color(0xFFE5E4E2), Color(0xFF8C8C8C)],
        );
      case LevelTier.diamond:
        return const LinearGradient(
          colors: [Color(0xFF00CED1), Color(0xFF20B2AA)],
        );
      case LevelTier.master:
        return const LinearGradient(
          colors: [Color(0xFF9400D3), Color(0xFF4B0082)],
        );
    }
  }

  static LinearGradient diagonalGradient(LevelTier tier) {
    final base = gradient(tier);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: base.colors,
    );
  }
}

/// Compact level badge for header display
class LevelBadge extends ConsumerWidget {
  final VoidCallback? onTap;

  const LevelBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpSummaryAsync = ref.watch(userXpSummaryProvider);
    final theme = Theme.of(context);

    return xpSummaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final tier = LevelTier.fromLevel(summary.level);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: _TierPalette.gradient(tier),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _TierPalette.color(tier).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars,
                  size: 16,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Lv ${summary.level}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

/// Full XP progress card for profile/sidebar
class XpProgressCard extends ConsumerWidget {
  const XpProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpSummaryAsync = ref.watch(userXpSummaryProvider);
    final theme = Theme.of(context);

    return xpSummaryAsync.when(
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final tier = LevelTier.fromLevel(summary.level);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LevelIcon(tier: tier, level: summary.level),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level ${summary.level}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            tier.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _TierPalette.color(tier),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${summary.totalXp} XP',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${summary.xpToNextLevel} to next',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.progressToNextLevel,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(_TierPalette.color(tier)),
                  ),
                ),
                const SizedBox(height: 12),
                // Today/Week stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      label: 'Today',
                      value: '+${summary.xpEarnedToday} XP',
                      theme: theme,
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    _StatColumn(
                      label: 'This Week',
                      value: '+${summary.xpEarnedThisWeek} XP',
                      theme: theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelIcon extends StatelessWidget {
  final LevelTier tier;
  final int level;

  const _LevelIcon({required this.tier, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: _TierPalette.diagonalGradient(tier),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _TierPalette.color(tier).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          level.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = theme.extension<SemanticColors>();
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: semantic?.success ?? theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// XP gain popup animation
class XpGainPopup extends StatefulWidget {
  final int xpAmount;
  final String? label;
  final VoidCallback? onComplete;

  const XpGainPopup({
    super.key,
    required this.xpAmount,
    this.label,
    this.onComplete,
  });

  @override
  State<XpGainPopup> createState() => _XpGainPopupState();
}

class _XpGainPopupState extends State<XpGainPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 40,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_controller);

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .extension<SemanticColors>()!
                  .success,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .extension<SemanticColors>()!
                      .success
                      .withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bolt,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${widget.xpAmount} XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Level up celebration dialog
class LevelUpDialog extends StatelessWidget {
  final int newLevel;
  final LevelTier tier;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: _TierPalette.gradient(tier),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _TierPalette.color(tier).withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                newLevel.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Level Up!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You reached Level $newLevel',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            tier.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _TierPalette.color(tier),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }
}
