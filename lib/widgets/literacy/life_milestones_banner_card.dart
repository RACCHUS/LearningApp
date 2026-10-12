import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';

/// Discovery banner card for High-Stakes US Life Milestones & Foundational Literacy
/// in the Library catalog.
class LifeMilestonesBannerCard extends StatelessWidget {
  final VoidCallback? onTap;

  const LifeMilestonesBannerCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.indigo.withValues(alpha: 0.2),
                  Colors.teal.withValues(alpha: 0.12),
                  colorScheme.surface,
                ]
              : [
                  Colors.indigo.withValues(alpha: 0.1),
                  Colors.teal.withValues(alpha: 0.08),
                  colorScheme.surface,
                ],
        ),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          onTap: onTap ?? () => context.push('/milestones'),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Provenance Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space2,
                        vertical: DesignTokens.space1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, size: 14, color: Colors.indigo),
                          SizedBox(width: DesignTokens.space1),
                          Text(
                            'AUDIO-GUIDED MILESTONES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text('🏛️ 🚗 🎓', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: DesignTokens.space3),

                Text(
                  'High-Stakes US Life Goals & Literacy',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  'Oral-first preparation for US Citizenship (2025 Test), Florida Driver\'s License, and GED® ABE Reading Bridge.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                Wrap(
                  spacing: DesignTokens.space2,
                  runSpacing: DesignTokens.space1,
                  children: [
                    _buildPill(
                      label: '🇺🇸 USCIS 2025 Test',
                      color: Colors.blue,
                      context: context,
                      route: '/milestones?category=citizenship',
                    ),
                    _buildPill(
                      label: '🚗 Florida DMV',
                      color: Colors.teal,
                      context: context,
                      route: '/milestones?category=driver',
                    ),
                    _buildPill(
                      label: '🎓 GED® Reading Bridge',
                      color: Colors.amber,
                      context: context,
                      route: '/milestones?category=ged',
                    ),
                    _buildPill(
                      label: '🛡️ Safety & Cash Skills',
                      color: Colors.orange,
                      context: context,
                      route: '/domains',
                    ),
                    _buildPill(
                      label: '🔤 ABCs & Phonics',
                      color: Colors.purple,
                      context: context,
                      route: '/literacy',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required MaterialColor color,
    required BuildContext context,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space2,
          vertical: DesignTokens.space1,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color.shade800,
          ),
        ),
      ),
    );
  }
}
