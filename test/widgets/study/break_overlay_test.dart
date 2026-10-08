import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/timer_provider.dart';
import 'package:learning_pwa/widgets/study/break_overlay.dart';

void main() {
  group('BreakOverlay Widget Tests', () {
    testWidgets('renders nothing when timer is not on break', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Text('Active Study Session'),
                  BreakOverlay(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Active Study Session'), findsOneWidget);
      expect(find.text('Nice work!'), findsNothing);
      expect(find.text('Resume now'), findsNothing);
    });

    testWidgets('renders the longer recovery prompt on the fourth block',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(timerProvider.notifier);
      notifier.toggleEnabled(true);
      notifier.setDuration(1);
      notifier.setBreak(
        enabled: true,
        durationSeconds: 1,
        longDurationSeconds: 1200,
        longBreakEveryBlocks: 4,
      );

      for (var block = 1; block <= 3; block++) {
        notifier.tick();
        notifier.tick();
      }
      notifier.tick();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Text('Background Content'),
                  BreakOverlay(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Take a longer break'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(
        find.textContaining('You completed 4 focus blocks'),
        findsOneWidget,
      );
    });

    testWidgets('renders full break prompt when timer is on break and resumes on tap', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(timerProvider.notifier);
      notifier.toggleEnabled(true);
      notifier.setBreak(enabled: true, durationSeconds: 300);
      notifier.setDuration(1);
      notifier.start();

      // Tick to 0 -> auto-transitions to break
      notifier.tick();
      notifier.pause(); // Pause live ticker

      expect(container.read(timerProvider).isOnBreak, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Text('Background Content'),
                  BreakOverlay(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nice work!'), findsOneWidget);
      expect(find.text('Take a short break — you have earned it.'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('Resume now'), findsOneWidget);

      // Tapping "Resume now" button skips the break and returns to study
      await tester.tap(find.text('Resume now'));
      await tester.pumpAndSettle();

      expect(container.read(timerProvider).isOnBreak, isFalse);
      expect(find.text('Nice work!'), findsNothing);
    });
  });
}
