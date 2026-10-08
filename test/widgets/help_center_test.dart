import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';

void main() {
  Widget app() {
    final router = GoRouter(
      initialLocation: '/learn',
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: const Text('Learn'),
              actions: const [HelpAction()],
            ),
            body: const Text('LEARN PAGE'),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('SETTINGS PAGE')),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const Scaffold(body: Text('LIBRARY PAGE')),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const Scaffold(body: Text('PROGRESS PAGE')),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('Help opens and searches locally', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    expect(find.text('Help'), findsOneWidget);
    expect(find.byKey(const Key('help-search')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('help-search')), 'timer');
    await tester.pump();

    expect(find.text('Study timer & breaks'), findsOneWidget);
    await tester.tap(find.text('Study timer & breaks'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The study timer is optional'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('help-topic-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-search')), findsOneWidget);
  });

  testWidgets('Help topic action closes Help and navigates', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('help-search')), 'daily goal');
    await tester.pump();

    await tester.tap(find.text('Daily study goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS PAGE'), findsOneWidget);
    expect(find.byKey(const Key('help-search')), findsNothing);
  });

  testWidgets('Help shows no-results fallback', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('help-search')),
      'xyzzy-no-such-help-topic',
    );
    await tester.pump();

    expect(
      find.text('No help topics matched that search.'),
      findsOneWidget,
    );
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('closing Help returns to the underlying screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('help-close')));
    await tester.pumpAndSettle();

    expect(find.text('LEARN PAGE'), findsOneWidget);
    expect(find.byKey(const Key('help-search')), findsNothing);
  });
}
