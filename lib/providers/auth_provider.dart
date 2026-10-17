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

  bool get isAnonymousSession =>
      _supabase.auth.currentUser?.isAnonymous == true;

  bool get hasAuthenticatedSession => _supabase.auth.currentUser != null;

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
    if (_supabase.auth.currentUser != null) {
      throw StateError('An authenticated session already exists.');
    }
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
    if (isAnonymousSession) {
      throw StateError(
        'Use linkGuestToGoogle to preserve the anonymous learner ID.',
      );
    }
    try {
      state = AuthLoading();
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (!launched) {
        state = GuestMode();
      }
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
      final launched = await _supabase.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (!launched) {
        // No navigation took place: do not strand the UI in AuthLoading.
        state = AuthSuccess(guest);
      }
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
    final success = await _upsertUser(user);
    if (success && _supabase.auth.currentUser?.id == user.id) {
      state = AuthSuccess(user);
    }
  }

  Future<bool> _upsertUser(User user) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final existing = await _supabase.from('users')
            .select('email')
            .eq('id', user.id)
            .maybeSingle();
        if (existing == null) {
          // Let the database set created_at exactly once. No replacement of
          // user-controlled display names on subsequent auth events.
          await _supabase.from('users').insert({
            'id': user.id,
            'email': user.email,
            'display_name': user.isAnonymous ? 'Guest' : null,
          });
        } else if (existing['email'] != user.email) {
          // Anonymous -> Google linking keeps the same UID. Sync the email
          // without erasing existing profile fields or creation time.
          await _supabase.from('users').update({
            'email': user.email,
          }).eq('id', user.id);
        }

        _logger.info('User record synchronized successfully',
            metadata: {'userId': user.id});
        return true; // Success
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
          return false;
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
