import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? error;
  final DateTime? lastSync;

  const SyncState({
    this.status = SyncStatus.idle,
    this.error,
    this.lastSync,
  });

  bool get isLoading => status == SyncStatus.syncing;
  bool get hasError => status == SyncStatus.error;

  SyncState copyWith({
    SyncStatus? status,
    String? error,
    DateTime? lastSync,
  }) {
    return SyncState(
      status: status ?? this.status,
      error: error ?? this.error,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState());

  Future<void> syncData() async {
    state = state.copyWith(status: SyncStatus.syncing, error: null);
    
    try {
      // TODO: Implement actual sync logic
      await Future.delayed(const Duration(seconds: 2)); // Simulate sync
      
      state = state.copyWith(
        status: SyncStatus.success,
        lastSync: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const SyncState();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(),
);
