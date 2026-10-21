import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/services/assessment/exam_part_next_action_engine.dart';

TargetReadiness _readiness({
  TargetReadinessBand band = TargetReadinessBand.notYetAssessed,
  int total = 4,
  int assessed = 0,
  int weak = 0,
  String version = 'version-a',
}) {
  return TargetReadiness(
    targetVersionId: version,
    band: band,
    score: 0.0,
    totalCoreConcepts: total,
    assessedConceptsCount: assessed,
    bandDistribution: {
      for (final b in RetrievalBand.values)
        b: b == RetrievalBand.needsReinforcement ? weak : 0,
    },
  );
}

DiagnosticAvailability _availability({
  String version = 'version-a',
  int items = 6,
  int concepts = 3,
  bool published = true,
}) {
  return DiagnosticAvailability(
    targetVersionId: version,
    isPublishedVersion: published,
    availableItemCount: items,
    representedConceptCount: concepts,
    minimumItemCount: 6,
    minimumConceptCount: 3,
  );
}

void main() {
  const engine = ExamPartNextActionEngine();

  group('EXM-03 part next-step precedence', () {
    test('unmapped part does not suggest a test or infer readiness', () {
      final step = engine.recommend(
        readiness: _readiness(total: 0),
        diagnostic: _availability(),
      );
      expect(step.kind, ExamPartNextStepKind.mapCurriculum);
      expect(step.canLaunchDiagnostic, isFalse);
    });

    test('unassessed part uses reviewed diagnostic when available', () {
      final step = engine.recommend(
        readiness: _readiness(),
        diagnostic: _availability(),
      );
      expect(step.kind, ExamPartNextStepKind.practiceDiagnostic);
      expect(step.canLaunchDiagnostic, isTrue);
      expect(step.rationale, contains('initial snapshot'));
    });

    test('unassessed part does not invent diagnostic coverage', () {
      final step = engine.recommend(
        readiness: _readiness(),
        diagnostic: _availability(items: 5),
      );
      expect(step.kind, ExamPartNextStepKind.studyCurriculum);
      expect(step.canLaunchDiagnostic, isFalse);
    });

    test('weak knowledge outranks otherwise available practice', () {
      final step = engine.recommend(
        readiness: _readiness(
          band: TargetReadinessBand.needsReinforcement,
          assessed: 2, weak: 1,
        ),
        diagnostic: _availability(),
      );
      expect(step.kind, ExamPartNextStepKind.reinforceKnowledge);
    });

    test('a weak concept outranks misleading strong aggregate band', () {
      final step = engine.recommend(
        readiness: _readiness(
          band: TargetReadinessBand.strongCoverage,
          assessed: 4, weak: 1,
        ),
        diagnostic: _availability(),
      );
      expect(step.kind, ExamPartNextStepKind.reinforceKnowledge);
    });

    test('strong knowledge can suggest practice, never official passing', () {
      final step = engine.recommend(
        readiness: _readiness(
          band: TargetReadinessBand.strongCoverage, assessed: 4,
        ),
        diagnostic: _availability(),
      );
      expect(step.kind, ExamPartNextStepKind.practiceDiagnostic);
      expect(step.rationale, contains('not an official exam score'));
    });

    test('strong knowledge without reviewed questions remains curriculum', () {
      final step = engine.recommend(
        readiness: _readiness(
          band: TargetReadinessBand.strongCoverage, assessed: 4,
        ),
        diagnostic: _availability(published: false),
      );
      expect(step.kind, ExamPartNextStepKind.studyCurriculum);
    });

    test('developing evidence suggests study rather than exam-level claims', () {
      final step = engine.recommend(
        readiness: _readiness(
          band: TargetReadinessBand.developing, assessed: 3,
        ),
        diagnostic: _availability(),
      );
      expect(step.kind, ExamPartNextStepKind.studyCurriculum);
    });

    test('mismatched version fails rather than borrowing another part', () {
      expect(
        () => engine.recommend(
          readiness: _readiness(),
          diagnostic: _availability(version: 'version-b'),
        ),
        throwsStateError,
      );
    });
  });
}
