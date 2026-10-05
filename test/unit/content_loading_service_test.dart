import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/assessment_stimulus.dart';
import 'package:learning_pwa/models/content_provenance.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/concept_content.dart';

void main() {
  group('Phase D: UnifiedLesson and Content Model Tests', () {
    final now = DateTime.now();
    final testLesson = Lesson(
      id: 'lesson-1',
      title: 'CompTIA Security+ Cryptography',
      description: 'Understanding symmetric and asymmetric encryption fundamentals.',
      tags: ['security', 'crypto'],
      createdAt: now,
      updatedAt: now,
      userId: 'user-1',
      visibility: 'public',
      terms: [],
      questions: [],
      concepts: [],
    );

    test('UnifiedLesson correctly holds rich blocks and provenance', () {
      final block = LessonBlock(
        id: 'block-1',
        lessonId: 'lesson-1',
        sortOrder: 1,
        blockType: LessonBlockType.code,
        content: {'code': 'openssl genpkey -algorithm RSA', 'language': 'bash'},
        createdAt: now,
        updatedAt: now,
      );

      final release = ContentSourceRelease(
        id: 'rel-1',
        publisher: 'CompTIA',
        title: 'CompTIA Security+ SY0-701',
        version: 'SY0-701',
        retrievedAt: now,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final mapping = ContentSourceMapping(
        id: 'map-1',
        sourceReleaseId: 'rel-1',
        entityType: 'lesson',
        entityId: 'lesson-1',
        relationship: 'official_blueprint',
        citationLocation: 'Objective 1.2',
        createdAt: now,
        release: release,
      );

      final unified = UnifiedLesson(
        lesson: testLesson,
        blocks: [block],
        provenance: [mapping],
      );

      expect(unified.hasRichBlocks, isTrue);
      expect(unified.hasProvenance, isTrue);
      expect(unified.effectiveBlocks.length, equals(1));
      expect(unified.effectiveBlocks.first.blockType, equals(LessonBlockType.code));
      expect(unified.provenance.first.release?.publisher, equals('CompTIA'));
      expect(unified.provenance.first.citationLocation, equals('Objective 1.2'));
    });

    test('UnifiedLesson synthesizes blocks from legacy content when no rich blocks exist', () {
      final term = TermContent(
        id: 'term-1',
        lessonId: 'lesson-1',
        order: 1,
        term: 'Public Key Infrastructure',
        definition: 'A framework of roles, policies, and hardware.',
        example: 'X.509 digital certificates.',
        createdAt: now,
        updatedAt: now,
      );

      final concept = ConceptContent(
        id: 'conc-1',
        lessonId: 'lesson-1',
        order: 2,
        conceptText: 'Confidentiality vs Integrity',
        exampleText: 'AES provides confidentiality; SHA provides integrity.',
        createdAt: now,
        updatedAt: now,
      );

      final question = QuestionContent(
        id: 'q-1',
        lessonId: 'lesson-1',
        order: 3,
        questionText: 'Which algorithm is asymmetric?',
        options: ['AES', 'RSA', 'DES'],
        correctAnswer: 1,
        explanation: 'RSA is asymmetric using public/private key pairs.',
        createdAt: now,
        updatedAt: now,
      );

      final legacyLesson = UnifiedLesson(
        lesson: testLesson,
        blocks: [], // Empty blocks
        legacyContent: [term, concept, question],
      );

      expect(legacyLesson.hasRichBlocks, isFalse);
      final synthBlocks = legacyLesson.effectiveBlocks;

      // Expect description block + term callout + concept example + question prompt = 4
      expect(synthBlocks.length, equals(4));
      expect(synthBlocks[0].blockType, equals(LessonBlockType.markdown));
      expect(synthBlocks[1].blockType, equals(LessonBlockType.callout));
      expect(synthBlocks[1].content['title'], equals('Public Key Infrastructure'));
      expect(synthBlocks[2].blockType, equals(LessonBlockType.example));
      expect(synthBlocks[3].blockType, equals(LessonBlockType.practicePrompt));
      expect(synthBlocks[3].content['prompt'], equals('Which algorithm is asymmetric?'));
    });

    test('AssessmentItem parses polymorphic specs and linked stimulus correctly', () {
      final stimulus = AssessmentStimulus(
        id: 'stim-1',
        stimulusType: AssessmentStimulusType.clinicalCase,
        title: 'Emergency Triage Scenario',
        body: 'Patient presents with acute chest pain.',
        structuredData: {'blood_pressure': '160/95', 'heart_rate': 110},
        createdAt: now,
        updatedAt: now,
      );

      final item = AssessmentItem(
        id: 'item-sata-1',
        interactionType: AssessmentInteractionType.multiSelect,
        prompt: 'Which immediate nursing interventions are indicated? (Select all that apply)',
        responseSpec: {
          'options': [
            'Administer high-flow oxygen',
            'Obtain 12-lead ECG',
            'Administer sublingual nitroglycerin',
            'Instruct patient to ambulate',
          ],
        },
        scoringSpec: {
          'correct_indices': [0, 1, 2],
          'scoring_method': 'partial_credit',
        },
        stimulus: stimulus,
        explanation: 'Oxygen, ECG, and nitroglycerin are priority interventions.',
        difficulty: 'advanced',
        cognitiveLevel: 'analysis',
        createdAt: now,
        updatedAt: now,
      );

      expect(item.interactionType, equals(AssessmentInteractionType.multiSelect));
      expect(item.stimulus, isNotNull);
      expect(item.stimulus!.stimulusType, equals(AssessmentStimulusType.clinicalCase));
      expect(item.stimulus!.structuredData['blood_pressure'], equals('160/95'));
      expect((item.scoringSpec['correct_indices'] as List).length, equals(3));
    });
  });
}
