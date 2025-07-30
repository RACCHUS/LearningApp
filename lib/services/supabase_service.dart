import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  
  late final SupabaseClient _client;
  
  SupabaseService._internal() {
    _client = Supabase.instance.client;
  }
  
  // Auth methods
  Future<AuthResponse> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      authScreenRoute: '/auth',
      redirectTo: 'https://your-app-url.com/callback', // Update with your app URL
    );
  }
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  // User data methods
  User? get currentUser => _client.auth.currentUser;
  
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  
  // Database methods
  PostgrestQueryBuilder<dynamic> from(String table) => _client.from(table);
  
  // Storage methods
  SupabaseStorageClient get storage => _client.storage;
  
  // Realtime subscriptions
  RealtimeChannel channel(String name, {String? key}) => 
      _client.channel(name, key: key);
}
