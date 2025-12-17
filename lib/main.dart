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
import 'package:learning_pwa/providers/app_initialization_provider.dart';
import 'package:learning_pwa/core/errors/global_error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global error handling FIRST
  GlobalErrorHandler.initialize();

  try {
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
      
      // For web deployment, we might need to hardcode or use different approach
      if (kIsWeb) {
        print('🌐 Running on web - using fallback configuration');
        // You can set environment variables here for web deployment if needed
      }
    }

    // Initialize Hive
    print('🔄 Initializing Hive...');
    registerHiveAdapters();
    hiveService = HiveService();
    await hiveService.init();
    print('✅ Hive initialized successfully');

    // Initialize Firebase
    print('🔄 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
    print('✅ Firebase initialized successfully');

    // Initialize Push Notification Service (FCM)
    try {
      print('🔄 Initializing Push Notifications...');
      await PushNotificationService().init();
      print('✅ Push Notifications initialized successfully');
    } catch (e) {
      // If FCM is not supported, ignore
      if (kDebugMode) {
        print('⚠️ FCM initialization failed: $e');
      }
    }

    // Initialize Audio Services
    try {
      print('🔄 Initializing Audio Services...');
      await AudioService().initialize();
      await VoiceInputService().initialize();
      print('✅ Audio Services initialized successfully');
    } catch (e) {
      // If audio services fail to initialize, continue without them
      if (kDebugMode) {
        print('⚠️ Audio services initialization failed: $e');
      }
    }

    // Validate Supabase configuration
    print('🔄 Checking Supabase configuration...');
    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        print('❌ ERROR: Supabase configuration missing!');
        print('📝 Please copy .env.example to .env and configure your Supabase credentials');
        print('SUPABASE_URL: ${SupabaseConfig.url.isEmpty ? 'MISSING' : 'SET'}');
        print('SUPABASE_ANON_KEY: ${SupabaseConfig.anonKey.isEmpty ? 'MISSING' : 'SET'}');
      }
      throw Exception('Supabase configuration missing. Please configure .env file.');
    }

    print('🔄 Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    print('✅ Supabase initialized successfully');

    // Initialize hands-free settings and check for auto-enable
    print('🔄 Initializing Hands-Free Mode...');
    await _initializeHandsFreeMode();
    print('✅ Hands-Free Mode initialized successfully');

    print('🚀 All services initialized - launching app...');
    runApp(
      const ProviderScope(
        child: LearningApp(),
      ),
    );
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ App initialization failed: $e');
      print('Stack trace: $stackTrace');
    }
    
    // Show error app instead of crashing
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('App failed to initialize'),
                SizedBox(height: 8),
                Text('Please check console for details'),
                if (kDebugMode) ...[
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Error: $e',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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

class LearningApp extends ConsumerStatefulWidget {
  const LearningApp({super.key});

  @override
  ConsumerState<LearningApp> createState() => _LearningAppState();
}

class _LearningAppState extends ConsumerState<LearningApp> {
  @override
  void initState() {
    super.initState();
    // Trigger app initialization after providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appInitNotifier = ref.read(appInitializationProvider.notifier);
      appInitNotifier.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    // Set global scaffoldMessengerKey for push notifications
    PushNotificationService.scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
    
    return MaterialApp.router(
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      title: 'Learning PWA',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
