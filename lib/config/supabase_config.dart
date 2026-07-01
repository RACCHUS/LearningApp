// Supabase Configuration for Learning PWA
// Resolution order (most secure first):
//   1. --dart-define=SUPABASE_URL=... / SUPABASE_ANON_KEY=...  (build-time, web + native)
//   2. .env file via flutter_dotenv                            (native/dev only)
//   3. Hardcoded public fallback                               (so existing web builds keep working)
//
// The anon key is a *public* key protected by Row-Level Security, so it is safe to
// ship in a client. Prefer --dart-define so the project can be re-pointed or the key
// rotated without editing source.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Values injected at build time: flutter build web --dart-define=SUPABASE_URL=...
  static const String _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _defineAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // Public fallbacks (anon key is RLS-protected and safe to expose). These keep
  // existing deployments working when no --dart-define / .env is provided.
  static const String _fallbackUrl = 'https://xzvkdwebtbxlrxagtzlv.supabase.co';
  static const String _fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6dmtkd2VidGJ4bHJ4YWd0emx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM0NTY4NTMsImV4cCI6MjA2OTAzMjg1M30.PrrRi4aecxwUVSeKgor-la2Vk-Tg6heRPGdUOzfEPIY';

  static String _fromDotenv(String key) {
    try {
      return dotenv.isInitialized ? (dotenv.env[key] ?? '') : '';
    } catch (_) {
      // dotenv not loaded (e.g. web build without a bundled .env) — ignore.
      return '';
    }
  }

  // Supabase Project URL
  static String get url {
    if (_defineUrl.isNotEmpty) return _defineUrl;
    final fromEnv = _fromDotenv('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _fallbackUrl;
  }

  // Supabase anon/public key
  static String get anonKey {
    if (_defineAnonKey.isNotEmpty) return _defineAnonKey;
    final fromEnv = _fromDotenv('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _fallbackAnonKey;
  }

  // Validation method to ensure config is loaded
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

// INSTRUCTIONS:
// 1. Copy .env.example to .env
// 2. Go to https://supabase.com/dashboard
// 3. Find your project or create a new one
// 4. Go to Settings > API
// 5. Copy the Project URL and anon/public key to .env file
// 6. Never commit the .env file to git (it's already in .gitignore)
