import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_supabase_client.dart';

/// A signed-out Supabase client whose every query and RPC fails the way an
/// offline request does. Use it to exercise offline fallbacks deliberately,
/// instead of letting code reach an uninitialized `Supabase.instance` (which
/// tests a misconfigured app, and which the log-noise ratchet rejects).
class OfflineSupabaseClient extends FakeSupabaseClient {
  OfflineSupabaseClient({super.currentUser});

  @override
  SupabaseQueryBuilder from(String table) => throw const SocketException('offline');

  @override
  PostgrestFilterBuilder<T> rpc<T>(String fn, {Map<String, dynamic>? params, dynamic get}) =>
      throw const SocketException('offline');
}
