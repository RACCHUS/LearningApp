import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_pwa/models/assessment_engine/exam_reference_manifest.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/providers/exam_part_progress_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/assessment/exam_part_next_action_engine.dart';
import 'package:learning_pwa/widgets/progress/exam_part_progress_card.dart';

const _profile = ExamPreparationProfile(
  targetVersionId: 'version-1',
  schemaVersion: 1,
  examParts: [
    ExamPartSpec(key: 'part_a', displayName: 'Part A',
      curriculumRootNodeId: 'root-a'),
    ExamPartSpec(key: 'part_b', displayName: 'Part B',
      curriculumRootNodeId: 'root-b'),
  ],
);

ExamPartProgressSnapshot _snapshot(String part, String owner, int total) {
  final key = (
    targetId: 'target-1',
    targetVersionId: 'version-1',
    examPartKey: part,
    learnerId: owner,
  );
  final knowledge = TargetReadiness(
    targetVersionId: 'version-1',
    band: total == 4
        ? TargetReadinessBand.developing
        : TargetReadinessBand.notYetAssessed,
    score: 0.4,
    totalCoreConcepts: total,
    assessedConceptsCount: total == 4 ? 2 : 0,
    bandDistribution: {for (final b in RetrievalBand.values) b: 0},
  );
  final availability = DiagnosticAvailability(
    targetVersionId: 'version-1',
    isPublishedVersion: true,
    availableItemCount: 6,
    representedConceptCount: 3,
    minimumItemCount: 6,
    minimumConceptCount: 3,
  );
  return ExamPartProgressSnapshot(
    key: key,
    rootNodeId: part == 'part_a' ? 'root-a' : 'root-b',
    knowledge: knowledge,
    diagnostic: availability,
    nextStep: const ExamPartNextActionEngine().recommend(
      readiness: knowledge,
      diagnostic: availability,
    ),
  );
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: child),
  ),
);

void main() {
  testWidgets('A and B show independent counts and scoped next steps',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learnerIdProvider.overrideWith((ref) => 'learner-a'),
        examPartProfileProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
        )).overrideWith((ref) async => _profile),
        examPartProgressProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
          examPartKey: 'part_a',
          learnerId: 'learner-a',
        )).overrideWith((ref) async => _snapshot('part_a', 'learner-a', 4)),
        examPartProgressProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
          examPartKey: 'part_b',
          learnerId: 'learner-a',
        )).overrideWith((ref) async => _snapshot('part_b', 'learner-a', 2)),
      ],
      child: _app(const ExamPartProgressCard(
        targetId: 'target-1',
        targetVersionId: 'version-1',
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-part-knowledge-count')), findsNothing);

    await tester.tap(find.byKey(const Key('exam-part-progress-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part A').last);
    await tester.pumpAndSettle();
    expect(find.text('2 of 4 part core concepts assessed'), findsOneWidget);
    expect(find.text('Continue building this part’s knowledge'), findsOneWidget);
    expect(find.byKey(const Key('exam-part-history-limit')), findsOneWidget);
    expect(find.byKey(const Key('exam-part-start-diagnostic')), findsNothing);

    await tester.tap(find.byKey(const Key('exam-part-progress-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part B').last);
    await tester.pumpAndSettle();
    expect(find.text('0 of 2 part core concepts assessed'), findsOneWidget);
    expect(find.text('2 of 4 part core concepts assessed'), findsNothing);
    expect(find.byKey(const Key('exam-part-start-diagnostic')), findsOneWidget);
    expect(find.textContaining('Saved R1–R4 reference drills'), findsOneWidget);
  });

  testWidgets('account switch resets selected part and hides old knowledge',
      (tester) async {
    final owner = StateProvider<String>((ref) => 'learner-a');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learnerIdProvider.overrideWith((ref) => ref.watch(owner)),
        examPartProfileProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
        )).overrideWith((ref) async => _profile),
        examPartProgressProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
          examPartKey: 'part_a',
          learnerId: 'learner-a',
        )).overrideWith((ref) async => _snapshot('part_a', 'learner-a', 4)),
      ],
      child: _app(Consumer(builder: (context, ref, _) {
        final learner = ref.watch(learnerIdProvider);
        return ExamPartProgressCard(
          key: ValueKey('part-progress:$learner'),
          targetId: 'target-1',
          targetVersionId: 'version-1',
        );
      })),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-part-progress-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part A').last);
    await tester.pumpAndSettle();
    expect(find.text('2 of 4 part core concepts assessed'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExamPartProgressCard)),
    );
    container.read(owner.notifier).state = 'learner-b';
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-part-knowledge-count')), findsNothing);
    expect(find.byKey(const Key('exam-part-start-diagnostic')), findsNothing);
    expect(find.text('2 of 4 part core concepts assessed'), findsNothing);
    expect(find.text('Select a part'), findsOneWidget);
  });

  testWidgets('unconfigured version shows no invented exam parts', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learnerIdProvider.overrideWith((ref) => 'learner-a'),
        examPartProfileProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
        )).overrideWith((ref) async => null),
      ],
      child: _app(const ExamPartProgressCard(
        targetId: 'target-1',
        targetVersionId: 'version-1',
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-part-progress-card')), findsNothing);
  });

  testWidgets('failed scoped read never falls back to global readiness',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learnerIdProvider.overrideWith((ref) => 'learner-a'),
        examPartProfileProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
        )).overrideWith((ref) async => _profile),
        examPartProgressProvider((
          targetId: 'target-1',
          targetVersionId: 'version-1',
          examPartKey: 'part_a',
          learnerId: 'learner-a',
        )).overrideWith((ref) async => throw StateError('invalid root')),
      ],
      child: _app(const ExamPartProgressCard(
        targetId: 'target-1',
        targetVersionId: 'version-1',
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-part-progress-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part A').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-part-progress-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('exam-part-knowledge-count')), findsNothing);
  });
}
