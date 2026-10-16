import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Explicitly links a Google identity to the CURRENT anonymous user.
  /// This preserves the auth UID when Manual Identity Linking is enabled.
  /// For an already-owned Google identity, keep the guest session intact;
  /// existing-account import must be a separate, consent-based flow.
  Future<void> linkGuestToGoogle() async {
    final guest = _supabase.auth.currentUser;
    if (guest == null || !guest.isAnonymous) {
      throw StateError('Only an anonymous guest can upgrade this way.');
    }
    try {
      state = AuthLoading();
      await _supabase.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (e, stackTrace) {
      _logger.warn('Google identity linking failed',
        error: e, stackTrace: stackTrace,
        metadata: {'method': 'linkGuestToGoogle'});
      // Never sign out or replace the anonymous identity on a failed link.
      state = AuthSuccess(guest);
      rethrow;
    }
  }

  /// Retry a failed profile write without discarding a valid auth session.
  Future<void> retryProfileProvisioning() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _upsertUser(user);
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

          // Keep the valid auth session: signing out here could make an
          // anonymous learner permanently lose access to their work.
          state = AuthError(
            'Signed in, but the profile could not be saved. Retry later.',
          );
          return;
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
