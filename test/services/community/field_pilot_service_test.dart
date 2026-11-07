import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/community/field_pilot_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FieldPilotService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('retrieves standard curated pilot cohorts', () {
      final service = FieldPilotService();
      final cohorts = service.getAvailableCohorts();

      expect(cohorts.length, equals(3));
      expect(cohorts.any((c) => c.id == 'cohort_a_literacy_dmv'), isTrue);
      expect(cohorts.any((c) => c.id == 'cohort_b_family_osha'), isTrue);
      expect(cohorts.any((c) => c.id == 'cohort_c_abe_health_food'), isTrue);

      final cohortA = service.getCohortById('cohort_a_literacy_dmv');
      expect(cohortA, isNotNull);
      expect(cohortA!.targetMilestone, contains('FLHSMV Class E'));
    });

    test('enrolls participant into cohort and retrieves cohort ID', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = FieldPilotService(prefs: prefs);

      await service.enrollParticipant(
        participantId: 'learner_123',
        cohortId: 'cohort_b_family_osha',
      );

      final enrolled = await service.getParticipantCohortId('learner_123');
      expect(enrolled, equals('cohort_b_family_osha'));
    });

    test('tracks participant session lifecycle and milestones', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = FieldPilotService(prefs: prefs);

      // Start session
      final session = await service.startSession(
        participantId: 'learner_123',
        cohortId: 'cohort_b_family_osha',
        audioGuidance: true,
        speechRate: 0.85,
        tactileTracingCompleted: true,
      );

      expect(session.sessionIndex, equals(1));
      expect(session.audioGuidanceEnabled, isTrue);
      expect(session.tactileTracingCompleted, isTrue);
      expect(session.completedAt, isNull);

      // Record milestone
      final withMilestone = await service.recordMilestoneCompleted(
        participantId: 'learner_123',
        sessionId: session.id,
        milestone: 'GHS Pictogram Match Complete',
      );

      expect(withMilestone.milestonesCompleted, contains('GHS Pictogram Match Complete'));

      // Complete session
      final completed = await service.completeSession(
        participantId: 'learner_123',
        sessionId: session.id,
        durationSeconds: 420,
        notes: 'Great audio pacing and engagement',
      );

      expect(completed.completedAt, isNotNull);
      expect(completed.durationSeconds, equals(420));
      expect(completed.notes, equals('Great audio pacing and engagement'));

      final allSessions = await service.getParticipantSessions('learner_123');
      expect(allSessions.length, equals(1));
      expect(allSessions.first.completedAt, isNotNull);
    });

    test('computes cohort aggregate summary', () async {
      final service = FieldPilotService();
      final summary = await service.getCohortAggregateSummary('cohort_a_literacy_dmv');

      expect(summary['cohort_id'], equals('cohort_a_literacy_dmv'));
      expect(summary['target_milestone'], contains('FLHSMV'));
      expect(summary['target_skills_count'], equals(4));
    });
  });
}

