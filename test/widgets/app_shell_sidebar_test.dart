import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/widgets/app_shell.dart';

void main() {
  testWidgets('desktop sidebar collapses and expands without changing tab',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/learn',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/learn',
              builder: (context, state) =>
                  const Scaffold(body: Text('LEARN CONTENT')),
            ),
            GoRoute(
              path: '/library',
              builder: (context, state) => Scaffold(
                  body: Text('LIBRARY ${state.uri.queryParameters['search'] ?? ''}')),
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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-search')), findsOneWidget);
    expect(find.text('LEARN CONTENT'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-search')), findsNothing);
    expect(find.byKey(const Key('sidebar-open-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar-open-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-search')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('sidebar-search')), 'CompTIA Security+');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('LIBRARY CompTIA Security+'), findsOneWidget);
  });
}
