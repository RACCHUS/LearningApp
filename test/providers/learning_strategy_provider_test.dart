import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/fast_plan_result.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';
import 'package:learning_pwa/services/learning_context_sync_service.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import 'package:learning_pwa/widgets/learn/learning_approach_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestContextsNotifier extends LearningContextsNotifier {
  _TestContextsNotifier([LearningContextsState? initial])
      : super.stub(initial ?? const LearningContextsState());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TEL-01B & TEL-04A FastPreferenceStore & LearningStrategyNotifier', () {
    test(
      'Atomic compare-and-set increments revision on match, replays idempotently on same mutationId, and rejects stale expectedRevision (including non-zero first write) without clobbering',
      () {
        final store = FastPreferenceStore();
        final notifier = LearningStrategyNotifier(
          store: store,
          activeUserId: 'user-1',
        );

        // Initial default is Standard at revision 0
        final initial = notifier.preferenceForContext('ctx-1');
        expect(initial.strategy, PersistedLearningStrategy.standard);
        expect(initial.revision, 0);

        // Non-zero expectedRevision on first write when no preference exists yet must conflict
        expect(
          () => notifier.setStrategy(
            contextId: 'ctx-1',
            strategy: PersistedLearningStrategy.fast,
            expectedRevision: 2,
            mutationId: 'mut-invalid-first-write',
          ),
          throwsA(isA<FastPreferenceConflictException>()),
        );
        expect(
          notifier.preferenceForContext('ctx-1').strategy,
          PersistedLearningStrategy.standard,
        );
        expect(notifier.preferenceForContext('ctx-1').revision, 0);
        notifier.dismissConflict('ctx-1');

        // Valid CAS update from rev 0 -> rev 1
        final rev1 = notifier.setStrategy(
          contextId: 'ctx-1',
          strategy: PersistedLearningStrategy.fast,
          expectedRevision: 0,
          mutationId: 'mut-A',
        );
        expect(rev1.strategy, PersistedLearningStrategy.fast);
        expect(rev1.revision, 1);
        expect(rev1.lastMutationId, 'mut-A');

        // Idempotent replay with same mutationId ('mut-A') does not bump revision
        final replay = notifier.setStrategy(
          contextId: 'ctx-1',
          strategy: PersistedLearningStrategy.fast,
          expectedRevision: 0,
          mutationId: 'mut-A',
        );
        expect(replay.revision, 1);

        // Stale CAS update with expectedRevision: 0 (when authoritative is 1) throws conflict
        expect(
          () => notifier.setStrategy(
            contextId: 'ctx-1',
            strategy: PersistedLearningStrategy.standard,
            expectedRevision: 0,
            mutationId: 'mut-stale',
          ),
          throwsA(isA<FastPreferenceConflictException>()),
        );

        // Authoritative state remains Fast at revision 1, and conflict is recorded
        expect(
          notifier.preferenceForContext('ctx-1').strategy,
          PersistedLearningStrategy.fast,
        );
        expect(notifier.preferenceForContext('ctx-1').revision, 1);
        expect(notifier.state.conflictFor('ctx-1'), isNotNull);

        notifier.dismissConflict('ctx-1');
        expect(notifier.state.conflictFor('ctx-1'), isNull);
      },
    );

    test(
      'rekeyContext migrates preference and queued offline mutations when client context ID reconciles with server UUID',
      () {
        final store = FastPreferenceStore();
        final notifier = LearningStrategyNotifier(
          store: store,
          activeUserId: 'user-1',
        );

        notifier.setStrategy(
          contextId: 'temp-local-ctx',
          strategy: PersistedLearningStrategy.fast,
          expectedRevision: 0,
          mutationId: 'mut-local-1',
        );
        store.enqueueOfflineMutation(
          PendingFastPreferenceMutation(
            mutationId: 'mut-offline-2',
            contextId: 'temp-local-ctx',
            userId: 'user-1',
            expectedRevision: 1,
            strategy: PersistedLearningStrategy.fast,
            optionalTotalMinutes: 30,
            queuedAt: DateTime.utc(2026, 11, 10),
          ),
        );

        notifier.rekeyContext(
          oldContextId: 'temp-local-ctx',
          newContextId: 'server-uuid-ctx',
        );

        final migrated = notifier.preferenceForContext('server-uuid-ctx');
        expect(migrated.contextId, 'server-uuid-ctx');
        expect(migrated.strategy, PersistedLearningStrategy.fast);
        expect(migrated.revision, 1);
        expect(
          store.pendingOfflineMutations.single.contextId,
          'server-uuid-ctx',
        );

        final conflicts = store.flushOfflineQueue();
        expect(conflicts, isEmpty);
        expect(
          store
              .getOrDefault(contextId: 'server-uuid-ctx', userId: 'user-1')
              .optionalTotalMinutes,
          30,
        );
      },
    );

    test(
      'TEL-04A: Fast preferences, manual skips, time budget, and offline queue survive app reload via SharedPreferences',
      () async {
        final store1 = FastPreferenceStore();
        final notifier1 = LearningStrategyNotifier(
          store: store1,
          activeUserId: 'user-reload',
        );

        notifier1.setStrategy(
          contextId: 'ctx-persist',
          strategy: PersistedLearningStrategy.fast,
          optionalTotalMinutes: 45,
          manualSkippedActivityIds: const {'lesson-skip-1'},
          mutationId: 'mut-persist-1',
        );
        store1.enqueueOfflineMutation(
          PendingFastPreferenceMutation(
            mutationId: 'mut-queued-2',
            contextId: 'ctx-persist',
            userId: 'user-reload',
            expectedRevision: 1,
            strategy: PersistedLearningStrategy.fast,
            optionalTotalMinutes: 60,
            manualSkippedActivityIds: const {'lesson-skip-1', 'lesson-skip-2'},
            queuedAt: DateTime.utc(2026, 11, 10, 12),
          ),
        );

        await store1.flushPersistence();

        // Simulate full app restart with a brand-new store and notifier
        final store2 = FastPreferenceStore();
        final notifier2 = LearningStrategyNotifier(
          store: store2,
          activeUserId: 'user-reload',
        );
        await notifier2.ensureHydrated();

        final restored = notifier2.preferenceForContext('ctx-persist');
        expect(restored.strategy, PersistedLearningStrategy.fast);
        expect(restored.revision, 1);
        expect(restored.optionalTotalMinutes, 45);
        expect(restored.manualSkippedActivityIds, contains('lesson-skip-1'));
        expect(store2.pendingOfflineMutations.length, 1);
        expect(
          store2.pendingOfflineMutations.single.mutationId,
          'mut-queued-2',
        );
      },
    );

    test(
      'TEL-04A: LearningContextsNotifier.notifyContextRekeyed automatically migrates LearningStrategyNotifier state',
      () {
        final contextsNotifier = _TestContextsNotifier();
        final store = FastPreferenceStore();
        final strategyNotifier = LearningStrategyNotifier(
          store: store,
          activeUserId: 'user-sync',
        );

        void listener(String oldId, String newId) {
          strategyNotifier.rekeyContext(
            oldContextId: oldId,
            newContextId: newId,
          );
        }

        contextsNotifier.addRekeyListener(listener);
        addTearDown(() => contextsNotifier.removeRekeyListener(listener));

        strategyNotifier.setStrategy(
          contextId: 'local-temp-uuid',
          strategy: PersistedLearningStrategy.fast,
          optionalTotalMinutes: 25,
        );

        contextsNotifier.notifyContextRekeyed(
          'local-temp-uuid',
          'remote-canonical-uuid',
        );

        final afterSync = strategyNotifier.preferenceForContext(
          'remote-canonical-uuid',
        );
        expect(afterSync.strategy, PersistedLearningStrategy.fast);
        expect(afterSync.optionalTotalMinutes, 25);
        expect(
          strategyNotifier.state.preferencesByContextId.containsKey(
            'local-temp-uuid',
          ),
          isFalse,
        );
      },
    );

    test(
      'TEL-04A: Server-backed cross-device CAS sync propagates preferences between devices, detects cross-device revision conflicts, and never touches LearningContext.scopeConfig',
      () async {
        final serverStore = <String, FastPreference>{};

        Future<FastPreferenceRemoteCasResult> simulatedServerCas(
          PendingFastPreferenceMutation mutation,
        ) async {
          final current = serverStore[mutation.contextId];
          if (current != null) {
            if (current.lastMutationId == mutation.mutationId) {
              return FastPreferenceRemoteCasResult(
                conflicted: false,
                authoritativePreference: current,
              );
            }
            if (current.revision != mutation.expectedRevision) {
              return FastPreferenceRemoteCasResult(
                conflicted: true,
                authoritativePreference: current,
              );
            }
          } else if (mutation.expectedRevision != 0) {
            final defaultBaseline = FastPreference.defaultStandard(
              contextId: mutation.contextId,
              userId: mutation.userId,
            );
            return FastPreferenceRemoteCasResult(
              conflicted: true,
              authoritativePreference: defaultBaseline,
            );
          }
          final updated = FastPreference(
            contextId: mutation.contextId,
            userId: mutation.userId,
            strategy: mutation.strategy,
            revision: mutation.expectedRevision + 1,
            updatedAtServer: mutation.queuedAt,
            lastMutationId: mutation.mutationId,
            optionalTotalMinutes: mutation.optionalTotalMinutes,
            optionalDeadline: mutation.optionalDeadline,
            manualSkippedActivityIds: mutation.manualSkippedActivityIds,
          );
          serverStore[mutation.contextId] = updated;
          return FastPreferenceRemoteCasResult(
            conflicted: false,
            authoritativePreference: updated,
          );
        }

        // Device A sets Fast strategy (rev 0 -> rev 1) and syncs to server
        final deviceAStore = FastPreferenceStore(
          remoteCasCallback: simulatedServerCas,
        );
        final deviceANotifier = LearningStrategyNotifier(
          store: deviceAStore,
          activeUserId: 'user-cross-device',
        );
        deviceANotifier.setStrategy(
          contextId: 'ctx-shared',
          strategy: PersistedLearningStrategy.fast,
          optionalTotalMinutes: 35,
          mutationId: 'mut-device-a-1',
        );
        await deviceANotifier.flushRemoteSync();
        expect(serverStore['ctx-shared']?.revision, 1);
        expect(
          serverStore['ctx-shared']?.strategy,
          PersistedLearningStrategy.fast,
        );

        // Device B pulls server preferences during context sync
        final deviceBStore = FastPreferenceStore(
          remoteCasCallback: simulatedServerCas,
        );
        final deviceBNotifier = LearningStrategyNotifier(
          store: deviceBStore,
          activeUserId: 'user-cross-device',
        );
        deviceBNotifier.reconcileRemotePreferences(serverStore);

        final deviceBPref = deviceBNotifier.preferenceForContext('ctx-shared');
        expect(deviceBPref.strategy, PersistedLearningStrategy.fast);
        expect(deviceBPref.revision, 1);
        expect(deviceBPref.optionalTotalMinutes, 35);

        // Device C (stale at rev 0) attempts to push a conflicting update (expectedRevision: 0)
        final deviceCStore = FastPreferenceStore(
          remoteCasCallback: simulatedServerCas,
        );
        final deviceCNotifier = LearningStrategyNotifier(
          store: deviceCStore,
          activeUserId: 'user-cross-device',
        );
        deviceCNotifier.setStrategy(
          contextId: 'ctx-shared',
          strategy: PersistedLearningStrategy.standard,
          expectedRevision: 0,
          mutationId: 'mut-device-c-stale',
        );
        await deviceCNotifier.flushRemoteSync();

        // Device C receives authoritative server state (Fast, rev 1) and surfaces conflict banner state
        expect(
          deviceCNotifier.preferenceForContext('ctx-shared').strategy,
          PersistedLearningStrategy.fast,
        );
        expect(deviceCNotifier.preferenceForContext('ctx-shared').revision, 1);
        expect(deviceCNotifier.state.conflictFor('ctx-shared'), isNotNull);

        // Verify LearningContext.scopeConfig and ScopeResolver.computeConfigHash remain completely untouched
        final baseContext = LearningContext(
          id: 'ctx-shared',
          userId: 'user-cross-device',
          label: 'CLEP Introductory Psychology',
          rootType: ContextRootType.target,
          rootId: '00000000-0000-4000-8000-000000000101',
          lastActiveAt: DateTime.utc(2026, 11, 10),
        );
        expect(baseContext.scopeConfig.containsKey('fast_preference'), isFalse);
        expect(
          ScopeResolver.computeConfigHash(baseContext),
          equals('v2:user-cross-device::coreAndPrerequisites::{}'),
        );
      },
    );

    test(
      'User isolation and TelFeatureFlags.disabled fallback to Standard',
      () {
        final store = FastPreferenceStore();
        final userANotifier = LearningStrategyNotifier(
          store: store,
          activeUserId: 'user-A',
        );
        userANotifier.setStrategy(
          contextId: 'shared-ctx-id',
          strategy: PersistedLearningStrategy.fast,
        );

        // User B never sees User A's preference on the same contextId
        final userBNotifier = LearningStrategyNotifier(
          store: store,
          activeUserId: 'user-B',
        );
        expect(
          userBNotifier.preferenceForContext('shared-ctx-id').strategy,
          PersistedLearningStrategy.standard,
        );

        // Flag-off forces effectiveStrategyFor to return Standard even for User A
        final ctx = LearningContext(
          id: 'shared-ctx-id',
          userId: 'user-A',
          label: 'CLEP Introductory Psychology',
          rootType: ContextRootType.target,
          rootId: 'a0000000-0000-0000-0000-000000000001',
          lastActiveAt: DateTime.utc(2026, 11, 10),
        );
        expect(
          userANotifier.effectiveStrategyFor(
            context: ctx,
            flags: TelFeatureFlags.disabled,
          ),
          PersistedLearningStrategy.standard,
        );
      },
    );

    test(
      'TEL-04A: Late-subscriber replay and independent remote fetch prevent fresh devices from missing synced Fast preferences',
      () async {
        // 1. Late-subscriber replay: LearningContextsNotifier finishes syncing BEFORE LearningStrategyNotifier subscribes
        final contextsNotifier = _TestContextsNotifier();
        final syncedSnapshot = {
          'ctx-late': FastPreference(
            contextId: 'ctx-late',
            userId: 'user-fresh-device',
            strategy: PersistedLearningStrategy.fast,
            revision: 3,
            updatedAtServer: DateTime.utc(2026, 11, 10, 14),
            lastMutationId: 'mut-remote-3',
            optionalTotalMinutes: 60,
          ),
        };
        contextsNotifier.notifyRemoteFastPreferencesSynced(syncedSnapshot);

        final lateStore = FastPreferenceStore();
        final lateNotifier = LearningStrategyNotifier(
          store: lateStore,
          activeUserId: 'user-fresh-device',
        );
        contextsNotifier.addRemoteFastPreferencesListener(
          lateNotifier.reconcileRemotePreferences,
        );

        final replayedPref = lateNotifier.preferenceForContext('ctx-late');
        expect(replayedPref.strategy, PersistedLearningStrategy.fast);
        expect(replayedPref.revision, 3);
        expect(replayedPref.optionalTotalMinutes, 60);

        // 2. Independent remote fetch on LearningStrategyNotifier initialization even without LearningContextsNotifier
        final independentStore = FastPreferenceStore(
          remoteFetchCallback: (userId) async => {
            'ctx-independent': FastPreference(
              contextId: 'ctx-independent',
              userId: userId,
              strategy: PersistedLearningStrategy.fast,
              revision: 2,
              updatedAtServer: DateTime.utc(2026, 11, 10, 15),
              lastMutationId: 'mut-remote-2',
              manualSkippedActivityIds: const {'lesson-skip-x'},
            ),
          },
        );
        final independentNotifier = LearningStrategyNotifier(
          store: independentStore,
          activeUserId: 'user-independent',
        );
        await independentNotifier.ensureHydrated();

        final fetchedPref = independentNotifier.preferenceForContext(
          'ctx-independent',
        );
        expect(fetchedPref.strategy, PersistedLearningStrategy.fast);
        expect(fetchedPref.revision, 2);
        expect(fetchedPref.manualSkippedActivityIds, contains('lesson-skip-x'));
      },
    );

    testWidgets(
      'TEL-04A: FastPlanCoverageSheet exposes optional time-budget chips and per-activity manual-skip toggles with truthful manual_skip disclosure',
      (tester) async {
        final store = FastPreferenceStore();
        final activeCtx = LearningContext(
          id: 'ctx-ui-test',
          userId: 'user-ui',
          label: 'CLEP Introductory Psychology',
          rootType: ContextRootType.target,
          rootId: '00000000-0000-4000-8000-000000000101',
          lastActiveAt: DateTime.utc(2026, 11, 10),
        );

        final samplePlan = FastPlanResult(
          contextId: activeCtx.id,
          asOf: DateTime.utc(2026, 11, 10),
          activeStrategy: PersistedLearningStrategy.fast,
          fullOrderedCandidates: const [
            RecommendedActivity(
              activityId: 'lesson-bio-bases',
              title: 'Biological Bases of Behavior',
              rank: 1,
              actionClass: FastCandidateActionClass.recommended,
              primaryDomainId: 'BIO',
              primaryDomainTitle: 'Biological Bases of Behavior',
              primaryDomainWeight: 0.085,
              depthTier: DepthTier.core,
              canonicalOrderIndex: 0,
              estimatedMinutes: 15,
              estimateQuality: EstimateQuality.authored,
              reasonCodes: ['UNCOVERED_BREADTH_DOMAIN'],
              userFacingRationale: 'Covers Biological Bases of Behavior (8–9%)',
              evidenceStatus: EvidenceStatusLabel.notAssessed,
            ),
          ],
          provisionalBudgetSchedule: const [],
          domainCoverage: const [
            DomainCoverageSummary(
              domainId: 'BIO',
              title: 'Biological Bases of Behavior',
              publishedWeightRangeLabel: '8–9%',
              normalizedModelWeight: 0.085,
              evidenceStatus: EvidenceStatusLabel.notAssessed,
              mappedActivityIds: ['lesson-bio-bases'],
              completedActivityIds: [],
              isCoverageMissing: false,
              isCoveredInProvisionalBudget: true,
            ),
          ],
          budgetFeasibility: BudgetFeasibilityStatus.noBudgetSpecified,
          knownDurationSubtotalMinutes: 15,
          remainingUnknownTimeCount: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fastPreferenceStoreProvider.overrideWithValue(store),
              learnerIdProvider.overrideWithValue('user-ui'),
              learningContextsProvider.overrideWith(
                (_) => _TestContextsNotifier(
                  LearningContextsState(
                    contexts: [activeCtx],
                    activeId: activeCtx.id,
                  ),
                ),
              ),
              activeFastPlanProvider.overrideWith((_) async => samplePlan),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: FastPlanCoverageSheet(contextId: 'ctx-ui-test'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select 30 min time budget chip
        final chip30 = find.byKey(const Key('fast-budget-chip-30'));
        expect(chip30, findsOneWidget);
        await tester.tap(chip30);
        await tester.pumpAndSettle();

        expect(
          store
              .getOrDefault(contextId: 'ctx-ui-test', userId: 'user-ui')
              .optionalTotalMinutes,
          30,
        );

        // Toggle manual skip on lesson-bio-bases
        final skipBtn = find.byKey(
          const Key('fast-manual-skip-toggle-lesson-bio-bases'),
        );
        expect(skipBtn, findsOneWidget);
        await tester.tap(skipBtn);
        await tester.pumpAndSettle();

        expect(
          store
              .getOrDefault(contextId: 'ctx-ui-test', userId: 'user-ui')
              .manualSkippedActivityIds,
          contains('lesson-bio-bases'),
        );
        expect(
          find.text(
            'Skipped by learner preference (topic remains unassessed)',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
