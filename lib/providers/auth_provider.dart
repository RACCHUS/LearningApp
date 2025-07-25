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
        state = AuthSuccess(session.user);
      } else {
        state = AuthInitial();
      }
    });
  }

  final _supabase = Supabase.instance.client;
  late final StreamSubscription _authStateSubscription;

  Future<void> signInWithGoogle() async {
    try {
      state = AuthLoading();
      // Dynamically use current window origin for redirect URL on web (no /auth/callback)
      String redirectUrl = 'https://xzvkdwebtbxlrxagtzlv.supabase.co/auth/v1/callback';
      if (kIsWeb) {
        final origin = Uri.base.origin;
        redirectUrl = origin; // Use the app root as the redirect URL
      }
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      // After login, upsert user into public.users table
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('users').upsert({
          'id': user.id,
          'email': user.email,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Google sign-in error: $e');
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
