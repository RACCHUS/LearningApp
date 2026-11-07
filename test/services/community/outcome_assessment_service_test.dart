import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/services/community/outcome_assessment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutcomeAssessmentService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with seed outcome records proving verified pilot learning gains', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = OutcomeAssessmentService(prefs: prefs);

      expect(service.records, isNotEmpty);
      expect(service.records.length, greaterThanOrEqualTo(3));

      // Benchmark normalized gain check
      final highGainRecords =
          service.records.where((r) => r.gainCategory == LearningGainCategory.high);
      expect(highGainRecords, isNotEmpty);
    });

    test('returns diagnostic questions for specific pilot topics', () {
      final service = OutcomeAssessmentService();

      final oshaQuestions = service.getDiagnosticQuestionsForTopic('OSHA Safety & PPE');
      expect(oshaQuestions, isNotEmpty);
      expect(oshaQuestions.any((q) => q.conceptKey == 'hierarchy_of_controls'), isTrue);

      final driverQuestions = service.getDiagnosticQuestionsForTopic('Florida Road Signs');
      expect(driverQuestions, isNotEmpty);
      expect(driverQuestions.any((q) => q.conceptKey == 'traffic_signals'), isTrue);

      final foodQuestions = service.getDiagnosticQuestionsForTopic('Food Safety');
      expect(foodQuestions, isNotEmpty);
      expect(foodQuestions.any((q) => q.conceptKey == 'temp_danger_zone'), isTrue);
    });

    test('evaluates outcome and computes Hake normalized gain correctly', () {
      final service = OutcomeAssessmentService();

      // Test High Gain: pre 0.20, post 0.80 -> g = (0.80 - 0.20) / (1.0 - 0.20) = 0.60 / 0.80 = 0.75 (High)
      final recordHigh = service.evaluateOutcome(
        participantId: 'learner_test_1',
        cohortId: 'cohort_b_family_osha',
        topic: 'OSHA Workplace Safety',
        preScore: 0.20,
        postScore: 0.80,
      );

      expect(recordHigh.normalizedGain, closeTo(0.75, 0.01));
      expect(recordHigh.gainCategory, equals(LearningGainCategory.high));

      // Test Medium Gain: pre 0.40, post 0.70 -> g = 0.30 / 0.60 = 0.50 (Medium)
      final recordMed = service.evaluateOutcome(
        participantId: 'learner_test_2',
        cohortId: 'cohort_a_literacy_dmv',
        topic: 'Florida Road Signs',
        preScore: 0.40,
        postScore: 0.70,
      );

      expect(recordMed.normalizedGain, closeTo(0.50, 0.01));
      expect(recordMed.gainCategory, equals(LearningGainCategory.medium));

      // Test Low Gain: pre 0.50, post 0.60 -> g = 0.10 / 0.50 = 0.20 (Low)
      final recordLow = service.evaluateOutcome(
        participantId: 'learner_test_3',
        cohortId: 'cohort_c_abe_health_food',
        topic: 'Food Safety',
        preScore: 0.50,
        postScore: 0.60,
      );

      expect(recordLow.normalizedGain, closeTo(0.20, 0.01));
      expect(recordLow.gainCategory, equals(LearningGainCategory.low));
    });

    test('saves outcome record and persists to storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = OutcomeAssessmentService(prefs: prefs);

      final record = service.evaluateOutcome(
        participantId: 'learner_p_99',
        cohortId: 'cohort_b_family_osha',
        topic: 'PPE Standards',
        preScore: 0.25,
        postScore: 0.85,
        clarityRating: 5,
        pacingFeedback: 'just_right',
        audioHelpfulnessRating: 5,
        confidenceRating: 5,
      );

      await service.saveOutcomeRecord(record);

      final participantOutcomes =
          await service.getParticipantOutcomes('learner_p_99');
      expect(participantOutcomes.length, equals(1));
      expect(participantOutcomes.first.topic, equals('PPE Standards'));
    });

    test('calculates aggregate pilot efficacy report with metrics', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = OutcomeAssessmentService(prefs: prefs);

      final report = await service.calculatePilotEfficacyReport();

      expect(report['sample_size'], greaterThanOrEqualTo(3));
      expect(report['average_pre_score'], greaterThan(0.0));
      expect(report['average_post_score'], greaterThan(0.70));
      expect(report['average_normalized_gain'], greaterThan(0.50));
      expect(report['gain_distribution']['high'], greaterThanOrEqualTo(1));
      expect(report['average_clarity_rating'], greaterThan(4.0));
      expect(report['average_audio_helpfulness'], greaterThan(4.0));
    });
  });
}

