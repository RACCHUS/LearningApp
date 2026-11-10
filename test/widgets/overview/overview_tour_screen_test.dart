import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';
import 'package:learning_pwa/screens/overview/overview_tour_screen.dart';
import 'package:learning_pwa/widgets/library/quick_overview_entry.dart';

class _SpyContextsNotifier extends LearningContextsNotifier {
  int createOrSwitchCalls = 0;

  _SpyContextsNotifier() : super.stub(const LearningContextsState());

  @override
  Future<LearningContext?> createOrSwitch({
    required String userId,
    required String label,
    required ContextRootType rootType,
    required String rootId,
    String? emoji,
    String? targetVersionId,
    String? activeFocusType,
    String? activeFocusId,
    ScopeMode scopeMode = ScopeMode.coreAndPrerequisites,
    Map<String, dynamic> scopeConfig = const {},
  }) async {
    createOrSwitchCalls++;
    return null;
  }
}

void main() {
  group('TEL-03 OverviewTourScreen & QuickOverviewEntry Widget Tests', () {
    testWidgets(
      'Opening OverviewTourScreen, switching 5/15/30 presets, and answering transient self-check performs zero context or progress writes',
      (tester) async {
        final spyNotifier = _SpyContextsNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningContextsProvider.overrideWith((ref) => spyNotifier),
              learnerIdProvider.overrideWithValue('learner-test'),
            ],
            child: const MaterialApp(
              home: OverviewTourScreen(
                targetSlugOrId: 'clep-introductory-psychology',
                initialPreset: OverviewDurationPreset.fifteenMinutes,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Read-only disclosure banner and 7 topic families are visible
        expect(
          find.byKey(const Key('overview-readonly-disclosure-banner')),
          findsOneWidget,
        );
        expect(find.text('Foundations and method'), findsOneWidget);
        expect(find.text('People together'), findsOneWidget);

        // Zero contexts created on open
        expect(spyNotifier.state.contexts, isEmpty);
        expect(spyNotifier.createOrSwitchCalls, 0);

        // Switch to 5-minute preset: vocabulary cards are hidden
        await tester.tap(find.text('5 min'));
        await tester.pumpAndSettle();
        expect(find.text('Essential vocabulary'), findsNothing);

        // Switch to 30-minute preset: transient self-check appears
        await tester.tap(find.text('30 min'));
        await tester.pumpAndSettle();

        final checkFinder = find.byKey(
          const Key('overview-transient-check-ov-check-1'),
        );
        await tester.ensureVisible(checkFinder);
        expect(checkFinder, findsOneWidget);

        // Tap an option in the transient self-check
        final optionFinder = find.byKey(
          const Key('overview-check-ov-check-1-option-1'),
        );
        await tester.ensureVisible(optionFinder);
        await tester.tap(optionFinder);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('overview-check-ov-check-1-feedback')),
          findsOneWidget,
        );

        // Still zero context or persistence writes!
        expect(spyNotifier.state.contexts, isEmpty);
        expect(spyNotifier.createOrSwitchCalls, 0);
      },
    );

    testWidgets(
      'Flag-off regression hides QuickOverviewEntry and renders unavailable state on OverviewTourScreen',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              telFeatureFlagsProvider.overrideWith(
                (ref) => TelFeatureFlags.disabled,
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    QuickOverviewEntry(
                      targetId: 'a0000000-0000-0000-0000-000000000001',
                      targetSlug: 'clep-introductory-psychology',
                    ),
                    Expanded(
                      child: OverviewTourScreen(
                        targetSlugOrId: 'clep-introductory-psychology',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const Key(
              'quick-overview-entry-a0000000-0000-0000-0000-000000000001',
            ),
          ),
          findsNothing,
        );
        expect(
          find.text('Quick overview is not available for this topic yet.'),
          findsOneWidget,
        );
      },
    );
  });
}
