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
  final bearer = supabaseBearerValueForApiKey(normalized);
  if (bearer == null ||
      !normalized.startsWith('eyJ')) {
    throw const FormatException(
      'Admin import requires sb_secret_ or a legacy JWT-based service-role '
      'key; publishable keys are not privileged.',
    );
  }
}
