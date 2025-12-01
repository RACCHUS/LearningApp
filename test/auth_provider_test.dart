import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';

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

    // Note: Testing AuthNotifier requires Supabase initialization
    // which is complex in unit tests. These state tests verify
    // the basic auth state classes work correctly.
  });
}
