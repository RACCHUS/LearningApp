import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Same limits as educator public names (ECO_04), so one name fits both.
const int displayNameMinLength = 2;
const int displayNameMaxLength = 100;

/// Returns an error message, or null when [raw] is an acceptable name.
String? validateDisplayName(String raw) {
  final name = raw.trim();
  if (name.length < displayNameMinLength) {
    return 'Use at least $displayNameMinLength characters.';
  }
  if (name.length > displayNameMaxLength) {
    return 'Use $displayNameMaxLength characters or fewer.';
  }
  if (RegExp(r'[\u0000-\u001F\u007F]').hasMatch(name)) {
    return 'Remove line breaks and control characters.';
  }
  return null;
}

/// Reads and writes `public.users.display_name` for the signed-in learner.
/// Row-level security (`users_self_update`) limits writes to the owner's row.
class DisplayNameRepository {
  DisplayNameRepository([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<String?> fetch(String userId) async {
    final row = await _db
        .from('users')
        .select('display_name')
        .eq('id', userId)
        .maybeSingle();
    final name = (row?['display_name'] as String?)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  Future<void> save(String userId, String name) async {
    await _db
        .from('users')
        .update({'display_name': name.trim()}).eq('id', userId);
  }
}

final displayNameRepositoryProvider =
    Provider<DisplayNameRepository>((ref) => DisplayNameRepository());

/// The learner's chosen display name, or null if unset or unavailable.
final displayNameProvider = FutureProvider<String?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthSuccess) return null;
  try {
    return await ref.read(displayNameRepositoryProvider).fetch(auth.user.id);
  } catch (_) {
    return null;
  }
});

/// Initial letter for avatars: display name first, then email.
String? accountInitial(String? displayName, String? email) {
  final source = (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : email?.trim();
  if (source == null || source.isEmpty) return null;
  return source.characters.first.toUpperCase();
}
