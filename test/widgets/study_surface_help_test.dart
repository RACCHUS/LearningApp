import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:learning_pwa/widgets/learning_support/study_help_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Master plan v2.6 §21: Learning help on the study screens opened from a
/// lesson, not only in Lesson mode.
void main() {
  late BridgeLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, {StudyHelpContext? help}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 11, 19);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canSpeakProvider.overrideWithValue(false),
          readAloudOffProvider.overrideWithValue(false),
          canListenProvider.overrideWithValue(false),
          quickRescueEnabledProvider.overrideWithValue(true),
          bridgeLibraryProvider.overrideWith((ref) async => library),
          supportSessionStoreProvider.overrideWithValue(SupportSessionStore()),
          supportOwnerScopeProvider.overrideWithValue('user-a'),
          supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
          supportStrategyProvider.overrideWithValue(
            PersistedLearningStrategy.standard,
          ),
        ],
        child: MaterialApp(
          home: ConceptScreen(
            helpContext: help,
            concepts: [
              ConceptContent(
                id: 'c1',
                lessonId: 'excel-101',
                conceptText: 'Percent format shows the value times 100',
                order: 0,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opened from an Excel lesson: help is offered and Back '
      'returns to the concept', (tester) async {
    await pump(
      tester,
      help: const StudyHelpContext(
        lessonId: 'excel-101',
        lessonTitle: 'Budget Totals in Excel',
        tags: ['excel'],
      ),
    );
    await tester.tap(find.byKey(const Key('learning_help_action')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('support_choice_bridge-percent-change')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bridge-back-action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bridge-back-action')));
    await tester.pumpAndSettle();
    expect(find.byType(ConceptScreen), findsOneWidget);
    expect(find.byKey(const Key('bridge-back-action')), findsNothing);
  });

  testWidgets('no lesson context (e.g. a study set): no help button', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('learning_help_action')), findsNothing);
  });

  testWidgets('a lesson outside the pilot: no help button', (tester) async {
    await pump(
      tester,
      help: const StudyHelpContext(
        lessonId: 'bio-1',
        lessonTitle: 'Cells',
        tags: ['biology'],
      ),
    );
    expect(find.byKey(const Key('learning_help_action')), findsNothing);
  });
}
