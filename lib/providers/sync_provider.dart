import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? error;
  final DateTime? lastSync;
  final int itemsSynced;

  const SyncState({
    this.status = SyncStatus.idle,
    this.error,
    this.lastSync,
    this.itemsSynced = 0,
  });

  bool get isLoading => status == SyncStatus.syncing;
  bool get hasError => status == SyncStatus.error;

  SyncState copyWith({
    SyncStatus? status,
    String? error,
    DateTime? lastSync,
    int? itemsSynced,
  }) {
    return SyncState(
      status: status ?? this.status,
      error: error,
      lastSync: lastSync ?? this.lastSync,
      itemsSynced: itemsSynced ?? this.itemsSynced,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final ProgressSyncService _syncService;
  
  SyncNotifier(this._syncService) : super(const SyncState());

  /// Sync all unsynced progress data to Supabase
  Future<void> syncData() async {
    state = state.copyWith(status: SyncStatus.syncing, error: null);
    
    try {
      // Get current user
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload local changes to server
      await _syncService.syncProgress();
      
      // Download any server changes (if needed)
      // This ensures we have the latest data
      await _syncService.downloadProgress(userId);
      
      state = state.copyWith(
        status: SyncStatus.success,
        lastSync: DateTime.now(),
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        error: e.toString(),
      );
      
      // Rethrow for caller to handle if needed
      rethrow;
    }
  }

  /// Force a full sync (upload and download)
  Future<void> forceSyncAll() async {
    await syncData();
  }

  /// Reset sync state
  void reset() {
    state = const SyncState();
  }
  
  /// Check if sync is needed based on last sync time
  bool needsSync({Duration threshold = const Duration(minutes: 5)}) {
    if (state.lastSync == null) return true;
    return DateTime.now().difference(state.lastSync!) > threshold;
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) {
    final hiveService = ref.watch(hiveServiceProvider);
    final syncService = ProgressSyncService(hiveService);
    return SyncNotifier(syncService);
  },
);
