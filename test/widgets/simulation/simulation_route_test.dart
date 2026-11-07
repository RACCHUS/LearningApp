import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/screens/simulation/simulation_screen.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:learning_pwa/widgets/lesson/blocks/simulation_block_widget.dart';

LessonBlock _simulationBlock({
  String id = 'networking-basics',
  String version = '1.0.0',
}) {
  final now = DateTime.utc(2026, 11, 7);
  return LessonBlock(
    id: 'simulation-block',
    lessonId: 'lesson-1',
    sortOrder: 1,
    blockType: LessonBlockType.simulation,
    content: {
      'simulation_id': id,
      'simulation_version': version,
      'title': 'Fix the network',
      'body': 'Choose the failed link and repair it.',
      'fallback_body': 'This does not replace the backward-compatible body.',
    },
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Simulation lesson block', () {
    testWidgets('renders its equivalent lesson fallback while preview is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimulationBlockWidget(
              block: _simulationBlock(),
              previewEnabled: false,
            ),
          ),
        ),
      );

      expect(
        find.text('Choose the failed link and repair it.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('launch-simulation')), findsNothing);
    });

    testWidgets('keeps the fallback for an unknown immutable version', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimulationBlockWidget(
              block: _simulationBlock(version: '99.0.0'),
              previewEnabled: true,
            ),
          ),
        ),
      );

      expect(
        find.text('Choose the failed link and repair it.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('launch-simulation')), findsNothing);
    });

    testWidgets('launches the registered activity from the lesson block', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/lesson',
        routes: [
          GoRoute(
            path: '/lesson',
            builder: (context, state) => Scaffold(
              body: SimulationBlockWidget(
                block: _simulationBlock(),
                previewEnabled: true,
              ),
            ),
          ),
          GoRoute(
            path: '/simulation/:simulationId/:version',
            builder: (context, state) => SimulationScreen(
              simulationId: state.pathParameters['simulationId']!,
              version: state.pathParameters['version']!,
              previewEnabled: true,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.tap(find.byKey(const Key('launch-simulation')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('help-action')), findsOneWidget);
      expect(find.text('Network troubleshooting practice'), findsOneWidget);
      expect(find.textContaining('Practice mode.'), findsOneWidget);
      expect(find.text('Choose the failed link and repair it.'), findsNothing);
    });

    testWidgets(
      'network practice provides structured accessible choices and exits',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/lesson',
          routes: [
            GoRoute(
              path: '/lesson',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      context.push('/simulation/networking-basics/1.0.0'),
                  child: const Text('Open network practice'),
                ),
              ),
            ),
            GoRoute(
              path: '/simulation/:simulationId/:version',
              builder: (context, state) => SimulationScreen(
                simulationId: state.pathParameters['simulationId']!,
                version: state.pathParameters['version']!,
                previewEnabled: true,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.tap(find.text('Open network practice'));
        await tester.pumpAndSettle();

        for (final choice in [
          'Between the router and the laptop',
          'Reconnect the Ethernet cable between router and laptop',
          'The cable carries network traffic from the router to the laptop.',
        ]) {
          await tester.ensureVisible(find.text(choice));
          await tester.tap(find.text(choice));
          await tester.pumpAndSettle();
        }

        await tester.ensureVisible(find.text('Review the scenario'));
        await tester.tap(find.text('Review the scenario'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('The router is online, but the Ethernet link'),
          findsOneWidget,
        );

        final finish = find.byKey(const Key('finish-network-simulation'));
        await tester.ensureVisible(finish);
        await tester.pumpAndSettle();
        await tester.tap(finish);
        await tester.pumpAndSettle();
        expect(find.text('Open network practice'), findsOneWidget);
      },
    );

    testWidgets('escape returns from the simulation without scoring', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/lesson',
        routes: [
          GoRoute(
            path: '/lesson',
            builder: (context, state) =>
                const Scaffold(body: Text('Lesson remains available')),
          ),
          GoRoute(
            path: '/simulation/:simulationId/:version',
            builder: (context, state) => SimulationScreen(
              simulationId: state.pathParameters['simulationId']!,
              version: state.pathParameters['version']!,
              previewEnabled: true,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      router.push(
        '/simulation/${SimulationActivityRegistry.networking.id}/'
        '${SimulationActivityRegistry.networking.version}',
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Lesson remains available'), findsOneWidget);
      expect(find.byKey(const Key('help-action')), findsNothing);
    });

    testWidgets('system back returns from the simulation', (tester) async {
      final router = GoRouter(
        initialLocation: '/lesson',
        routes: [
          GoRoute(
            path: '/lesson',
            builder: (context, state) =>
                const Scaffold(body: Text('Lesson remains available')),
          ),
          GoRoute(
            path: '/simulation/:simulationId/:version',
            builder: (context, state) => SimulationScreen(
              simulationId: state.pathParameters['simulationId']!,
              version: state.pathParameters['version']!,
              previewEnabled: true,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      router.push(
        '/simulation/${SimulationActivityRegistry.networking.id}/'
        '${SimulationActivityRegistry.networking.version}',
      );
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Lesson remains available'), findsOneWidget);
    });

    testWidgets('shows an explicit return fallback when preview is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SimulationScreen(
            simulationId: 'networking-basics',
            version: '1.0.0',
            previewEnabled: false,
          ),
        ),
      );

      expect(
        find.text(
          'This simulation is unavailable. Use the lesson’s '
          'alternative activity to continue learning.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('help-action')), findsOneWidget);
    });

    testWidgets('real simulation route recovers from a deferred load failure', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      context.push('/simulation/networking-basics/1.0.0'),
                  child: const Text('Lesson page'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/simulation/:simulationId/:version',
            builder: (context, state) => buildSimulationRoute(
              simulationId: state.pathParameters['simulationId']!,
              version: state.pathParameters['version']!,
              loader: () async => throw StateError('chunk load failure'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.tap(find.text('Lesson page'));
      await tester.pumpAndSettle();

      expect(find.text('Interactive practice unavailable'), findsOneWidget);
      expect(
        find.text(
          'The simulation could not load. Return to the lesson '
          'and use its alternative activity.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('help-action')), findsOneWidget);

      await tester.tap(find.byKey(const Key('simulation-load-failure-return')));
      await tester.pumpAndSettle();

      expect(find.text('Lesson page'), findsOneWidget);
      expect(find.text('Interactive practice unavailable'), findsNothing);
    });
  });
}
