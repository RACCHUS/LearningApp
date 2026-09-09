import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// First-run state. Exactly two options — no carousel, no featured grid,
/// no onboarding quiz.
///
/// Neither option may terminate in an empty screen: when the catalog is empty
/// the two swap emphasis so the recommended path always leads somewhere
/// (spec C2).
class LearnZeroState extends StatelessWidget {
  final bool catalogEmpty;

  const LearnZeroState({super.key, this.catalogEmpty = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final browse = _ZeroOption(
      key: const Key('zero-browse'),
      label: 'Browse courses',
      icon: Icons.explore_outlined,
      subtitle: catalogEmpty ? 'Nothing available yet' : null,
      enabled: !catalogEmpty,
      onTap: () => context.go('/library'),
    );

    final create = _ZeroOption(
      key: const Key('zero-create'),
      label: 'Import or create content',
      icon: Icons.add_circle_outline,
      onTap: () => context.push('/create-lesson'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DesignTokens.space5),
        Text('What do you want to learn?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: DesignTokens.space5),
        if (catalogEmpty) ...[create, browse] else ...[browse, create],
      ],
    );
  }
}

class _ZeroOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ZeroOption({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
