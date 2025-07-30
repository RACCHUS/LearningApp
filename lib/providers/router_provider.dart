import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/screens/auth/login_screen.dart';
import 'package:learning_pwa/screens/home_screen.dart';
import 'package:learning_pwa/screens/test/notification_test_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState is AuthSuccess) {
        if (state.uri.toString() == '/login') {
          return '/home';
        }
      } else if (authState is AuthInitial) {
        if (state.uri.toString() != '/login') {
          return '/login';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      // Development-only routes
      GoRoute(
        path: '/test/notifications',
        builder: (context, state) => const NotificationTestScreen(),
      ),
    ],
  );
});
