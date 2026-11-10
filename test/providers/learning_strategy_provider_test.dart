import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';

void main() {
  group('TEL-01B FastPreferenceStore & LearningStrategyNotifier', () {
    test(
      'Atomic compare-and-set increments revision on match, replays idempotently on same mutationId, and rejects stale expectedRevision without clobbering',
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
          store.getOrDefault(contextId: 'server-uuid-ctx', userId: 'user-1').optionalTotalMinutes,
          30,
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
  });
}
