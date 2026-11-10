import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/config/brand_config.dart';
import 'package:learning_pwa/widgets/simulation/simulation_route_title.dart';

void main() {
  testWidgets('browser title follows simulation routes and restores on exit', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/learn',
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => const Scaffold(body: Text('Learn')),
        ),
        GoRoute(
          path: '/simulation/:simulationId/:version',
          builder: (context, state) => const Scaffold(body: Text('Simulation')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        title: BrandConfig.appName,
        routerConfig: router,
        builder: (context, child) =>
            SimulationRouteTitle(router: router, child: child!),
      ),
    );
    await tester.pumpAndSettle();

    String windowTitle() => tester.widget<Title>(find.byType(Title).last).title;

    expect(windowTitle(), BrandConfig.appName);
    router.push('/simulation/networking-basics/1.0.0');
    await tester.pumpAndSettle();
    expect(
      windowTitle(),
      'Network troubleshooting practice - ${BrandConfig.appName}',
    );

    router.push('/simulation/atm-withdrawal/1.0.0');
    await tester.pumpAndSettle();
    expect(windowTitle(), 'ATM withdrawal practice - ${BrandConfig.appName}');

    router.pop();
    await tester.pumpAndSettle();
    expect(
      windowTitle(),
      'Network troubleshooting practice - ${BrandConfig.appName}',
    );

    router.go('/simulation/networking-basics/99.0.0');
    await tester.pumpAndSettle();
    expect(
      windowTitle(),
      'Interactive practice unavailable - ${BrandConfig.appName}',
    );

    router.go('/learn');
    await tester.pumpAndSettle();
    expect(windowTitle(), BrandConfig.appName);
  });

  testWidgets('a direct simulation link sets the activity title on startup', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/simulation/atm-withdrawal/1.0.0',
      routes: [
        GoRoute(
          path: '/simulation/:simulationId/:version',
          builder: (context, state) => const Scaffold(body: Text('Simulation')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        title: BrandConfig.appName,
        routerConfig: router,
        builder: (context, child) =>
            SimulationRouteTitle(router: router, child: child!),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Title>(find.byType(Title).last).title,
      'ATM withdrawal practice - ${BrandConfig.appName}',
    );
  });
}
