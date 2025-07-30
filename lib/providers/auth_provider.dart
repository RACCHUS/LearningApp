import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthInitial()) {
    _authStateSubscription =
        _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _upsertUser(session.user);
        state = AuthSuccess(session.user);
      } else if (state is! GuestMode) {
        state = AuthInitial();
      }
    });
  }
  
  /// Sign in as a guest
  void signInAsGuest() {
    state = GuestMode();
  }

  final _supabase = Supabase.instance.client;
  late final StreamSubscription _authStateSubscription;

  Future<void> signInWithGoogle() async {
    try {
      state = AuthLoading();
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (e) {
      print('Google sign-in error: $e');
      state = AuthError(e.toString());
    }
  }

  Future<void> _upsertUser(User user) async {
    try {
      await _supabase.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error upserting user: $e');
      // Optionally, handle the error in the UI
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
