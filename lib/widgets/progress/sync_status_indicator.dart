import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/sync_provider.dart';

/// Sync status indicator widget
/// 
/// Shows sync progress, errors, and provides retry functionality
/// for the progress dashboard.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    // Show sync status at the bottom of the screen
    if (syncState.isLoading) {
      return const LinearProgressIndicator();
    } else if (syncState.hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.red[100],
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sync error: ${syncState.error}'.split('\n').first,
                style: const TextStyle(color: Colors.red),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => ref.read(syncProvider.notifier).syncData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // No sync status to show
    return const SizedBox.shrink();
  }
}
