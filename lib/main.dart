import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/offline_provider.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.web,
  );

  await Supabase.initialize(
    url: 'https://xzvkdwebtbxlrxagtzlv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6dmtkd2VidGJ4bHJ4YWd0emx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM0NTY4NTMsImV4cCI6MjA2OTAzMjg1M30.PrrRi4aecxwUVSeKgor-la2Vk-Tg6heRPGdUOzfEPIY',
  );

  final container = ProviderContainer();
  await container.read(offlineProvider.notifier).init();

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Learning PWA',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routerConfig: router,
    );
  }
}
