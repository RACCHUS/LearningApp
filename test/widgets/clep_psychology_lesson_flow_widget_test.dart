import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/widgets/lesson/blocks/callout_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/table_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/rich_lesson_reader.dart';

void main() {
  group('CLEP Introductory Psychology: Learner-Facing Lesson Flow & Widget Tests', () {
    final now = DateTime.now();

    final clepLesson = Lesson(
      id: 'clep-psyc-les-1',
      title: 'Historical Foundations and Modern Perspectives in Psychology',
      description:
          'From Wundt\'s 1879 Leipzig laboratory and James\'s functionalism to the modern biopsychosocial model.',
      tags: ['history', 'perspectives', 'clep-psychology'],
      createdAt: now,
      updatedAt: now,
      userId: 'system-curriculum',
      visibility: 'public',
      terms: [
        Term(
          id: 't-1',
          term: 'Structuralism',
          definition:
              'Early school using systematic introspection to isolate the basic elements of conscious experience.',
          createdBy: 'system',
        ),
        Term(
          id: 't-2',
          term: 'Functionalism',
          definition:
              'School influenced by Darwin examining how mental operations enable organisms to adapt and survive.',
          createdBy: 'system',
        ),
      ],
      questions: [
        Question(
          id: 'q-formative-1',
          questionText:
              'Which early school of psychology utilized trained introspection to break conscious experience into its most basic sensory elements?',
          options: [
            'Structuralism',
            'Functionalism',
            'Behaviorism',
            'Psychoanalysis',
          ],
          correctAnswer: 0,
          type: 'mcq',
          createdBy: 'system',
          explanation:
              'Structuralism, founded by Wilhelm Wundt and Edward Titchener, attempted to map consciousness through systematic introspection.',
        ),
      ],
      concepts: [],
    );

    final concepts = [
      KnowledgeConcept(
        id: 'conc-struct',
        fieldId: 'field-psyc',
        slug: 'psyc-structuralism',
        name: 'Structuralism',
        shortDefinition: 'Wundt and Titchener introspection method',
        status: KnowledgeConceptStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeConcept(
        id: 'conc-funct',
        fieldId: 'field-psyc',
        slug: 'psyc-functionalism',
        name: 'Functionalism',
        shortDefinition: 'William James adaptive mental processes',
        status: KnowledgeConceptStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final blocks = [
      LessonBlock(
        id: 'b-md-intro',
        lessonId: 'clep-psyc-les-1',
        sortOrder: 1,
        blockType: LessonBlockType.markdown,
        content: {
          'text':
              '### The Emergence of Scientific Psychology\nPsychology transitioned from philosophical inquiry into an empirical science in 1879 when Wilhelm Wundt founded the first formal experimental psychology laboratory at the University of Leipzig in Germany.',
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-callout-case',
        lessonId: 'clep-psyc-les-1',
        sortOrder: 2,
        blockType: LessonBlockType.callout,
        content: {
          'callout_type': 'example',
          'title': 'Historical Vignette: The Leipzig Reaction Time Apparatus',
          'text':
              'In Wundt\'s early chronometry experiments, subjects were instructed to press a telegraph key the instant they heard a metal ball strike a platform, measuring the latency between sensation and apperception.',
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-table-comp',
        lessonId: 'clep-psyc-les-1',
        sortOrder: 3,
        blockType: LessonBlockType.table,
        content: {
          'title': 'Structuralism vs. Functionalism Paradigms',
          'headers': ['Dimension', 'Structuralism', 'Functionalism'],
          'rows': [
            ['Founding Theorists', 'Wilhelm Wundt, Edward Titchener', 'William James, John Dewey'],
            ['Primary Methodology', 'Systematic Trained Introspection', 'Direct Observation & Stream of Consciousness'],
            ['Core Question', 'What are the basic elements of mind?', 'Why does consciousness adapt and function?'],
          ],
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-callout-misconception',
        lessonId: 'clep-psyc-les-1',
        sortOrder: 4,
        blockType: LessonBlockType.callout,
        content: {
          'callout_type': 'warning',
          'title': 'Common CLEP Misconception: Structuralism vs Functionalism',
          'text':
              'Do not confuse Titchener\'s structuralism (which decomposes static mental structures) with James\'s functionalism (which studies adaptive evolutionary utility).',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Formative item that is safe for in-lesson formative check
    final formativeItem = AssessmentItem(
      id: 'itm-formative-1',
      lessonId: 'clep-psyc-les-1',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Formative Check: Which theorist established the functionalist school of psychology?',
      responseSpec: {
        'options': ['William James', 'Edward Titchener', 'John B. Watson', 'Max Wertheimer'],
      },
      scoringSpec: {'correct_index': 0},
      explanation: 'William James established functionalism, influenced by Darwin\'s evolutionary theory.',
      difficulty: 'intermediate',
      cognitiveLevel: 'recall',
      metadata: {
        'bank': 'formative_lesson',
        'item_role': 'concept_check',
        'is_protected': false,
      },
      createdAt: now,
      updatedAt: now,
    );

    final unifiedLesson = UnifiedLesson(
      lesson: clepLesson,
      blocks: blocks,
      assessmentItems: [formativeItem],
      concepts: concepts,
    );

    testWidgets('RichLessonReader renders CLEP lesson blocks, tables, and callouts', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: RichLessonReader(unifiedLesson: unifiedLesson),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Lesson Header & Core Exposition
      expect(find.text('Historical Foundations and Modern Perspectives in Psychology'), findsWidgets);
      expect(find.textContaining('Emergence of Scientific Psychology'), findsOneWidget);
      expect(find.textContaining('Wilhelm Wundt founded the first formal experimental psychology laboratory'), findsOneWidget);

      // Verify Case Scenario Callout
      expect(find.byType(CalloutBlockWidget), findsNWidgets(2));
      expect(find.textContaining('Historical Vignette: The Leipzig Reaction Time Apparatus'), findsOneWidget);

      // Verify Comparison Table
      expect(find.byType(TableBlockWidget), findsOneWidget);
      expect(find.text('Structuralism vs. Functionalism Paradigms'), findsOneWidget);
      expect(find.text('Founding Theorists'), findsOneWidget);
      expect(find.text('Wilhelm Wundt, Edward Titchener'), findsOneWidget);

      // Verify Common Misconception Callout
      expect(find.textContaining('Common CLEP Misconception'), findsOneWidget);
    });

    testWidgets('RichLessonReader renders formative assessment questions without leaking protected simulation items', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: RichLessonReader(unifiedLesson: unifiedLesson),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the Practice Evaluation section
      final beginBtn = find.textContaining('Begin Practice Evaluation');
      expect(beginBtn, findsOneWidget);
      await tester.tap(beginBtn);
      await tester.pumpAndSettle();

      // Verify Formative Check is present
      expect(find.textContaining('Formative Check: Which theorist established the functionalist school'), findsOneWidget);
      expect(find.text('William James'), findsOneWidget);
      expect(find.text('Edward Titchener'), findsOneWidget);

      // Verify that NO protected simulation items are in this view
      expect(find.textContaining('Protected Sim Item'), findsNothing);
      expect(find.textContaining('resting potential of an axon'), findsNothing);
      expect(find.textContaining('simulation_exam'), findsNothing);
      expect(find.textContaining('timed_exam_only'), findsNothing);
    });

    testWidgets('Learner can interact with formative question and view feedback', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: RichLessonReader(unifiedLesson: unifiedLesson),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the Practice Evaluation section
      final beginBtn = find.textContaining('Begin Practice Evaluation');
      expect(beginBtn, findsOneWidget);
      await tester.tap(beginBtn);
      await tester.pumpAndSettle();

      // Tap on the correct answer "William James"
      final jamesOption = find.text('William James');
      expect(jamesOption, findsOneWidget);

      await tester.tap(jamesOption);
      await tester.pumpAndSettle();

      // Verification: interaction does not crash and renders state update
      expect(find.text('William James'), findsOneWidget);
    });
  });
}
