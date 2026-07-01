import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
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
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          (authState.user.email?.isNotEmpty ?? false)
                              ? authState.user.email![0].toUpperCase()
                              : '?',
                          style:
                              const TextStyle(fontSize: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        authState.user.email ?? 'No email available',
                        style: Theme.of(context).textTheme.titleLarge,
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
