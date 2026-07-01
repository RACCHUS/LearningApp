import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/generation_session.dart';
import 'package:learning_pwa/providers/generation_session_provider.dart';
import 'package:learning_pwa/services/ai_prompt_service.dart';
import 'package:learning_pwa/services/content_quality_service.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

final _samplePlan = <String, dynamic>{
  'lesson_plan': {
    'title': 'Intro to Variables',
    'description': 'Learn the basics of variables in programming.',
    'difficulty': 'beginner',
    'estimated_duration_minutes': 15,
    'learning_objectives': ['Define a variable', 'Assign values'],
    'prerequisite_knowledge': [],
    'key_terminology': ['variable', 'assignment'],
  },
  'content_manifest': {
    'terms': [
      {'title': 'Variable', 'purpose': 'Core building block', 'order': 1},
      {'title': 'Assignment', 'purpose': 'How to set values', 'order': 2},
    ],
    'concepts': [
      {
        'title': 'Declaring Variables',
        'purpose': 'How to create variables',
        'depends_on_terms': ['Variable'],
        'order': 1,
      },
    ],
    'mcqs': [
      {
        'tests_concept': 'Declaring Variables',
        'cognitive_level': 'recall',
        'order': 1,
      },
    ],
  },
  'terminology_glossary': {
    'Variable': 'A named storage location in memory.',
    'Assignment': 'The act of storing a value in a variable.',
  },
};

// ---------------------------------------------------------------------------
// GenerationSession model tests
// ---------------------------------------------------------------------------

