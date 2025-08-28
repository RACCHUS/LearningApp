// Supabase Configuration for Learning PWA
// Now uses environment variables for security

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Supabase Project URL from environment
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  
  // Supabase anon/public key from environment
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
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
