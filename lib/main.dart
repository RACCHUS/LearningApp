import 'package:learning_pwa/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/config/supabase_config.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:learning_pwa/services/push_notification_service.dart';
import 'package:learning_pwa/providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:learning_pwa/config/firebase_options.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:learning_pwa/services/hands_free_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    if (kDebugMode) {
      print('✅ Environment variables loaded successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Warning: Could not load .env file: $e');
      print('📝 Make sure to copy .env.example to .env and configure it');
    }
  }

  // Initialize Hive
  registerHiveAdapters();
  hiveService = HiveService();
  await hiveService.init();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.web,
  );

  // Initialize Push Notification Service (FCM)
  try {
    await PushNotificationService().init();
  } catch (e) {
    // If FCM is not supported, ignore
  }

  // Initialize Audio Services
  try {
    await AudioService().initialize();
    await VoiceInputService().initialize();
  } catch (e) {
    // If audio services fail to initialize, continue without them
    if (kDebugMode) {
      print('Audio services initialization failed: $e');
    }
  }

  // Validate Supabase configuration
  if (!SupabaseConfig.isConfigured) {
    if (kDebugMode) {
      print('❌ ERROR: Supabase configuration missing!');
      print('📝 Please copy .env.example to .env and configure your Supabase credentials');
    }
    throw Exception('Supabase configuration missing. Please configure .env file.');
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  if (kDebugMode) {
    print('✅ Supabase initialized successfully');
  }

  // Initialize hands-free settings and check for auto-enable
  await _initializeHandsFreeMode();

  runApp(
    const ProviderScope(
      child: LearningApp(),
    ),
  );
}

/// Initialize hands-free mode based on user settings
Future<void> _initializeHandsFreeMode() async {
  try {
    final settingsService = HandsFreeSettingsService();
    await settingsService.initialize();
    final settings = settingsService.settings;
    
    if (settings.defaultHandsFreeMode || settingsService.isHandsFreeEnabled) {
      if (kDebugMode) {
        print('🎙️ Auto-enabling hands-free mode based on user settings');
      }
      // Note: Actual global voice enabling will be handled by the app after provider initialization
      // This just loads the setting that indicates hands-free should be enabled
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Failed to check hands-free settings: $e');
    }
  }
}

class LearningApp extends ConsumerWidget {
  const LearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Learning PWA',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
