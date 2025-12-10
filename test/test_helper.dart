import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/services/hive_service.dart';

/// Test helper to initialize required services for testing
class TestHelper {
  static bool _initialized = false;

  /// Initialize Hive for testing environment
  static Future<void> initializeHive() async {
    if (!_initialized) {
      // Initialize Hive for testing
      Hive.init('test_db');
      
      // Register all model adapters
      registerHiveAdapters();
      
      _initialized = true;
    }
  }

  /// Initialize Supabase with test/mock configuration
  static Future<void> initializeSupabase() async {
    try {
      await Supabase.initialize(
        url: 'https://test-url.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (e) {
      // Supabase already initialized, that's okay for tests
    }
  }

  /// Clean up test environment
  static Future<void> cleanup() async {
    if (_initialized) {
      await Hive.close();
      _initialized = false;
    }
  }

  /// Setup complete test environment
  static Future<void> setupTestEnvironment() async {
    await initializeHive();
    await initializeSupabase();
  }
}
