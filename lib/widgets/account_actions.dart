import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/display_name_provider.dart';
import 'package:learning_pwa/providers/device_avatar_provider.dart';
import 'package:learning_pwa/widgets/avatar/device_local_avatar_widget.dart';

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
      final displayName = ref.watch(displayNameProvider).valueOrNull;
      final initial = accountInitial(displayName, email);
      final label = displayName ??
          (email?.isNotEmpty == true ? email! : 'signed in');
      final colors = Theme.of(context).colorScheme;
      final avatarEnabled = ref.watch(avatarCustomizerEnabledProvider);
      final localAvatar = avatarEnabled
          ? ref.watch(avatarPersistenceProvider).avatar
          : null;

      return PopupMenuButton<String>(
        key: const Key('account-menu'),
        tooltip: 'Account: $label',
        icon: localAvatar != null
            ? DeviceLocalAvatarWidget(avatar: localAvatar, radius: 16)
            : CircleAvatar(
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
