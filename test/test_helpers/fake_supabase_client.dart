import 'package:supabase_flutter/supabase_flutter.dart';

/// A fake SupabaseClient for testing that throws on all operations
/// This allows testing service constructors without real Supabase connections
class FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Fake SupabaseClient - method ${invocation.memberName} not implemented');
  }
}
