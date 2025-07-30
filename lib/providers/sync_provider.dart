import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/connectivity_service.dart';
import 'package:learning_pwa/services/data_sync_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final syncProvider = StateNotifierProvider<SyncNotifier, AsyncValue<bool>>((ref) {
  final supabase = Supabase.instance.client;
  final hiveService = ref.watch(hiveServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  
  return SyncNotifier(
    supabase: supabase,
    hiveService: hiveService,
    connectivityService: connectivityService,
    userId: supabase.auth.currentUser?.id ?? '',
  )..init();
});

class SyncNotifier extends StateNotifier<AsyncValue<bool>> {
  final SupabaseClient supabase;
  final HiveService hiveService;
  final ConnectivityService connectivityService;
  final String userId;
  
  StreamSubscription<bool>? _connectivitySubscription;
  
  SyncNotifier({
    required this.supabase,
    required this.hiveService,
    required this.connectivityService,
    required this.userId,
  }) : super(const AsyncValue.data(false));
  
  void init() {
    // Initial sync if online
    _checkAndSync();
    
    // Listen for connectivity changes
    _connectivitySubscription = connectivityService.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        _checkAndSync();
      }
    });
  }
  
  Future<void> _checkAndSync() async {
    try {
      final isConnected = await connectivityService.isConnected;
      if (isConnected) {
        await syncData();
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> syncData() async {
    try {
      state = const AsyncValue.loading();
      
      final syncService = DataSyncService(
        supabase: supabase,
        hiveService: hiveService,
        userId: userId,
      );
      
      await syncService.syncAllData();
      state = const AsyncValue.data(true);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Widget to show sync status and error messages
class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    
    return syncState.when(
      data: (_) => const SizedBox.shrink(),
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) {
        // Only show error if we're online
        return ref.watch(connectivityProvider) 
            ? Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red,
                child: Text(
                  'Sync error: ${error.toString()}',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }
}
