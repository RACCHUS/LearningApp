import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/screens/auth/login_screen.dart';
import 'package:learning_pwa/screens/home_screen.dart';
import 'package:learning_pwa/screens/test/notification_test_screen.dart';
import 'package:learning_pwa/screens/explore_screen.dart';
import 'package:learning_pwa/screens/saved_screen.dart';
import 'package:learning_pwa/screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Auth state is not used for routing as we allow both authenticated and guest access
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      // Allow all routes for both authenticated and unauthenticated users
      // The app will adjust its behavior based on auth state
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
      // App feature routes
      GoRoute(
        path: '/explore',
        builder: (context, state) => const ExploreScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Development-only routes
      GoRoute(
        path: '/test/notifications',
        builder: (context, state) => const NotificationTestScreen(),
      ),
    ],
  );
});
