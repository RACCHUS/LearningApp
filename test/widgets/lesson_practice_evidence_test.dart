import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/gap_signal_service.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:learning_pwa/widgets/lesson/blocks/lesson_block_renderer.dart';
import 'package:learning_pwa/widgets/lesson/blocks/practice_prompt_block_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PR-D main-lesson evidence: first practice answers in the lesson itself
/// can lead to a dismissible help suggestion. Never progress or mastery.
void main() {
  late BridgeLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('practice prompt reports its first checked pick', () {
    LessonBlock block({String answer = 'Paris'}) => LessonBlock(
      id: 'synth-q-1',
      lessonId: 'l1',
      sortOrder: 0,
      blockType: LessonBlockType.practicePrompt,
      content: {
        'prompt': 'Capital of France?',
        'options': ['London', 'Paris', 'Rome'],
        'answer': answer,
      },
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Future<List<bool>> run(
      WidgetTester tester,
      LessonBlock b, {
      String? pick,
      int reveals = 1,
    }) async {
      final reports = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PracticePromptBlockWidget(
                key: UniqueKey(),
                block: b,
                onFirstChecked: reports.add,
              ),
            ),
          ),
        ),
      );
      if (pick != null) {
        await tester.tap(find.text(pick));
        await tester.pump();
      }
      for (var i = 0; i < reveals; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      return reports;
    }

    testWidgets('a right or wrong pick is reported once', (tester) async {
      expect(await run(tester, block(), pick: 'Paris', reveals: 3), [true]);
      expect(await run(tester, block(), pick: 'Rome'), [false]);
    });

    testWidgets('no pick, or an answer that matches no option: nothing', (
      tester,
    ) async {
      expect(await run(tester, block()), isEmpty);
      expect(
        await run(tester, block(answer: 'Berlin'), pick: 'Rome'),
        isEmpty,
        reason: 'an answer outside the options cannot be checked',
      );
      expect(await run(tester, block(answer: ''), pick: 'Rome'), isEmpty);
    });
  });

  group('GapSignalService.proposeForLesson', () {
    GapSuggestion? propose(
      Map<String, bool> answers, {
      Set<String> dismissed = const {},
    }) => GapSignalService.proposeForLesson(
      firstAnswers: answers,
      library: library,
      dismissed: dismissed,
      canOpen: (_) => true,
    );

    test('needs two different first-try misses', () {
      expect(propose({'a': false}), isNull);
      expect(propose({'a': false, 'b': true}), isNull);
      final s = propose({'a': false, 'b': false, 'c': true})!;
      expect(s.prerequisite.bridgeId, library.offerOrder.first.bridgeId);
      expect(s.reason, contains('2 of 3'));
    });

    test('dismissed Bridges are skipped, then nothing is left', () {
      final all = {for (final b in library.bridges) b.bridgeId};
      final first = library.offerOrder.first.bridgeId;
      expect(
        propose(
          {'a': false, 'b': false},
          dismissed: {first},
        )!.prerequisite.bridgeId,
        isNot(first),
      );
      expect(propose({'a': false, 'b': false}, dismissed: all), isNull);
    });
  });

  group('help button suggestion', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      required bool suggestions,
      Map<String, bool> answers = const {},
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          quickRescueEnabledProvider.overrideWithValue(true),
          autoGapSuggestionsEnabledProvider.overrideWithValue(suggestions),
          bridgeLibraryProvider.overrideWith((ref) async => library),
          supportSessionStoreProvider.overrideWithValue(SupportSessionStore()),
          supportOwnerScopeProvider.overrideWithValue('user-a'),
          supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
          supportStrategyProvider.overrideWithValue(
            PersistedLearningStrategy.standard,
          ),
        ],
      );
      addTearDown(container.dispose);
      container
              .read(lessonPracticeAttemptsProvider('excel-101').notifier)
              .state =
          answers;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  LearningHelpAction(
                    lessonId: 'excel-101',
                    lessonTitle: 'Budget Totals in Excel',
                    tags: ['excel'],
                  ),
                ],
              ),
              body: const Text('lesson body'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    bool dot(WidgetTester tester) => tester
        .widget<Badge>(find.byKey(const Key('learning_help_suggestion_dot')))
        .isLabelVisible;

    testWidgets('two misses: a dot, a suggestion, and "Not the issue"', (
      tester,
    ) async {
      final c = await pump(
        tester,
        suggestions: true,
        answers: {'synth-q-1': false, 'item:x': false},
      );
      expect(dot(tester), isTrue);
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('support_lesson_suggestion')),
        findsOneWidget,
      );
      expect(find.textContaining('missed 2 of 2'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('support_lesson_suggestion_not_the_issue')),
      );
      await tester.pumpAndSettle();
      expect(c.read(lessonGapDismissedProvider('excel-101')), {
        library.offerOrder.first.bridgeId,
      });
    });

    testWidgets('accepting opens the suggested Bridge with Back kept', (
      tester,
    ) async {
      await pump(tester, suggestions: true, answers: {'a': false, 'b': false});
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('support_lesson_suggestion_open')));
      await tester.pumpAndSettle();
      expect(find.text(library.offerOrder.first.title), findsWidgets);
      expect(find.byKey(const Key('bridge-back-action')), findsOneWidget);
    });

    testWidgets('one miss: no dot', (tester) async {
      await pump(tester, suggestions: true, answers: {'a': false});
      expect(dot(tester), isFalse);
    });

    testWidgets('suggestions OFF: no dot and no suggestion', (tester) async {
      await pump(tester, suggestions: false, answers: {'a': false, 'b': false});
      expect(dot(tester), isFalse);
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('support_lesson_suggestion')), findsNothing);
    });
  });

  test('only the first answer per item is kept', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(lessonPracticeAttemptsProvider('l').notifier);
    // Mirror recordLessonPractice without a WidgetRef.
    void record(String id, bool ok) {
      if (!n.state.containsKey(id)) n.state = {...n.state, id: ok};
    }

    record('q1', false);
    record('q1', true);
    expect(c.read(lessonPracticeAttemptsProvider('l')), {'q1': false});
  });

  testWidgets('the block renderer passes the block id through', (tester) async {
    final seen = <(String, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LessonBlockRenderer(
              block: LessonBlock(
                id: 'synth-q-9',
                lessonId: 'l1',
                sortOrder: 0,
                blockType: LessonBlockType.practicePrompt,
                content: {
                  'prompt': 'Two plus two?',
                  'options': ['3', '4'],
                  'answer': '4',
                },
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              onPracticeChecked: (id, ok) => seen.add((id, ok)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(seen, [('synth-q-9', false)]);
  });
}
