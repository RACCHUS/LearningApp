import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/pathway_readiness_provider.dart';
import 'package:learning_pwa/services/pathway_readiness_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PathwayReadinessService', () {
    test('loads empty state initially', () async {
      final service = PathwayReadinessService();
      final state = await service.loadReadiness('fl_bon:registered-nurse');

      expect(state.pathwayKey, equals('fl_bon:registered-nurse'));
      expect(state.selectedRouteIndex, isNull);
      expect(state.selectedRouteLabel, isNull);
      expect(state.completedStepLabels, isEmpty);
    });

    test('selects route and persists to storage', () async {
      final service = PathwayReadinessService();
      final updated = await service.selectRoute(
        'fl_bon:registered-nurse',
        0,
        'Florida-approved nursing program',
      );

      expect(updated.selectedRouteIndex, equals(0));
      expect(updated.selectedRouteLabel, equals('Florida-approved nursing program'));

      // Reload from storage
      final reloaded = await service.loadReadiness('fl_bon:registered-nurse');
      expect(reloaded.selectedRouteIndex, equals(0));
      expect(reloaded.selectedRouteLabel, equals('Florida-approved nursing program'));
    });

    test('toggles step completion and persists to storage', () async {
      final service = PathwayReadinessService();
      const step = 'Complete electronic fingerprinting and Level 2 background screening';

      // Toggle ON
      final afterOn = await service.toggleStep('fl_bon:registered-nurse', step);
      expect(afterOn.isStepCompleted(step), isTrue);

      final reloadedOn = await service.loadReadiness('fl_bon:registered-nurse');
      expect(reloadedOn.isStepCompleted(step), isTrue);

      // Toggle OFF
      final afterOff = await service.toggleStep('fl_bon:registered-nurse', step);
      expect(afterOff.isStepCompleted(step), isFalse);

      final reloadedOff = await service.loadReadiness('fl_bon:registered-nurse');
      expect(reloadedOff.isStepCompleted(step), isFalse);
    });

    test('links standalone state to target goal', () async {
      final service = PathwayReadinessService();
      await service.selectRoute(
        'fl_bon:registered-nurse',
        2,
        'Out-of-state nursing program',
      );
      await service.toggleStep('fl_bon:registered-nurse', 'Fingerprints');

      // Link to a new private target
      final linked = await service.linkToGoal(
        targetId: 'goal-999',
        pathwayKey: 'fl_bon:registered-nurse',
      );

      expect(linked.targetId, equals('goal-999'));
      expect(linked.selectedRouteIndex, equals(2));
      expect(linked.isStepCompleted('Fingerprints'), isTrue);

      // Loading with targetId recovers the state
      final loadedGoal = await service.loadReadiness(
        'fl_bon:registered-nurse',
        targetId: 'goal-999',
      );
      expect(loadedGoal.targetId, equals('goal-999'));
      expect(loadedGoal.selectedRouteIndex, equals(2));
      expect(loadedGoal.isStepCompleted('Fingerprints'), isTrue);
    });

    test('resets state cleanly', () async {
      final service = PathwayReadinessService();
      await service.selectRoute(
        'fl_bon:registered-nurse',
        1,
        'ACEN/CCNE',
      );
      await service.toggleStep('fl_bon:registered-nurse', 'Step 1');

      final resetState = await service.reset('fl_bon:registered-nurse');
      expect(resetState.selectedRouteIndex, isNull);
      expect(resetState.completedStepLabels, isEmpty);
    });
  });

  group('PathwayReadinessNotifier Integration', () {
    test('StateNotifier loads and updates reactively', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const key = (
        pathwayKey: 'fl_bon:registered-nurse',
        targetId: 'goal-1',
      );

      // Initial read
      final initial = container.read(pathwayReadinessProvider(key));
      expect(initial, isA<AsyncLoading>());

      // Wait for async load
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final loaded = container.read(pathwayReadinessProvider(key));
      expect(loaded.value?.pathwayKey, equals('fl_bon:registered-nurse'));
      expect(loaded.value?.targetId, equals('goal-1'));

      // Select route
      await container
          .read(pathwayReadinessProvider(key).notifier)
          .selectRoute(0, 'Route 0');

      final afterRoute = container.read(pathwayReadinessProvider(key));
      expect(afterRoute.value?.selectedRouteIndex, equals(0));

      // Toggle step
      await container
          .read(pathwayReadinessProvider(key).notifier)
          .toggleStep('Step A');

      final afterStep = container.read(pathwayReadinessProvider(key));
      expect(afterStep.value?.isStepCompleted('Step A'), isTrue);
    });
  });
}
