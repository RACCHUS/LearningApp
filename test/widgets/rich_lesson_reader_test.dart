import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/content_provenance.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';
import 'package:learning_pwa/widgets/lesson/rich_lesson_reader.dart';
import 'package:learning_pwa/widgets/lesson/blocks/callout_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/code_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/table_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/formula_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/practice_prompt_block_widget.dart';

void main() {
  group('Phase D: RichLessonReader Widget Tests', () {
    final now = DateTime.now();
    final testLesson = Lesson(
      id: 'lesson-crypto-1',
      title: 'Public Key Cryptography & PKI',
      description:
          'Asymmetric cryptography architectures and certificate lifecycles.',
      tags: ['security', 'cryptography'],
      createdAt: now,
      updatedAt: now,
      userId: 'user-1',
      visibility: 'public',
      terms: [],
      questions: [],
      concepts: [],
    );

    final concept = KnowledgeConcept(
      id: 'conc-rsa',
      fieldId: 'field-cs',
      slug: 'rsa-cryptography',
      name: 'RSA Algorithm',
      shortDefinition:
          'Asymmetric public key algorithm based on prime factorization',
      status: KnowledgeConceptStatus.active,
      aliases: ['RSA'],
      createdAt: now,
      updatedAt: now,
    );

    final blocks = [
      LessonBlock(
        id: 'b-md-1',
        lessonId: 'lesson-crypto-1',
        sortOrder: 1,
        blockType: LessonBlockType.markdown,
        content: {
          'body':
              '### Introduction\nPublic-key cryptography uses mathematically linked keypairs.',
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-callout-1',
        lessonId: 'lesson-crypto-1',
        sortOrder: 2,
        blockType: LessonBlockType.callout,
        content: {
          'callout_type': 'exam_tip',
          'title': 'CompTIA Exam Tip',
          'body': 'Never transmit the private key across an insecure channel.',
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-code-1',
        lessonId: 'lesson-crypto-1',
        sortOrder: 3,
        blockType: LessonBlockType.code,
        content: {
          'language': 'bash',
          'code': 'openssl rsa -in private.key -pubout -out public.key',
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-table-1',
        lessonId: 'lesson-crypto-1',
        sortOrder: 4,
        blockType: LessonBlockType.table,
        content: {
          'title': 'Symmetric vs Asymmetric Comparison',
          'headers': ['Property', 'Symmetric', 'Asymmetric'],
          'rows': [
            ['Key Count', 'Single shared key', 'Public & private keypair'],
            ['Speed', 'Fast (Hardware-optimized)', 'Computationally slower'],
          ],
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-formula-1',
        lessonId: 'lesson-crypto-1',
        sortOrder: 5,
        blockType: LessonBlockType.formula,
        content: {
          'name': 'RSA Encryption Congruence',
          'latex': 'c \\equiv m^e \\pmod{n}',
          'explanation':
              'Ciphertext c is calculated by raising plaintext m to public exponent e modulo n.',
        },
        createdAt: now,
        updatedAt: now,
      ),
      LessonBlock(
        id: 'b-prompt-1',
        lessonId: 'lesson-crypto-1',
        sortOrder: 6,
        blockType: LessonBlockType.practicePrompt,
        content: {
          'prompt':
              'Which key is used to decrypt a message encrypted with Alice\'s public key?',
          'options': [
            'Bob\'s private key',
            'Alice\'s private key',
            'The CA master key',
          ],
          'answer': 'Alice\'s private key',
          'explanation':
              'Only Alice\'s private key can invert operations performed with her public key.',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final release = ContentSourceRelease(
      id: 'rel-comptia',
      publisher: 'CompTIA',
      title: 'CompTIA Security+ SY0-701 Blueprint',
      version: 'SY0-701',
      retrievedAt: now,
      sha256: 'a1b2c3d4e5f6',
    );

    final mapping = ContentSourceMapping(
      id: 'map-comptia',
      sourceReleaseId: 'rel-comptia',
      entityType: 'lesson',
      entityId: 'lesson-crypto-1',
      relationship: 'official_blueprint',
      citationLocation: 'Objective 1.2: Summarize Cryptographic Concepts',
      createdAt: now,
      release: release,
    );

    final unifiedLesson = UnifiedLesson(
      lesson: testLesson,
      blocks: blocks,
      concepts: [concept],
      provenance: [mapping],
    );

    testWidgets(
      'RichLessonReader renders header, concept badges, and all block types',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(home: RichLessonReader(unifiedLesson: unifiedLesson)),
        );
        await tester.pumpAndSettle();

        // Verify title & concept badge
        expect(find.text('Public Key Cryptography & PKI'), findsWidgets);
        expect(find.text('RSA Algorithm'), findsOneWidget);

        // Verify Blueprint chip in action bar
        expect(find.text('Blueprint'), findsOneWidget);

        // Verify Callout block
        expect(find.byType(CalloutBlockWidget), findsOneWidget);
        expect(find.text('CompTIA Exam Tip'), findsOneWidget);

        // Verify Code block
        expect(find.byType(CodeBlockWidget), findsOneWidget);
        expect(find.text('BASH'), findsOneWidget);

        // Verify Table block
        expect(find.byType(TableBlockWidget), findsOneWidget);
        expect(find.text('Symmetric vs Asymmetric Comparison'), findsOneWidget);

        // Verify Formula block
        expect(find.byType(FormulaBlockWidget), findsOneWidget);
        expect(find.text('RSA Encryption Congruence'), findsOneWidget);

        // Verify Practice Prompt block
        expect(find.byType(PracticePromptBlockWidget), findsOneWidget);
        expect(
          find.text(
            'Which key is used to decrypt a message encrypted with Alice\'s public key?',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('PracticePromptBlockWidget reveals explanation upon button tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PracticePromptBlockWidget(block: blocks[5])),
        ),
      );
      await tester.pumpAndSettle();

      // Before tap: Explanation should not be visible
      expect(
        find.text(
          'Only Alice\'s private key can invert operations performed with her public key.',
        ),
        findsNothing,
      );
      expect(find.text('Check Recall & Answer'), findsOneWidget);

      // Tap reveal button
      await tester.tap(find.text('Check Recall & Answer'));
      await tester.pumpAndSettle();

      // After tap: Explanation and answer revealed
      expect(
        find.text(
          'Only Alice\'s private key can invert operations performed with her public key.',
        ),
        findsOneWidget,
      );
      expect(find.text('Hide Explanation'), findsOneWidget);
    });

    testWidgets(
      'RichLessonReader generates a fresh per-attempt nonce and option permutation when retrying or re-presenting an assessment item',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 3500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assessmentItem = AssessmentItem(
          id: 'lesson-item-rsa-1',
          interactionType: AssessmentInteractionType.singleChoice,
          prompt:
              'Which algorithm relies on elliptic curve discrete logarithms?',
          responseSpec: {
            'options': ['RSA', 'ECDSA', 'AES-GCM', 'ChaCha20'],
          },
          scoringSpec: {'correct_index': 1},
          explanation:
              'ECDSA is based on the elliptic curve discrete logarithm problem.',
          createdAt: now,
          updatedAt: now,
        );

        final lessonWithItems = UnifiedLesson(
          lesson: testLesson,
          blocks: [blocks.first],
          assessmentItems: [assessmentItem],
          concepts: [concept],
          provenance: [mapping],
        );

        await tester.pumpWidget(
          MaterialApp(home: RichLessonReader(unifiedLesson: lessonWithItems)),
        );
        await tester.pumpAndSettle();

        // Open practice evaluation section
        await tester.tap(find.textContaining('Begin Practice Evaluation'));
        await tester.pumpAndSettle();

        final readerState =
            tester.state(find.byType(RichLessonReader)) as dynamic;
        final itemState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;

        final nonce1 =
            readerState.attemptNonceForItem(assessmentItem.id) as int;
        final order1 = List<int>.from(itemState.presentationOrder as List<int>);
        expect(order1.toSet(), equals({0, 1, 2, 3}));

        // Select an option and submit to reveal 'Try Again'
        await tester.tap(find.text('ECDSA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();

        // Retry the item via the 'Try Again' button
        await tester.tap(find.text('Try Again'));
        await tester.pumpAndSettle();

        final nonce2 =
            readerState.attemptNonceForItem(assessmentItem.id) as int;
        final order2 = List<int>.from(itemState.presentationOrder as List<int>);
        expect(nonce2, isNot(equals(nonce1)));
        expect(order2.toSet(), equals({0, 1, 2, 3}));
        expect(order2, isNot(equals(order1)));

        // Re-present all evaluation items via 'Retry All' and verify another fresh permutation
        await tester.tap(find.text('Retry All'));
        await tester.pumpAndSettle();

        final nonce3 =
            readerState.attemptNonceForItem(assessmentItem.id) as int;
        final order3 = List<int>.from(itemState.presentationOrder as List<int>);
        expect(nonce3, isNot(equals(nonce2)));
        expect(order3, isNot(equals(order2)));
      },
    );
  });
}
