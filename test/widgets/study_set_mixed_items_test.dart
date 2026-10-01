import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/screens/study/mixed_mode_screen.dart';
import 'package:learning_pwa/screens/study/study_set_mixed_items.dart';
import 'package:learning_pwa/services/study_set_service.dart';

void main() {
  test(
    'mixed items retain interleaved lesson order and append standalone cards',
    () {
      final now = DateTime(2026);
      final set = StudySet(
        lessonIds: const ['lesson-1'],
        terms: [
          Term(
            id: 'term-1',
            term: 'Subnet',
            definition: 'Segment',
            createdBy: 'user-1',
          ),
          Term(
            id: 'card-1',
            term: 'VLAN',
            definition: 'Virtual LAN',
            createdBy: 'user-1',
          ),
        ],
        concepts: const [],
        questions: [
          Question(
            id: 'question-1',
            questionText: 'Which is a subnet?',
            options: const ['A', 'B'],
            correctAnswer: 0,
            type: 'mcq',
            createdBy: 'user-1',
          ),
        ],
      );

      final items = studySetMixedItems(
        set,
        orderedLessonContent: [
          QuestionContent(
            id: 'question-1',
            lessonId: 'lesson-1',
            order: 0,
            questionText: 'Which is a subnet?',
            options: const ['A', 'B'],
            correctAnswer: 0,
            createdAt: now,
            updatedAt: now,
          ),
          TermContent(
            id: 'term-1',
            lessonId: 'lesson-1',
            order: 1,
            term: 'Subnet',
            definition: 'Segment',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(items.map((item) => item.type), ['mcq', 'flashcard', 'flashcard']);
      expect(items.map((item) => item.data.id), [
        'question-1',
        'term-1',
        'card-1',
      ]);
    },
  );

  testWidgets(
    'mixed mode includes a standalone card alongside lesson content',
    (tester) async {
      final set = StudySet(
        lessonIds: const ['lesson-1'],
        terms: [
          Term(
            id: 'lesson-term',
            term: 'Subnet',
            definition: 'A network segment',
            createdBy: 'user-1',
          ),
          Term(
            id: 'standalone-card',
            term: 'VLAN',
            definition: 'A virtual LAN',
            createdBy: 'user-1',
          ),
        ],
        concepts: const [],
        questions: const [],
      );

      final items = studySetMixedItems(set);
      expect(items.map((item) => (item.data as Term).id), [
        'lesson-term',
        'standalone-card',
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [canSpeakProvider.overrideWithValue(false)],
          child: MaterialApp(home: MixedModeScreen(preSortedItems: items)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subnet'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
