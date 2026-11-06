import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/deferred_loader_widget.dart';

void main() {
  group('DeferredLoaderWidget Tests', () {
    testWidgets('displays loading indicator while deferred library loads',
        (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: DeferredLoaderWidget(
            loader: () => completer.future,
            builder: () => const Text('Target Component'),
          ),
        ),
      );

      // Loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Target Component'), findsNothing);

      // Complete loading
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Target Component'), findsOneWidget);
    });

    testWidgets('renders custom fallback while loading', (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: DeferredLoaderWidget(
            loader: () => completer.future,
            fallback: const Center(child: Text('Custom Placeholder...')),
            builder: () => const Text('Loaded View'),
          ),
        ),
      );

      expect(find.text('Custom Placeholder...'), findsOneWidget);
      expect(find.text('Loaded View'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Custom Placeholder...'), findsNothing);
      expect(find.text('Loaded View'), findsOneWidget);
    });

    testWidgets('renders error view and retries on failure', (tester) async {
      int attempts = 0;

      Future<void> flakyLoader() async {
        attempts++;
        if (attempts == 1) {
          throw Exception('Network timeout loading part.js');
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: DeferredLoaderWidget(
            loader: flakyLoader,
            builder: () => const Text('Recovered Target'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state
      expect(find.text('Error Loading Component'), findsOneWidget);
      expect(
        find.textContaining('Failed to load component: Exception: Network timeout loading part.js'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(attempts, equals(2));
      expect(find.text('Error Loading Component'), findsNothing);
      expect(find.text('Recovered Target'), findsOneWidget);
    });
  });
}

