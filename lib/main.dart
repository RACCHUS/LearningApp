import 'package:learning_pwa/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/config/supabase_config.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:learning_pwa/services/push_notification_service.dart';
import 'package:learning_pwa/providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:learning_pwa/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    const ProviderScope(
      child: LearningApp(),
    ),
  );
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
