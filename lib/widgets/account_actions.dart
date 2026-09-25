import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';

/// Account access without hiding signed-out settings behind a login screen.
class AccountActions extends ConsumerWidget {
  const AccountActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is AuthSuccess && !authState.user.isAnonymous
        ? authState.user
        : null;

    if (user != null) {
      final email = user.email?.trim();
      final initial = email != null && email.isNotEmpty
          ? email[0].toUpperCase()
          : null;
      final colors = Theme.of(context).colorScheme;

      return PopupMenuButton<String>(
        key: const Key('account-menu'),
        tooltip: 'Account: ${email?.isNotEmpty == true ? email : 'signed in'}',
        icon: CircleAvatar(
          radius: 16,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: initial == null
              ? const Icon(Icons.person, size: 18)
              : Text(initial),
        ),
        onSelected: (route) => context.push(route),
        itemBuilder: (context) => const [
          PopupMenuItem(value: '/profile', child: Text('Profile')),
          PopupMenuItem(value: '/settings', child: Text('Settings')),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => context.push('/login'),
          child: const Text('Log in'),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}
