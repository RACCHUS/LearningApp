import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';
import 'package:learning_pwa/screens/overview/overview_tour_screen.dart';
import 'package:learning_pwa/widgets/library/quick_overview_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpyContextsNotifier extends LearningContextsNotifier {
  int createOrSwitchCalls = 0;
  String? lastRootId;
  ContextRootType? lastRootType;

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
    lastRootId = rootId;
    lastRootType = rootType;
    final created = LearningContext(
      id: 'ctx-created-from-overview',
      userId: userId,
      label: label,
      rootType: rootType,
      rootId: rootId,
      targetVersionId: targetVersionId,
      emoji: emoji,
      lastActiveAt: DateTime.utc(2026, 11, 10),
    );
    state = LearningContextsState(
      contexts: [created],
      activeId: created.id,
      isLoading: false,
    );
    return created;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TEL-03 & TEL-04A OverviewTourScreen & QuickOverviewEntry Widget Tests', () {
    testWidgets(
      'Opening OverviewTourScreen, switching 5/15/30 presets, and answering transient self-check performs zero context or progress writes',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

        // Read-only disclosure banner and first topic family are visible
        expect(
          find.byKey(const Key('overview-readonly-disclosure-banner')),
          findsOneWidget,
        );
        expect(find.text('Foundations and method'), findsOneWidget);
        expect(find.text('Essential vocabulary'), findsWidgets);

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
        await tester.scrollUntilVisible(
          checkFinder,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
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

        // Scroll down to verify the 7th family ('People together') and provenance card
        await tester.scrollUntilVisible(
          find.text('People together'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('People together'), findsOneWidget);

        // Still zero context or persistence writes!
        expect(spyNotifier.state.contexts, isEmpty);
        expect(spyNotifier.createOrSwitchCalls, 0);
      },
    );

    testWidgets(
      'TEL-04A: Leaving Overview via Try Fast preserves canonical target UUID on created LearningContext and activates Fast strategy',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const canonicalTargetUuid = '00000000-0000-4000-8000-000000000101';
        final spyNotifier = _SpyContextsNotifier();
        final store = FastPreferenceStore();
        final router = GoRouter(
          initialLocation: '/overview',
          routes: [
            GoRoute(
              path: '/overview',
              builder: (_, __) => const OverviewTourScreen(
                targetSlugOrId: canonicalTargetUuid,
                targetSlug: 'clep-introductory-psychology',
                initialPreset: OverviewDurationPreset.fiveMinutes,
              ),
            ),
            GoRoute(
              path: '/learn',
              builder: (_, __) =>
                  const Scaffold(body: Text('Learn Destination')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningContextsProvider.overrideWith((ref) => spyNotifier),
              fastPreferenceStoreProvider.overrideWithValue(store),
              learnerIdProvider.overrideWithValue('learner-uuid-test'),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final tryFastFinder = find.byKey(const Key('overview-try-fast-button'));
        await tester.scrollUntilVisible(
          tryFastFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(tryFastFinder);
        await tester.pumpAndSettle();

        expect(spyNotifier.createOrSwitchCalls, 1);
        expect(spyNotifier.lastRootType, ContextRootType.target);
        expect(spyNotifier.lastRootId, canonicalTargetUuid);
        expect(
          store
              .getOrDefault(
                contextId: 'ctx-created-from-overview',
                userId: 'learner-uuid-test',
              )
              .strategy,
          PersistedLearningStrategy.fast,
        );
        expect(find.text('Learn Destination'), findsOneWidget);
      },
    );

    testWidgets(
      'TEL-04A: OverviewTourScreen blocks goal creation when only an unresolved slug is available and canonical target lookup fails',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final spyNotifier = _SpyContextsNotifier();
        final store = FastPreferenceStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningContextsProvider.overrideWith((ref) => spyNotifier),
              fastPreferenceStoreProvider.overrideWithValue(store),
              learnerIdProvider.overrideWithValue('learner-slug-only'),
            ],
            child: const MaterialApp(
              home: OverviewTourScreen(
                targetSlugOrId: 'clep-introductory-psychology',
                initialPreset: OverviewDurationPreset.fiveMinutes,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tryFastFinder = find.byKey(const Key('overview-try-fast-button'));
        await tester.scrollUntilVisible(
          tryFastFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(tryFastFinder);
        await tester.pumpAndSettle();

        // Must NOT create a goal with a non-UUID slug rootId
        expect(spyNotifier.createOrSwitchCalls, 0);
        expect(
          find.byKey(const Key('overview-target-resolution-error-banner')),
          findsOneWidget,
        );
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
