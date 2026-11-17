import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/community_qa_provider.dart';
import 'package:learning_pwa/providers/display_name_provider.dart';
import 'package:learning_pwa/providers/device_avatar_provider.dart';
import 'package:learning_pwa/widgets/avatar/avatar_customizer_sheet.dart';
import 'package:learning_pwa/widgets/avatar/device_local_avatar_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final displayName = ref.watch(displayNameProvider).valueOrNull;
    final avatarService = watchAccountAvatar(ref);
    // learning.educator_profiles: permanent accounts only (anonymous users
    // cannot own a contributor profile).
    final contributorProfileUserId =
        ref.watch(educatorProfilesFeatureEnabledProvider) &&
                authState is AuthSuccess &&
                !authState.user.isAnonymous
            ? authState.user.id
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: authState is AuthSuccess
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User info section
                Center(
                  child: Column(
                    children: [
                      if (avatarService != null)
                        DeviceLocalAvatarWidget(
                          key: const Key('profile-local-avatar'),
                          avatar: avatarService.avatar,
                          radius: 50,
                          onTap: () => AvatarCustomizerSheet.show(
                            context,
                            service: avatarService,
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            accountInitial(displayName, authState.user.email) ??
                                '?',
                            style: const TextStyle(
                                fontSize: 40, color: Colors.white),
                          ),
                        ),
                      if (avatarService != null)
                        TextButton.icon(
                          key: const Key('profile-customize-avatar'),
                          onPressed: () => AvatarCustomizerSheet.show(
                            context,
                            service: avatarService,
                          ),
                          icon: const Icon(Icons.palette_outlined),
                          label: const Text('Customize avatar'),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayName ??
                                  authState.user.email ??
                                  'No email available',
                              key: const Key('profile-headline'),
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            key: const Key('profile-edit-display-name'),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: displayName == null
                                ? 'Add display name'
                                : 'Edit display name',
                            onPressed: () => DisplayNameDialog.show(
                              context,
                              userId: authState.user.id,
                              initialName: displayName,
                            ),
                          ),
                        ],
                      ),
                      if (displayName != null &&
                          (authState.user.email?.isNotEmpty ?? false))
                        Text(
                          authState.user.email!,
                          key: const Key('profile-email'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Quick links
                const Text(
                  'Learning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.psychology, color: Colors.purple),
                        title: const Text('My Skills'),
                        subtitle: const Text('View your skill levels'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/skills'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.route, color: Colors.blue),
                        title: const Text('My Career Paths'),
                        subtitle: const Text('Track your career progress'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/my-careers'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.bar_chart, color: Colors.green),
                        title: const Text('Progress Dashboard'),
                        subtitle: const Text('View learning analytics'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/progress'),
                      ),
                      if (contributorProfileUserId != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          key: const Key('profile-contributor-profile'),
                          leading: const Icon(Icons.school_outlined, color: Colors.teal),
                          title: const Text('Contributor profile'),
                          subtitle: const Text('How you appear when you answer questions'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.push('/educators/$contributorProfileUserId'),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Sign out
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authProvider.notifier).signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please sign in to view your profile'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.go('/login');
                    },
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ),
    );
  }
}

class DisplayNameDialog extends ConsumerStatefulWidget {
  const DisplayNameDialog({super.key, required this.userId, this.initialName});

  final String userId;
  final String? initialName;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    String? initialName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          DisplayNameDialog(userId: userId, initialName: initialName),
    );
  }

  @override
  ConsumerState<DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends ConsumerState<DisplayNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = validateDisplayName(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(displayNameRepositoryProvider)
          .save(widget.userId, _controller.text);
      ref.invalidate(displayNameProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save. Check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Display name'),
      content: TextField(
        key: const Key('display-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: displayNameMaxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Name to show in the app',
          helperText:
              '$displayNameMinLength-$displayNameMaxLength characters. '
              "This doesn't change how you sign in.",
          helperMaxLines: 2,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('display-name-save'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
