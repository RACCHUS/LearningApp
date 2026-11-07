import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/casestudy/case_study_service.dart';

void main() {
  group('CaseStudyService Tests', () {
    test('contains curated realistic occupational scenarios', () {
      final service = CaseStudyService();
      final scenarios = service.getAllScenarios();
      expect(scenarios, isNotEmpty);

      final scaffold = scenarios.first;
      expect(scaffold.title, contains('Scaffolding'));
      expect(scaffold.steps, isNotEmpty);
      expect(scaffold.steps.first.choices.length, greaterThanOrEqualTo(2));
      expect(scaffold.steps.first.choices.any((c) => c.isOptimal), isTrue);
    });

    test('getScenarioById returns matching scenario or null', () {
      final service = CaseStudyService();
      final scenario = service.getScenarioById('case_osha_scaffold_1');
      expect(scenario, isNotNull);
      expect(scenario!.domain, equals('OSHA Workplace Safety'));

      final missing = service.getScenarioById('non-existent');
      expect(missing, isNull);
    });

    test('getScenariosByDomain filters correctly', () {
      final service = CaseStudyService();
      final matches = service.getScenariosByDomain('OSHA Workplace Safety');
      expect(matches, isNotEmpty);
      expect(matches.first.domain, equals('OSHA Workplace Safety'));
    });
  });
}
