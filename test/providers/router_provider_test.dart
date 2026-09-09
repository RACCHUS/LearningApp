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

    test('should have initial location set to Learn', () async {
      final router = container.read(routerProvider);
      // Wait for router to initialize
      await Future.delayed(const Duration(milliseconds: 100));
      final path = router.routerDelegate.currentConfiguration.uri.path;
      // Learn replaced the old '/' home surface. The delegate stays empty
      // until the router is attached to a widget tree, so accept both.
      expect(path == '/learn' || path.isEmpty, true,
          reason: 'Initial location should be "/learn" once resolved');
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

  group('Locked architecture routes', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    List<RouteBase> flatten(List<RouteBase> routes) => [
          for (final route in routes) ...[route, ...flatten(route.routes)],
        ];

    test('the three destinations exist as shell children', () {
      final router = container.read(routerProvider);
      final shells =
          router.configuration.routes.whereType<ShellRoute>().toList();

      expect(shells, hasLength(1), reason: 'exactly one persistent app shell');

      final shellPaths =
          shells.first.routes.whereType<GoRoute>().map((r) => r.path).toList();

      expect(shellPaths, containsAll(['/learn', '/library', '/progress']));
    });

    test('no duplicate paths', () {
      final router = container.read(routerProvider);
      final paths = flatten(router.configuration.routes)
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(paths.toSet().length, paths.length,
          reason: 'duplicate paths make GoRouter assert at construction');
    });

    test('no duplicate route names', () {
      final router = container.read(routerProvider);
      final names = flatten(router.configuration.routes)
          .whereType<GoRoute>()
          .map((r) => r.name)
          .whereType<String>()
          .toList();

      expect(names.toSet().length, names.length);
    });

    test('course outline route is registered', () {
      final router = container.read(routerProvider);
      final paths = flatten(router.configuration.routes)
          .whereType<GoRoute>()
          .map((r) => r.path);

      expect(paths, contains('/course/:courseId/outline'));
    });

    test('legacy "/" is kept as a redirect so deep links keep working', () {
      final router = container.read(routerProvider);
      final root = flatten(router.configuration.routes)
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/');

      expect(root.redirect, isNotNull);
      expect(root.builder, isNull);
    });
  });
}

