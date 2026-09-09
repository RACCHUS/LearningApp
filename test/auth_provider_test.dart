import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

void main() {
  group('AuthState Tests', () {
    test('AuthInitial should be created', () {
      final state = AuthInitial();
      expect(state, isA<AuthState>());
      expect(state, isA<AuthInitial>());
    });

    test('AuthLoading should be created', () {
      final state = AuthLoading();
      expect(state, isA<AuthState>());
      expect(state, isA<AuthLoading>());
    });

    test('GuestMode should be created', () {
      final state = GuestMode();
      expect(state, isA<AuthState>());
      expect(state, isA<GuestMode>());
    });

    test('AuthError should store error message', () {
      final state = AuthError('Test error');
      expect(state, isA<AuthState>());
      expect(state, isA<AuthError>());
      expect(state.message, 'Test error');
    });

    test('AuthSuccess should store user', () {
      final mockUser = User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final state = AuthSuccess(mockUser);
      
      expect(state, isA<AuthState>());
      expect(state, isA<AuthSuccess>());
      expect(state.user, mockUser);
      expect(state.user.id, 'user-123');
    });

    test('different AuthState types should not be equal', () {
      final initial = AuthInitial();
      final loading = AuthLoading();
      final guest = GuestMode();
      
      expect(initial, isNot(loading));
      expect(initial, isNot(guest));
      expect(loading, isNot(guest));
    });

    test('AuthError should handle empty message', () {
      final state = AuthError('');
      expect(state.message, isEmpty);
    });

    test('AuthError should handle long error message', () {
      final longMessage = 'This is a very long error message ' * 10;
      final state = AuthError(longMessage);
      expect(state.message, longMessage);
      expect(state.message.length, greaterThan(100));
    });

    test('multiple AuthError instances with same message should have same message', () {
      final state1 = AuthError('Network error');
      final state2 = AuthError('Network error');
      
      expect(state1.message, state2.message);
    });

    test('AuthSuccess should handle different user IDs', () {
      final user1 = User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final user2 = User(
        id: 'user-2',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      final state1 = AuthSuccess(user1);
      final state2 = AuthSuccess(user2);
      
      expect(state1.user.id, 'user-1');
      expect(state2.user.id, 'user-2');
      expect(state1.user.id, isNot(state2.user.id));
    });

    test('AuthSuccess should preserve user metadata', () {
      final user = User(
        id: 'user-123',
        appMetadata: {'role': 'admin'},
        userMetadata: {'name': 'Test User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final state = AuthSuccess(user);
      
      expect(state.user.appMetadata['role'], 'admin');
      expect(state.user.userMetadata?['name'], 'Test User');
    });

    // Note: Testing AuthNotifier requires Supabase initialization
    // which is complex in unit tests. These state tests verify
    // the basic auth state classes work correctly.
  });
}
