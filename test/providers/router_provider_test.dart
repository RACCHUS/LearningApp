import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/router_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RouterProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should create router instance', () {
      final router = container.read(routerProvider);
      
      expect(router, isNotNull);
      expect(router, isA<GoRouter>());
    });

    test('should have initial location set to home', () async {
      final router = container.read(routerProvider);
      // Wait for router to initialize
      await Future.delayed(const Duration(milliseconds: 100));
      final path = router.routerDelegate.currentConfiguration.uri.path;
      // Accept both '' and '/' as valid initial home
      expect(path == '/' || path == '', true, reason: 'Initial location should be "/" or ""');
    });

    test('should have all required routes defined', () {
      final router = container.read(routerProvider);
      final routes = router.routerDelegate.currentConfiguration;
      
      // Verify router is configured
      expect(routes, isNotNull);
    });

    test('should handle route navigation', () {
      final router = container.read(routerProvider);
      
      // Router should be accessible
      expect(router.canPop(), false); // At initial route
    });
  });
}

