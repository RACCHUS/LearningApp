import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/widgets/app_shell.dart';

/// The primary destinations must stay reachable by assistive technology
/// (and by semantics-based browser tests) while a routed page is showing.
GoRouter _router() => GoRouter(
      initialLocation: '/learn',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/learn',
              builder: (context, state) => Scaffold(
                appBar: AppBar(title: const Text('Learn')),
                body: const Text('LEARN CONTENT'),
              ),
            ),
            GoRoute(
              path: '/library',
              builder: (context, state) =>
                  const Scaffold(body: Text('LIBRARY CONTENT')),
            ),
            GoRoute(
              path: '/progress',
              builder: (context, state) =>
                  const Scaffold(body: Text('PROGRESS CONTENT')),
            ),
          ],
        ),
      ],
    );

void main() {
  for (final width in [1024.0, 1280.0, 400.0]) {
    testWidgets('primary destinations are in the semantics tree at ${width}dp',
        (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
      await tester.pumpAndSettle();

      for (final label in ['Learn', 'Library', 'Progress']) {
        expect(
          find.semantics.byLabel(RegExp('^$label')),
          findsAtLeast(1),
          reason: '$label destination missing from semantics at ${width}dp',
        );
      }
      semantics.dispose();
    });
  }
}
