import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthInitial()) {
    _authStateSubscription =
        _supabase.auth.onAuthStateChange.listen((authState) {
      if (authState.session != null) {
        state = AuthSuccess(authState.session!.user);
      } else {
        state = AuthInitial();
      }
    });
  }

  final _supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authStateSubscription;

  Future<void> signInWithGoogle() async {
    try {
      state = AuthLoading();
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'http://localhost:3000/auth/callback',
      );
    } catch (e) {
      state = AuthError(e.toString());
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

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
