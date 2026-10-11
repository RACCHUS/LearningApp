import 'dart:convert';
import 'dart:io';

/// Supabase REST gateway authentication for server-side Dart clients.
///
/// Legacy service_role and anon API keys are JWTs and can be sent as a
/// Bearer token. Modern sb_secret_ and sb_publishable_ keys are NOT JWTs;
/// Supabase requires them on the apikey header and rejects them on
/// Authorization: Bearer. Never send an admin key from a client app.
///
/// https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys
String? supabaseBearerValueForApiKey(String rawKey) {
  final key = rawKey.trim();
  if (key.startsWith('sb_secret_') || key.startsWith('sb_publishable_')) {
    return null;
  }
  if (key.split('.').length == 3 &&
      key.split('.').every((part) => part.isNotEmpty)) {
    return 'Bearer $key';
  }
  throw const FormatException(
    'Unsupported Supabase API key shape. Expected a modern sb_secret_ / '
    'sb_publishable_ key or a legacy JWT. Do not print the key.',
  );
}

void setSupabaseRestAuth(HttpClientRequest request, String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw const FormatException('Supabase API key is empty.');
  }
  final bearer = supabaseBearerValueForApiKey(key);
  request.headers.set('apikey', key);
  if (bearer != null) {
    request.headers.set(HttpHeaders.authorizationHeader, bearer);
  }
}

/// Admin import must never accidentally run with a publishable or anon key.
void assertSupabaseAdminKey(String key) {
  final normalized = key.trim();
  if (normalized.startsWith('sb_secret_')) return;
  // Decode the payload only to refuse obvious anon JWTs. The gateway still
  // validates the JWT signature for real requests.
  try {
    final parts = normalized.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid legacy key.');
    }
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    if (payload['role'] != 'service_role') {
      throw const FormatException('Legacy key is not service_role.');
    }
  } catch (_) {
    throw const FormatException(
      'Admin import requires sb_secret_ or a valid-shaped legacy '
      'service_role JWT. Anon/publishable keys are not allowed.',
    );
  }
}
