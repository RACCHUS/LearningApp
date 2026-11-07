import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/family_abe_pilot.dart';
import 'package:learning_pwa/widgets/community/pilot_progress_card.dart';

void main() {
  testWidgets('PilotProgressCard renders cohort info, progress, and responds to actions',
      (tester) async {
    bool continued = false;
    bool takeAssessment = false;

    const cohort = PilotCohort(
      id: 'cohort_test_1',
      type: PilotCohortType.adultLiteracyDriverLicense,
      name: 'Adult Basic Literacy & Florida Driver\'s License',
      description: 'Phonics and road sign preparation.',
      primarySubject: 'Foundational Literacy',
      targetMilestone: 'FLHSMV Class E Driver Knowledge Exam',
      estimatedSessions: 4,
      recommendedSpeechRate: 0.80,
      targetSkills: ['MUTCD Signs', 'Phonemic Awareness'],
    );

    final sessions = [
      PilotParticipantSession(
        id: 's1',
        participantId: 'p1',
        cohortId: 'cohort_test_1',
        sessionIndex: 1,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
      PilotParticipantSession(
        id: 's2',
        participantId: 'p1',
        cohortId: 'cohort_test_1',
        sessionIndex: 2,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PilotProgressCard(
            cohort: cohort,
            sessions: sessions,
            onContinueSession: () => continued = true,
            onTakeAssessment: () => takeAssessment = true,
          ),
        ),
      ),
    );

    expect(find.text('Active Field Pilot'), findsOneWidget);
    expect(find.text('Adult Basic Literacy & Florida Driver\'s License'), findsOneWidget);
    expect(find.text('Target: FLHSMV Class E Driver Knowledge Exam'), findsOneWidget);
    expect(find.text('Session 2 of 4 Completed'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('80% Audio Pacing'), findsOneWidget);
    expect(find.text('MUTCD Signs'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue_pilot_session_button')));
    expect(continued, isTrue);

    await tester.tap(find.byKey(const Key('take_assessment_button')));
    expect(takeAssessment, isTrue);
  });
}

