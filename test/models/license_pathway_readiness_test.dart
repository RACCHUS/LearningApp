import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/license_pathway_readiness.dart';

void main() {
  final sampleTree = {
    'op': 'all',
    'children': [
      {
        'op': 'any',
        'children': [
          {
            'op': 'step',
            'label': 'Graduate from a Florida-approved nursing education program',
            'stage': 'education',
            'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
          },
          {
            'op': 'step',
            'label': 'Graduate from an ACEN- or CCNE-accredited nursing program with NCLEX code',
            'stage': 'education',
            'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
          },
          {
            'op': 'step',
            'label': 'Graduate from an international or non-NCSBN program',
            'stage': 'education',
            'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
            'condition': 'Requires Board equivalency determination',
          },
        ],
      },
      {
        'op': 'step',
        'label': 'Provide applicable education documentation to the Florida Board of Nursing',
        'stage': 'application',
        'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
      },
      {
        'op': 'step',
        'label': 'Complete electronic fingerprinting and Level 2 background screening',
        'stage': 'background_screening',
        'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
      },
      {
        'op': 'step',
        'label': 'Submit initial licensure application and fees',
        'stage': 'application',
        'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
      },
      {
        'op': 'step',
        'label': 'Obtain Board approval for NCLEX eligibility and pass the NCLEX examination',
        'stage': 'examination',
        'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
      },
      {
        'op': 'step',
        'label': 'Receive Florida license after meeting all licensing criteria',
        'stage': 'authorization',
        'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
      },
    ],
  };

  group('PathwayTreeParser', () {
    test('extracts alternative route options from op:any group', () {
      final routes = PathwayTreeParser.extractRoutes(sampleTree);
      expect(routes.length, equals(3));
      expect(routes[0].index, equals(0));
      expect(routes[0].label, contains('Florida-approved'));
      expect(routes[1].label, contains('ACEN- or CCNE-accredited'));
      expect(routes[2].condition, equals('Requires Board equivalency determination'));
    });

    test('extracts all steps when no route is selected', () {
      final steps = PathwayTreeParser.extractApplicableSteps(sampleTree);
      // 3 alternatives + 5 common steps = 8
      expect(steps.length, equals(8));
      expect(steps.where((s) => s.isRouteAlternative).length, equals(3));
      expect(steps.where((s) => !s.isRouteAlternative).length, equals(5));
    });

    test('filters to specific route when selectedRouteLabel is provided', () {
      final selectedRoute =
          'Graduate from a Florida-approved nursing education program';
      final steps = PathwayTreeParser.extractApplicableSteps(
        sampleTree,
        selectedRouteLabel: selectedRoute,
      );
      // 1 chosen route + 5 common steps = 6
      expect(steps.length, equals(6));
      expect(steps.first.label, equals(selectedRoute));
      expect(steps.first.isRouteAlternative, isTrue);
      expect(steps.skip(1).every((s) => !s.isRouteAlternative), isTrue);
    });

    test('computes readiness progress correctly', () {
      final selectedRoute =
          'Graduate from a Florida-approved nursing education program';
      final steps = PathwayTreeParser.extractApplicableSteps(
        sampleTree,
        selectedRouteLabel: selectedRoute,
      );

      final completed = {
        selectedRoute,
        'Complete electronic fingerprinting and Level 2 background screening',
      };

      final readiness = PathwayTreeParser.computeReadiness(
        applicableSteps: steps,
        completedLabels: completed,
      );

      expect(readiness.totalSteps, equals(6));
      expect(readiness.completedSteps, equals(2));
      expect(readiness.ratio, closeTo(2 / 6, 0.001));
      expect(readiness.isComplete, isFalse);
    });

    test('computes isComplete when all applicable steps are checked', () {
      final selectedRoute =
          'Graduate from a Florida-approved nursing education program';
      final steps = PathwayTreeParser.extractApplicableSteps(
        sampleTree,
        selectedRouteLabel: selectedRoute,
      );

      final completed = steps.map((s) => s.label).toSet();

      final readiness = PathwayTreeParser.computeReadiness(
        applicableSteps: steps,
        completedLabels: completed,
      );

      expect(readiness.completedSteps, equals(6));
      expect(readiness.ratio, equals(1.0));
      expect(readiness.isComplete, isTrue);
    });
  });

  group('PathwayReadinessState', () {
    test('serializes to and from json cleanly', () {
      final state = PathwayReadinessState(
        pathwayKey: 'fl_bon:registered-nurse',
        targetId: 'target-123',
        selectedRouteIndex: 1,
        selectedRouteLabel: 'Graduate from an ACEN- or CCNE-accredited program',
        completedStepLabels: {'Step 1', 'Step 2'},
        lastUpdated: DateTime.utc(2026, 10, 16, 12, 0, 0),
      );

      final json = state.toJson();
      final revived = PathwayReadinessState.fromJson(json);

      expect(revived.pathwayKey, equals('fl_bon:registered-nurse'));
      expect(revived.targetId, equals('target-123'));
      expect(revived.selectedRouteIndex, equals(1));
      expect(revived.selectedRouteLabel, contains('ACEN- or CCNE-accredited'));
      expect(revived.completedStepLabels, containsAll({'Step 1', 'Step 2'}));
      expect(revived.isStepCompleted('Step 1'), isTrue);
      expect(revived.isStepCompleted('Step 3'), isFalse);
    });

    test('copyWith updates state immutably', () {
      final initial = PathwayReadinessState.empty('fl_bon:registered-nurse');
      final updated = initial.copyWith(
        selectedRouteIndex: 0,
        selectedRouteLabel: 'Route 0',
        completedStepLabels: {'Step 1'},
      );

      expect(initial.selectedRouteIndex, isNull);
      expect(updated.selectedRouteIndex, equals(0));
      expect(updated.completedStepLabels, contains('Step 1'));

      final cleared = updated.copyWith(clearRoute: true);
      expect(cleared.selectedRouteIndex, isNull);
      expect(cleared.selectedRouteLabel, isNull);
      expect(cleared.completedStepLabels, contains('Step 1'));
    });
  });
}
