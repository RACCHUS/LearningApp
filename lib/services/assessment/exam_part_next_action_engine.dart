import '../../models/user_concept_state.dart';
import '../../models/assessment/diagnostic_assessment.dart';

/// Recommendations specific to an explicitly selected exam part.
///
/// Never substitutes target-wide readiness, structural completion, or a
/// prior diagnostic score for a verified official examination outcome.
enum ExamPartNextStepKind {
  mapCurriculum,
  studyCurriculum,
  reinforceKnowledge,
  practiceDiagnostic,
}

class ExamPartNextStep {
  final ExamPartNextStepKind kind;
  final String title;
  final String rationale;

  const ExamPartNextStep({
    required this.kind,
    required this.title,
    required this.rationale,
  });

  bool get canLaunchDiagnostic =>
      kind == ExamPartNextStepKind.practiceDiagnostic;
}

/// Pure, deterministic part-aware guidance. Separate from the global
/// NextActionEngine's primary-action precedence and activity completion.
class ExamPartNextActionEngine {
  const ExamPartNextActionEngine();

  ExamPartNextStep recommend({
    required TargetReadiness readiness,
    required DiagnosticAvailability diagnostic,
  }) {
    if (diagnostic.targetVersionId != readiness.targetVersionId) {
      throw StateError('Part diagnostic and readiness target versions disagree.');
    }
    if (readiness.totalCoreConcepts == 0) {
      return const ExamPartNextStep(
        kind: ExamPartNextStepKind.mapCurriculum,
        title: 'Review this part’s curriculum map',
        rationale: 'No core concept coverage is mapped for this part. '
            'There is not enough information to claim knowledge readiness.',
      );
    }
    if (readiness.assessedConceptsCount == 0) {
      if (diagnostic.isAvailable) {
        return const ExamPartNextStep(
          kind: ExamPartNextStepKind.practiceDiagnostic,
          title: 'Try a part-specific practice diagnostic',
          rationale: 'You have no assessed knowledge evidence for this part. '
              'A reviewed practice diagnostic can provide an initial snapshot.',
        );
      }
      return const ExamPartNextStep(
        kind: ExamPartNextStepKind.studyCurriculum,
        title: 'Study this part’s curriculum',
        rationale: 'Knowledge has not been assessed for this part, '
            'and a reviewed part-specific diagnostic is unavailable.',
      );
    }

    final weakCount =
        (readiness.bandDistribution[RetrievalBand.needsReinforcement] ?? 0);
    if (weakCount > 0 ||
        readiness.band == TargetReadinessBand.needsReinforcement) {
      return const ExamPartNextStep(
        kind: ExamPartNextStepKind.reinforceKnowledge,
        title: 'Reinforce this part’s weaker concepts',
        rationale: 'Knowledge evidence indicates concepts that need '
            'reinforcement in this selected part.',
      );
    }
    if (readiness.band == TargetReadinessBand.strongCoverage &&
        diagnostic.isAvailable) {
      return const ExamPartNextStep(
        kind: ExamPartNextStepKind.practiceDiagnostic,
        title: 'Try a part-specific practice diagnostic',
        rationale: 'Current concept evidence suggests strong knowledge '
            'coverage. A practice diagnostic is not an official exam score.',
      );
    }
    return const ExamPartNextStep(
      kind: ExamPartNextStepKind.studyCurriculum,
      title: 'Continue building this part’s knowledge',
      rationale: 'Keep working on this part’s curriculum. Knowledge '
          'coverage is not the same as official exam performance.',
    );
  }
}
