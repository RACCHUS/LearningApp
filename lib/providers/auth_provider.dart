import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final _logger = AppLogger('AuthNotifier');
  final _supabase = Supabase.instance.client;
  late final StreamSubscription _authStateSubscription;

  AuthNotifier() : super(AuthInitial()) {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _upsertUser(session.user);
      state = AuthSuccess(session.user);
    } else {
      state = GuestMode();
    }
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _upsertUser(session.user);
        state = AuthSuccess(session.user);
      } else if (state is! GuestMode) {
        state = GuestMode();
      }
    });
  }

  /// Sign in as a guest using Supabase anonymous auth.
  ///
  /// Each guest gets a unique auth.uid() so RLS policies can scope rows to
  /// the individual guest. Guests can later be upgraded to a full account
  /// by linking an identity (email / OAuth) without losing their data.
  Future<void> signInAsGuest() async {
    try {
      state = AuthLoading();
      await _supabase.auth.signInAnonymously();
      // onAuthStateChange will fire and set state = AuthSuccess.
    } catch (e, stackTrace) {
      _logger.error(
        'Anonymous sign-in failed',
        error: e,
        stackTrace: stackTrace,
        metadata: {'method': 'signInAsGuest'},
      );
      state = AuthError('Unable to start guest session. Please try again.');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = AuthLoading();
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (e, stackTrace) {
      // Log full error details securely
      _logger.error(
        'Google sign-in failed',
        error: e,
        stackTrace: stackTrace,
        metadata: {'method': 'signInWithGoogle'},
      );

      // Sanitized user-facing message
      state = AuthError('Unable to sign in. Please try again.');
      rethrow;
    }
  }

  Future<void> _upsertUser(User user) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        await _supabase.from('users').upsert({
          'id': user.id,
          // Anonymous users have no email; column is nullable post-migration.
          'email': user.email,
          'display_name': user.isAnonymous ? 'Guest' : null,
          'created_at': DateTime.now().toIso8601String(),
        });

        _logger.info('User record upserted successfully',
            metadata: {'userId': user.id});
        return; // Success
      } catch (e, stackTrace) {
        attempts++;

        _logger.warn(
          'User upsert failed (attempt $attempts/$maxAttempts)',
          error: e,
          stackTrace: stackTrace,
          metadata: {'userId': user.id, 'attempt': attempts},
        );

        if (attempts >= maxAttempts) {
          // Critical: User authenticated but not in database
          _logger.error(
            'CRITICAL: User upsert failed after $maxAttempts attempts',
            error: e,
            stackTrace: stackTrace,
            metadata: {'userId': user.id},
          );

          // Sign out the user to prevent inconsistent state
          await _supabase.auth.signOut();
          state = AuthError('Failed to create user account. Please try again.');
          throw DatabaseException(
            'User record creation failed after $maxAttempts attempts',
            originalError: e,
            stackTrace: stackTrace,
          );
        }

        // Exponential backoff: wait before retry
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = AuthInitial();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }
}

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
}

class GuestMode extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
