import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/sync_provider.dart';

void main() {
  group('SyncState Tests', () {
    test('initial state should be idle', () {
      const state = SyncState();
      
      expect(state.status, SyncStatus.idle);
      expect(state.error, isNull);
      expect(state.lastSync, isNull);
      expect(state.itemsSynced, 0);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
    });

    test('copyWith should update specified fields', () {
      const state = SyncState();
      
      final newState = state.copyWith(
        status: SyncStatus.syncing,
        itemsSynced: 5,
      );
      
      expect(newState.status, SyncStatus.syncing);
      expect(newState.itemsSynced, 5);
      expect(newState.error, isNull); // Unchanged
      expect(newState.lastSync, isNull); // Unchanged
    });

    test('copyWith should clear error when set to null', () {
      const state = SyncState(
        status: SyncStatus.error,
        error: 'Test error',
      );
      
      final newState = state.copyWith(
        status: SyncStatus.syncing,
        error: null,
      );
      
      expect(newState.error, isNull);
      expect(newState.status, SyncStatus.syncing);
    });

    test('isLoading should be true when syncing', () {
      const state = SyncState(status: SyncStatus.syncing);
      expect(state.isLoading, isTrue);
    });

    test('isLoading should be false when idle', () {
      const state = SyncState(status: SyncStatus.idle);
      expect(state.isLoading, isFalse);
    });

    test('hasError should be true when status is error', () {
      const state = SyncState(status: SyncStatus.error, error: 'Test error');
      expect(state.hasError, isTrue);
    });

    test('hasError should be false when status is not error', () {
      const state = SyncState(status: SyncStatus.success);
      expect(state.hasError, isFalse);
    });

    test('copyWith should handle lastSync correctly', () {
      const state = SyncState();
      final now = DateTime.now();
      
      final newState = state.copyWith(
        lastSync: now,
        status: SyncStatus.success,
      );
      
      expect(newState.lastSync, now);
      expect(newState.status, SyncStatus.success);
    });

    test('should handle all SyncStatus values', () {
      for (final status in SyncStatus.values) {
        final state = SyncState(status: status);
        expect(state.status, status);
      }
    });

    test('should handle multiple copyWith calls', () {
      const initialState = SyncState();
      
      final state1 = initialState.copyWith(status: SyncStatus.syncing);
      expect(state1.status, SyncStatus.syncing);
      
      final state2 = state1.copyWith(itemsSynced: 10);
      expect(state2.status, SyncStatus.syncing);
      expect(state2.itemsSynced, 10);
      
      final state3 = state2.copyWith(status: SyncStatus.success);
      expect(state3.status, SyncStatus.success);
      expect(state3.itemsSynced, 10);
    });
  });

  group('SyncStatus Enum Tests', () {
    test('should have all expected values', () {
      expect(SyncStatus.values.length, 4);
      expect(SyncStatus.values, contains(SyncStatus.idle));
      expect(SyncStatus.values, contains(SyncStatus.syncing));
      expect(SyncStatus.values, contains(SyncStatus.success));
      expect(SyncStatus.values, contains(SyncStatus.error));
    });

    test('status names should be correct', () {
      expect(SyncStatus.idle.name, 'idle');
      expect(SyncStatus.syncing.name, 'syncing');
      expect(SyncStatus.success.name, 'success');
      expect(SyncStatus.error.name, 'error');
    });
  });

  group('SyncState Edge Cases', () {
    test('should handle zero items synced', () {
      const state = SyncState(
        status: SyncStatus.success,
        itemsSynced: 0,
      );
      
      expect(state.itemsSynced, 0);
      expect(state.status, SyncStatus.success);
    });

    test('should handle large item counts', () {
      const state = SyncState(
        status: SyncStatus.success,
        itemsSynced: 1000000,
      );
      
      expect(state.itemsSynced, 1000000);
    });

    test('should handle negative item counts', () {
      const state = SyncState(
        status: SyncStatus.error,
        itemsSynced: -1,
      );
      
      expect(state.itemsSynced, -1);
    });

    test('should handle very old lastSync dates', () {
      final oldDate = DateTime(2000, 1, 1);
      final state = SyncState(lastSync: oldDate);
      
      expect(state.lastSync, oldDate);
    });

    test('should handle future lastSync dates', () {
      final futureDate = DateTime(2030, 12, 31);
      final state = SyncState(lastSync: futureDate);
      
      expect(state.lastSync, futureDate);
    });

    test('should handle empty error message', () {
      const state = SyncState(
        status: SyncStatus.error,
        error: '',
      );
      
      expect(state.error, '');
      expect(state.hasError, isTrue);
    });

    test('should handle very long error messages', () {
      final longError = 'Error: ' * 100;
      final state = SyncState(
        status: SyncStatus.error,
        error: longError,
      );
      
      expect(state.error, longError);
      expect(state.hasError, isTrue);
    });
  });
}
