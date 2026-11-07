import 'dart:async';

import 'package:learning_pwa/config/brand_config.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/config/supabase_config.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:learning_pwa/services/push_notification_service.dart';
import 'package:learning_pwa/providers/theme_provider.dart';
import 'package:learning_pwa/providers/app_initialization_provider.dart';
import 'package:learning_pwa/core/errors/global_error_handler.dart';
import 'package:learning_pwa/core/logging/error_reporting_service.dart';
import 'package:learning_pwa/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIX-6: Ensure screen readers and assistive technologies receive semantics immediately on Web
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // Initialize error reporting service FIRST
  await ErrorReportingService.instance.initialize();

  // Initialize global error handling
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

    // Validate Supabase configuration
    print('🔄 Checking Supabase configuration...');
    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        print('❌ ERROR: Supabase configuration missing!');
        print(
            '📝 Please copy .env.example to .env and configure your Supabase credentials');
        print(
            'SUPABASE_URL: ${SupabaseConfig.url.isEmpty ? 'MISSING' : 'SET'}');
        print(
            'SUPABASE_ANON_KEY: ${SupabaseConfig.anonKey.isEmpty ? 'MISSING' : 'SET'}');
      }
      throw Exception(
          'Supabase configuration missing. Please configure .env file.');
    }

    print('🔄 Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    print('✅ Supabase initialized successfully');

    print('🚀 Launching app...');
    runApp(
      const ProviderScope(
        child: LearningApp(),
      ),
    );

    // Optional integrations must not delay the first usable frame. The app
    // shell and core learning routes are available before these services start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeOptionalServices());
    });
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ App initialization failed: $e');
      print('Stack trace: $stackTrace');
    }

    // Show error app instead of crashing
    runApp(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

/// Initialize browser notifications after the first frame. Audio and voice
/// services are initialized by their feature providers only when first needed.
Future<void> _initializeOptionalServices() async {
  try {
    await PushNotificationService().init();
  } catch (error, stackTrace) {
    debugPrint('Optional notification initialization failed: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
  }
}

class LearningApp extends ConsumerStatefulWidget {
  final List<String> degradedServices;
  
  const LearningApp({super.key, this.degradedServices = const []});

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
      
      // Notify user of degraded services
      if (widget.degradedServices.isNotEmpty) {
        final messenger = PushNotificationService.scaffoldMessengerKey?.currentState;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Some features unavailable: ${widget.degradedServices.join(", ")}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Set global scaffoldMessengerKey for push notifications
    PushNotificationService.scaffoldMessengerKey =
        GlobalKey<ScaffoldMessengerState>();

    return MaterialApp.router(
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      title: BrandConfig.appName,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
