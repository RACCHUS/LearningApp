// Supabase Configuration for Learning PWA
// Now uses environment variables for security

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // For web deployment, we need to handle environment variables differently
  // since .env files are not included in the web build
  
  // Supabase Project URL from environment or fallback
  static String get url {
    if (kIsWeb) {
      // For web deployment, use the hardcoded values
      return 'https://xzvkdwebtbxlrxagtzlv.supabase.co';
    }
    return dotenv.env['SUPABASE_URL'] ?? '';
  }
  
  // Supabase anon/public key from environment or fallback
  static String get anonKey {
    if (kIsWeb) {
      // For web deployment, use the hardcoded values
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6dmtkd2VidGJ4bHJ4YWd0emx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM0NTY4NTMsImV4cCI6MjA2OTAzMjg1M30.PrrRi4aecxwUVSeKgor-la2Vk-Tg6heRPGdUOzfEPIY';
    }
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
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