void main() {
  group('GenerationSession', () {
    late GenerationSession session;

    setUp(() {
      session = GenerationSession(
        id: 'sess-1',
        createdAt: DateTime.utc(2025, 1, 1),
        subject: 'Programming',
        targetAudience: 'Beginners',
        durationMinutes: 15,
        difficulty: 'beginner',
        contentFocus: 'terms_and_concepts',
      );
    });

    test('toJson / fromJson roundtrip preserves all fields', () {
      final withPlan = session.copyWith(
        lessonPlan: _samplePlan,
        terms: [
          {'type': 'term', 'title': 'Variable', 'content': 'A storage location'}
        ],
        concepts: [
          {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'}
        ],
        mcqs: [
          {'type': 'mcq', 'question': 'What is a variable?', 'options': ['a', 'b', 'c', 'd'], 'correct_answer': 'a'}
        ],
        currentPhase: GenerationPhase.reviewing,
      );

      final json = withPlan.toJson();
      final restored = GenerationSession.fromJson(json);

      expect(restored.id, withPlan.id);
      expect(restored.subject, withPlan.subject);
      expect(restored.targetAudience, withPlan.targetAudience);
      expect(restored.durationMinutes, withPlan.durationMinutes);
      expect(restored.difficulty, withPlan.difficulty);
      expect(restored.contentFocus, withPlan.contentFocus);
      expect(restored.terms.length, 1);
      expect(restored.concepts.length, 1);
      expect(restored.mcqs.length, 1);
      expect(restored.currentPhase, GenerationPhase.reviewing);
      expect(restored.lessonPlan, isNotNull);
    });

    test('toJsonString / fromJsonString roundtrip', () {
      final jsonStr = session.toJsonString();
      final restored = GenerationSession.fromJsonString(jsonStr);
      expect(restored.id, session.id);
      expect(restored.subject, session.subject);
    });

    test('manifest counts reflect lessonPlan contents', () {
      final s = session.copyWith(lessonPlan: _samplePlan);
      expect(s.expectedTermCount, 2);
      expect(s.expectedConceptCount, 1);
      expect(s.expectedMcqCount, 1);
    });

    test('allTermsGenerated is false when terms are missing', () {
      final s = session.copyWith(
        lessonPlan: _samplePlan,
        terms: [{'type': 'term', 'title': 'Variable'}],
      );
      expect(s.allTermsGenerated, isFalse);
    });

    test('allTermsGenerated is true when terms are complete', () {
      final s = session.copyWith(
        lessonPlan: _samplePlan,
        terms: [
          {'type': 'term', 'title': 'Variable'},
          {'type': 'term', 'title': 'Assignment'},
        ],
      );
      expect(s.allTermsGenerated, isTrue);
    });

    test('assemble produces flat structure with terms, concepts, questions', () {
      final s = session.copyWith(
        lessonPlan: _samplePlan,
        terms: [
          {'type': 'term', 'title': 'Variable', 'content': 'A named storage location'}
        ],
        concepts: [
          {'type': 'concept', 'title': 'Declaring Variables', 'content': 'How to create'}
        ],
        mcqs: [
          {'type': 'mcq', 'question': 'Q1', 'options': ['a','b','c','d'], 'correct_answer': 'a'}
        ],
      );

      final assembled = s.assemble();
      expect(assembled.containsKey('title'), isTrue);
      expect(assembled.containsKey('terms'), isTrue);
      expect(assembled.containsKey('concepts'), isTrue);
      expect(assembled.containsKey('questions'), isTrue);
      expect(assembled['title'], 'Intro to Variables');
      expect((assembled['terms'] as List).length, 1);
      expect((assembled['concepts'] as List).length, 1);
      expect((assembled['questions'] as List).length, 1);
      // Verify field mapping
      expect((assembled['terms'] as List).first['term'], 'Variable');
      expect((assembled['terms'] as List).first['definition'], 'A named storage location');
      expect((assembled['concepts'] as List).first['concept_text'], 'Declaring Variables');
      expect((assembled['questions'] as List).first['correct_answer'], 0);
    });

    test('assemble applies review revisions', () {
      final s = session.copyWith(
        lessonPlan: _samplePlan,
        terms: [
          {'type': 'term', 'title': 'Variable', 'content': 'Old definition'}
        ],
        reviewResult: {
          'review_summary': {'items_revised': 1},
          'revised_content': [
            {'title': 'Variable', 'type': 'term', 'content': 'Revised definition', '_revision_note': 'Improved'}
          ],
        },
      );

      final assembled = s.assemble();
      final terms = assembled['terms'] as List;
      final term = terms.firstWhere((t) => t['term'] == 'Variable');
      expect(term['definition'], 'Revised definition');
    });
  });

  // ---------------------------------------------------------------------------
  // GenerationSessionNotifier tests
  // ---------------------------------------------------------------------------

  group('GenerationSessionNotifier', () {
    late GenerationSessionNotifier notifier;

    setUp(() {
      notifier = GenerationSessionNotifier();
    });

    test('starts with null state', () {
      expect(notifier.state, isNull);
    });

    test('startSession creates a session in planning phase', () {
      notifier.startSession(
        subject: 'Math',
        targetAudience: 'Students',
        durationMinutes: 20,
        difficulty: 'intermediate',
        contentFocus: 'mixed',
      );

      final s = notifier.state!;
      expect(s.subject, 'Math');
      expect(s.currentPhase, GenerationPhase.planning);
    });

    test('handleResponse advances from planning to generatingTerms', () {
      notifier.startSession(
        subject: 'Math',
        targetAudience: 'Students',
        durationMinutes: 20,
        difficulty: 'intermediate',
        contentFocus: 'mixed',
      );

      final error = notifier.handleResponse(jsonEncode(_samplePlan));
      expect(error, isNull);
      expect(notifier.state!.currentPhase, GenerationPhase.generatingTerms);
      expect(notifier.state!.lessonPlan, isNotNull);
    });

    test('handleResponse rejects invalid planning JSON', () {
      notifier.startSession(
        subject: 'Math',
        targetAudience: 'Students',
        durationMinutes: 20,
        difficulty: 'intermediate',
        contentFocus: 'mixed',
      );

      final error = notifier.handleResponse(jsonEncode({'wrong': 'shape'}));
      expect(error, isNotNull);
      expect(notifier.state!.currentPhase, GenerationPhase.planning);
    });

    test('handleResponse accumulates terms and advances when complete', () {
      _advanceToPlanCompleted(notifier);

      // Add first batch
      final err1 = notifier.handleResponse(jsonEncode([
        {'type': 'term', 'title': 'Variable', 'content': 'Def 1'}
      ]));
      expect(err1, isNull);
      expect(notifier.state!.terms.length, 1);
      // Still generating terms — need 2 total
      expect(notifier.state!.currentPhase, GenerationPhase.generatingTerms);

      // Add second batch
      final err2 = notifier.handleResponse(jsonEncode([
        {'type': 'term', 'title': 'Assignment', 'content': 'Def 2'}
      ]));
      expect(err2, isNull);
      expect(notifier.state!.terms.length, 2);
      // All terms generated → advance to concepts
      expect(notifier.state!.currentPhase, GenerationPhase.generatingConcepts);
    });

    test('handleResponse advances through concepts and MCQs to review', () {
      _advanceToPlanCompleted(notifier);
      _advanceTermsComplete(notifier);

      // Add concepts
      notifier.handleResponse(jsonEncode([
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'}
      ]));
      expect(notifier.state!.currentPhase, GenerationPhase.generatingMcqs);

      // Add MCQs
      notifier.handleResponse(jsonEncode([
        {'type': 'mcq', 'question': 'Q1', 'options': ['a','b','c','d'], 'correct_answer': 'a'}
      ]));
      expect(notifier.state!.currentPhase, GenerationPhase.reviewing);
    });

    test('handleResponse completes session after review', () {
      _advanceToReview(notifier);

      notifier.handleResponse(jsonEncode({
        'review_summary': {'total_items': 4, 'items_passed': 4, 'items_revised': 0, 'issues_found': []},
        'revised_content': [],
      }));

      expect(notifier.state!.currentPhase, GenerationPhase.complete);
    });

    test('skipReview advances to complete from reviewing phase', () {
      _advanceToReview(notifier);
      notifier.skipReview();
      expect(notifier.state!.currentPhase, GenerationPhase.complete);
    });

    test('skipReview is a no-op when not in reviewing phase', () {
      _advanceToPlanCompleted(notifier);
      notifier.skipReview();
      expect(notifier.state!.currentPhase, GenerationPhase.generatingTerms);
    });

    test('getAssembledLesson returns assembled JSON when session exists', () {
      _advanceToReview(notifier);
      notifier.skipReview();
      final assembled = notifier.getAssembledLesson();
      expect(assembled, isNotNull);
      expect(assembled!.containsKey('title'), isTrue);
      expect(assembled.containsKey('terms'), isTrue);
      expect(assembled.containsKey('concepts'), isTrue);
      expect(assembled.containsKey('questions'), isTrue);
    });

    test('clearSession resets state to null', () {
      notifier.startSession(
        subject: 'Math',
        targetAudience: 'Students',
        durationMinutes: 20,
        difficulty: 'intermediate',
        contentFocus: 'mixed',
      );
      notifier.clearSession();
      expect(notifier.state, isNull);
    });

    test('handleResponse returns error on malformed JSON', () {
      notifier.startSession(
        subject: 'Math',
        targetAudience: 'Students',
        durationMinutes: 20,
        difficulty: 'intermediate',
        contentFocus: 'mixed',
      );
      final error = notifier.handleResponse('not { valid json');
      expect(error, contains('Invalid JSON'));
    });

    test('handleResponse accepts wrapped content batches', () {
      _advanceToPlanCompleted(notifier);

      // Response wrapped in {"terms": [...]} instead of bare array
      final error = notifier.handleResponse(jsonEncode({
        'terms': [
          {'type': 'term', 'title': 'Variable', 'content': 'Def 1'},
          {'type': 'term', 'title': 'Assignment', 'content': 'Def 2'},
        ]
      }));
      expect(error, isNull);
      expect(notifier.state!.terms.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // AiPromptService phased methods tests
  // ---------------------------------------------------------------------------

  group('AiPromptService phased prompts', () {
    test('generateCurriculumPlanPrompt contains required XML tags', () {
      final prompt = AiPromptService.generateCurriculumPlanPrompt(
        subject: 'Physics',
        targetAudience: 'High school',
        durationMinutes: 30,
        difficulty: 'intermediate',
        contentFocus: 'concepts',
      );

      expect(prompt, contains('<role>'));
      expect(prompt, contains('<task>'));
      expect(prompt, contains('<output_requirements>'));
      expect(prompt, contains('<quality_rules>'));
      expect(prompt, contains('Physics'));
      expect(prompt, contains('High school'));
    });

    test('generateTermsPrompt includes plan context and batch range', () {
      final prompt = AiPromptService.generateTermsPrompt(
        lessonPlan: _samplePlan,
        batchStart: 0,
        batchSize: 2,
        difficulty: 'beginner',
      );

      expect(prompt, contains('<lesson_plan>'));
      expect(prompt, contains('<critical_rules>'));
      expect(prompt, contains('<quality_checklist>'));
      expect(prompt, contains('0 through 1'));
    });

    test('generateConceptsPrompt includes terms context', () {
      final generatedTerms = [
        {'type': 'term', 'title': 'Variable', 'content': 'A named storage location'}
      ];

      final prompt = AiPromptService.generateConceptsPrompt(
        lessonPlan: _samplePlan,
        generatedTerms: generatedTerms,
        batchStart: 0,
        batchSize: 1,
        difficulty: 'beginner',
      );

      expect(prompt, contains('<previously_generated_terms>'));
      expect(prompt, contains('Variable'));
    });

    test('generateMcqsPrompt includes terms and concepts context', () {
      final terms = [{'type': 'term', 'title': 'Variable'}];
      final concepts = [{'type': 'concept', 'title': 'Declaring Variables'}];

      final prompt = AiPromptService.generateMcqsPrompt(
        lessonPlan: _samplePlan,
        generatedTerms: terms,
        generatedConcepts: concepts,
        batchStart: 0,
        batchSize: 1,
      );

      expect(prompt, contains('<lesson_terms>'));
      expect(prompt, contains('<lesson_concepts>'));
      expect(prompt, contains('cognitive_level'));
    });

    test('generateSelfReviewPrompt includes plan and content', () {
      final content = [
        {'type': 'term', 'title': 'Variable', 'content': '...'},
      ];

      final prompt = AiPromptService.generateSelfReviewPrompt(
        lessonPlan: _samplePlan,
        allContent: content,
      );

      expect(prompt, contains('<original_plan>'));
      expect(prompt, contains('<generated_content>'));
      expect(prompt, contains('<review_criteria>'));
    });
  });

  // ---------------------------------------------------------------------------
  // MCQ correct_answer resolution tests
  // ---------------------------------------------------------------------------

  group('MCQ answer resolution', () {
    GenerationSession _sessionWithMcq(Map<String, dynamic> mcq) {
      return GenerationSession(
        id: 'test',
        createdAt: DateTime.utc(2025),
        subject: 'Test',
        targetAudience: 'beginner',
        durationMinutes: 15,
        difficulty: 'beginner',
        contentFocus: 'balanced',
        lessonPlan: _samplePlan,
        terms: [
          {'title': 'Variable', 'content': 'A named storage location.'},
          {'title': 'Assignment', 'content': 'Storing a value.'},
        ],
        concepts: [
          {'title': 'Declaring Variables', 'content': '...'},
        ],
        mcqs: [mcq],
        currentPhase: GenerationPhase.complete,
      );
    }

    test('exact match resolves correctly', () {
      final session = _sessionWithMcq({
        'question': 'Q1',
        'options': ['Apple', 'Banana', 'Cherry'],
        'correct_answer': 'Banana',
        'explanation': 'Banana is correct.',
      });

      final assembled = session.assemble();
      final q = (assembled['questions'] as List).first;
      expect(q['correct_answer'], 1);
      expect(q['_needs_review'], isNull);
    });

    test('case-insensitive match resolves correctly', () {
      final session = _sessionWithMcq({
        'question': 'Q1',
        'options': ['Apple', 'Banana', 'Cherry'],
        'correct_answer': 'banana',
        'explanation': 'Banana is correct.',
      });

      final assembled = session.assemble();
      final q = (assembled['questions'] as List).first;
      expect(q['correct_answer'], 1);
      expect(q['_needs_review'], isNull);
    });

    test('trimmed match resolves correctly', () {
      final session = _sessionWithMcq({
        'question': 'Q1',
        'options': ['Apple', 'Banana', 'Cherry'],
        'correct_answer': '  Banana  ',
        'explanation': 'Banana is correct.',
      });

      final assembled = session.assemble();
      final q = (assembled['questions'] as List).first;
      expect(q['correct_answer'], 1);
      expect(q['_needs_review'], isNull);
    });

    test('no match flags for review', () {
      final session = _sessionWithMcq({
        'question': 'Q1',
        'options': ['Apple', 'Banana', 'Cherry'],
        'correct_answer': 'Dragonfruit',
      });

      final assembled = session.assemble();
      final q = (assembled['questions'] as List).first;
      expect(q['correct_answer'], 0); // defaults to 0
      expect(q['_needs_review'], isTrue);
      expect(q['_review_reason'], contains('did not match'));
    });

    test('duplicate options flagged for review', () {
      final session = _sessionWithMcq({
        'question': 'Q1',
        'options': ['Apple', 'Apple', 'Cherry'],
        'correct_answer': 'Apple',
      });

      final assembled = session.assemble();
      final q = (assembled['questions'] as List).first;
      expect(q['_needs_review'], isTrue);
      expect(q['_review_reason'], contains('duplicate'));
    });

    test('missing explanation flagged for review', () {
      final session = _sessionWithMcq({
        'question': 'Q1',
        'options': ['Apple', 'Banana', 'Cherry'],
        'correct_answer': 'Apple',
        'explanation': '',
      });

      final assembled = session.assemble();
      final q = (assembled['questions'] as List).first;
      expect(q['_needs_review'], isTrue);
      expect(q['_review_reason'], contains('missing explanation'));
    });
  });

  // ---------------------------------------------------------------------------
  // Batch schema validation tests
  // ---------------------------------------------------------------------------

  group('Batch schema validation', () {
    late GenerationSessionNotifier notifier;

    setUp(() {
      notifier = GenerationSessionNotifier();
      _advanceToPlanCompleted(notifier);
    });

    test('rejects terms missing title', () {
      final error = notifier.handleResponse(jsonEncode([
        {'type': 'term', 'content': 'A definition without a title'},
      ]));

      expect(error, isNotNull);
      expect(error, contains('missing "title"'));
    });

    test('rejects terms missing content', () {
      final error = notifier.handleResponse(jsonEncode([
        {'type': 'term', 'title': 'Something'},
      ]));

      expect(error, isNotNull);
      expect(error, contains('missing "content"'));
    });

    test('accepts terms with alternative field names', () {
      final error = notifier.handleResponse(jsonEncode([
        {'type': 'term', 'term': 'Variable', 'definition': 'A named storage.'},
        {'type': 'term', 'term': 'Assignment', 'definition': 'Storing.'},
      ]));

      expect(error, isNull);
    });

    test('rejects MCQs missing question', () {
      _advanceTermsComplete(notifier);
      notifier.handleResponse(jsonEncode([
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
      ]));

      final error = notifier.handleResponse(jsonEncode([
        {
          'type': 'mcq',
          'options': ['a', 'b', 'c', 'd'],
          'correct_answer': 'a',
        },
      ]));

      expect(error, isNotNull);
      expect(error, contains('missing "question"'));
    });

    test('rejects MCQs with insufficient options', () {
      _advanceTermsComplete(notifier);
      notifier.handleResponse(jsonEncode([
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
      ]));

      final error = notifier.handleResponse(jsonEncode([
        {
          'type': 'mcq',
          'question': 'Q1',
          'options': ['a'],
          'correct_answer': 'a',
        },
      ]));

      expect(error, isNotNull);
      expect(error, contains('insufficient "options"'));
    });
  });

  // ---------------------------------------------------------------------------
  // ManifestValidator tests
  // ---------------------------------------------------------------------------

  group('ManifestValidator', () {
    test('returns valid result when all content is present', () {
      final content = [
        {'type': 'term', 'title': 'Variable', 'content': 'A named storage location in memory.'},
        {'type': 'term', 'title': 'Assignment', 'content': 'The act of storing a value in a variable.'},
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
        {'type': 'mcq', 'question': 'Q1', 'options': ['a','b','c','d'], 'correct_answer': 'a', 'explanation': 'Because...'},
      ];

      final result = ManifestValidator.validate(
        lessonPlan: _samplePlan,
        generatedContent: content,
      );

      expect(result.missingItems, isEmpty);
      expect(result.completenessScore, 100.0);
    });

    test('detects missing terms', () {
      final content = [
        {'type': 'term', 'title': 'Variable', 'content': '...'},
        // Missing Assignment
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
        {'type': 'mcq', 'question': 'Q1', 'options': ['a','b','c','d'], 'correct_answer': 'a', 'explanation': 'Why'},
      ];

      final result = ManifestValidator.validate(
        lessonPlan: _samplePlan,
        generatedContent: content,
      );

      expect(result.missingItems, contains('Term: Assignment'));
    });

    test('detects MCQ correct_answer mismatch', () {
      final content = [
        {'type': 'term', 'title': 'Variable', 'content': '...'},
        {'type': 'term', 'title': 'Assignment', 'content': '...'},
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
        {
          'type': 'mcq',
          'question': 'What is a var?',
          'options': ['a', 'b', 'c', 'd'],
          'correct_answer': 'z', // doesn't match any option
          'explanation': 'Explanation',
        },
      ];

      final result = ManifestValidator.validate(
        lessonPlan: _samplePlan,
        generatedContent: content,
      );

      expect(result.mcqIssues.any((i) => i.contains('does not match')), isTrue);
    });

    test('detects MCQ missing explanation', () {
      final content = [
        {'type': 'term', 'title': 'Variable', 'content': '...'},
        {'type': 'term', 'title': 'Assignment', 'content': '...'},
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
        {
          'type': 'mcq',
          'question': 'What is a var?',
          'options': ['a', 'b', 'c', 'd'],
          'correct_answer': 'a',
          // no explanation
        },
      ];

      final result = ManifestValidator.validate(
        lessonPlan: _samplePlan,
        generatedContent: content,
      );

      expect(result.mcqIssues.any((i) => i.contains('missing explanation')), isTrue);
    });

    test('detects terminology drift from glossary', () {
      final content = [
        {
          'type': 'term',
          'title': 'Variable',
          'content': 'A fruit that grows on trees.', // totally wrong
        },
        {'type': 'term', 'title': 'Assignment', 'content': 'The act of storing a value in a variable.'},
        {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'},
        {'type': 'mcq', 'question': 'Q1', 'options': ['a','b','c','d'], 'correct_answer': 'a', 'explanation': 'Why'},
      ];

      final result = ManifestValidator.validate(
        lessonPlan: _samplePlan,
        generatedContent: content,
      );

      expect(result.terminologyDrifts, isNotEmpty);
    });

    test('completeness score reflects missing content', () {
      // Only 2 of 4 expected items
      final content = [
        {'type': 'term', 'title': 'Variable', 'content': '...'},
        {'type': 'term', 'title': 'Assignment', 'content': '...'},
      ];

      final result = ManifestValidator.validate(
        lessonPlan: _samplePlan,
        generatedContent: content,
      );

      expect(result.completenessScore, 50.0);
      expect(result.totalExpected, 4);
      expect(result.totalGenerated, 2);
    });
  });
}

// =============================================================================
// Test helpers — advance the notifier through phases
// =============================================================================

void _advanceToPlanCompleted(GenerationSessionNotifier notifier) {
  notifier.startSession(
    subject: 'Programming',
    targetAudience: 'Beginners',
    durationMinutes: 15,
    difficulty: 'beginner',
    contentFocus: 'mixed',
  );
  notifier.handleResponse(jsonEncode(_samplePlan));
}

void _advanceTermsComplete(GenerationSessionNotifier notifier) {
  notifier.handleResponse(jsonEncode([
    {'type': 'term', 'title': 'Variable', 'content': 'Def 1'},
    {'type': 'term', 'title': 'Assignment', 'content': 'Def 2'},
  ]));
}

void _advanceToReview(GenerationSessionNotifier notifier) {
  _advanceToPlanCompleted(notifier);
  _advanceTermsComplete(notifier);
  notifier.handleResponse(jsonEncode([
    {'type': 'concept', 'title': 'Declaring Variables', 'content': '...'}
  ]));
  notifier.handleResponse(jsonEncode([
    {'type': 'mcq', 'question': 'Q1', 'options': ['a','b','c','d'], 'correct_answer': 'a'}
  ]));
}
