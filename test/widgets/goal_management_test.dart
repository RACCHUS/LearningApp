import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:learning_pwa/widgets/learn/continue_card.dart';
import 'package:learning_pwa/widgets/learn/context_switcher.dart';
import 'package:learning_pwa/widgets/lesson_card.dart';

void main() {
  LearningContext ctx(String id, String label, {bool isArchived = false}) =>
      LearningContext(
        id: id,
        userId: 'u1',
        label: label,
        rootType: ContextRootType.target,
        rootId: 'target-$id',
        isArchived: isArchived,
        lastActiveAt: DateTime(2026, 1, 1),
      );

  group('Goal Management in ContextSwitcher', () {
    testWidgets(
        'renders dropdown when multiple goals exist and lists goal options',
        (tester) async {
      final active = ctx('1', 'Software Engineer');
      final second = ctx('2', 'Data Scientist');
      final state = LearningContextsState(
        contexts: [active, second],
        activeId: active.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(state),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: ContextSwitcher(state: state)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropdown control is visible
      expect(find.byKey(const Key('context-switcher')), findsOneWidget);
      await tester.tap(find.byKey(const Key('context-switcher')));
      await tester.pumpAndSettle();

      // Modal bottom sheet appears
      expect(find.text('Your learning'), findsOneWidget);
      expect(find.text('Software Engineer'), findsNWidgets(2));
      expect(find.text('Data Scientist'), findsOneWidget);
      expect(find.text('Clear active goal'), findsOneWidget);
    });

    testWidgets(
        'renders archived and paused goals with resume action',
        (tester) async {
      final active = ctx('1', 'Software Engineer');
      final archived = ctx('2', 'Cybersecurity Specialist', isArchived: true);
      final state = LearningContextsState(
        contexts: [active],
        archivedContexts: [archived],
        activeId: active.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(state),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: ContextSwitcher(state: state)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // showSwitcherControl is true because (1 active + 1 archived) >= 2
      expect(find.byKey(const Key('context-switcher')), findsOneWidget);
      await tester.tap(find.byKey(const Key('context-switcher')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Paused & Completed Goals'), findsOneWidget);
      expect(find.text('Cybersecurity Specialist'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets(
        'single goal shows active-goal-header with more options',
        (tester) async {
      final single = ctx('1', 'Software Engineer');
      final state = LearningContextsState(
        contexts: [single],
        activeId: single.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(state),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: ContextSwitcher(state: state)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // context-switcher is NOT present, preserving Ship Gate test
      expect(find.byKey(const Key('context-switcher')), findsNothing);
      expect(find.text('Software Engineer'), findsOneWidget);

      // But learner can tap active-goal-header to open options sheet
      expect(find.byKey(const Key('active-goal-header')), findsOneWidget);
      await tester.tap(find.byKey(const Key('active-goal-header')));
      await tester.pumpAndSettle();

      expect(find.text('Pause & Archive Goal'), findsOneWidget);
      expect(find.text('Clear active goal'), findsOneWidget);
      expect(find.text('Remove Goal'), findsOneWidget);
    });
  });

  group('ContinueCard ContextComplete', () {
    testWidgets('shows archive button when ContextComplete', (tester) async {
      final active = ctx('1', 'Software Engineer');
      final state = LearningContextsState(
        contexts: [active],
        activeId: active.id,
      );

      const action = ContextComplete(
        offer: ForwardOffer(label: 'Explore Catalog'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningContextsProvider.overrideWith(
              (ref) => LearningContextsNotifier.stub(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ContinueCard(action: action),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing left here'), findsOneWidget);
      expect(find.byKey(const Key('learn-archive-goal-action')), findsOneWidget);
      expect(find.text('Archive completed goal'), findsOneWidget);
    });
  });

  group('LessonCard manual progress toggle', () {
    testWidgets('renders completion icon and toggle action in overflow menu',
        (tester) async {
      final lesson = Lesson(
        id: 'lesson-1',
        title: 'Introduction to Algorithms',
        description: 'Basic computational thinking',
        tags: ['CS'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'test-user',
        terms: const [],
        questions: const [],
        concepts: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonProgressProvider('lesson-1').overrideWith((ref) => 1.0),
            lessonMasteryProvider('lesson-1').overrideWith((ref) => null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: ListView(
                children: [
                  LessonCard(lesson: lesson),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkmark icon button is visible
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Manual completion toggle option is present
      expect(find.text('Mark as incomplete'), findsOneWidget);
    });
  });
}
