import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/screens/study/lesson_screen.dart';
import 'package:learning_pwa/widgets/community/in_context_qa_sheet.dart';

import 'package:learning_pwa/providers/audio_provider.dart';

void main() {
  group('ECO-01: In-Context Learning Screen Q&A Integration', () {
    testWidgets('LessonScreen exposes forum action and launches in-context Q&A sheet', (tester) async {
      final sampleLesson = FullLesson(
        lesson: Lesson(
          id: 'lesson-qa-101',
          title: 'Phonics Blending Intro',
          tags: const ['phonics'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userId: 'user-1',
          visibility: 'public',
          terms: const [],
          questions: const [],
          concepts: const [],
        ),
        lessonContent: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnerIdProvider.overrideWith((ref) => 'user-1'),
            lessonProvider('lesson-qa-101').overrideWith((ref) => sampleLesson),
            canSpeakProvider.overrideWithValue(false),
            canListenProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: LessonScreen(lessonId: 'lesson-qa-101'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionFinder = find.byKey(const Key('lesson_in_context_qa_action'));
      expect(actionFinder, findsOneWidget);
      expect(find.byTooltip('Lesson Q&A & FAQs'), findsOneWidget);

      await tester.tap(actionFinder);
      await tester.pumpAndSettle();

      expect(find.byType(InContextQaSheet), findsOneWidget);
      expect(find.text('Phonics Blending Intro'), findsWidgets);
    });

    testWidgets('ConceptScreen exposes forum action and launches in-context Q&A sheet', (tester) async {
      final now = DateTime.now();
      final sampleConcepts = [
        ConceptContent(
          id: 'concept-qa-201',
          lessonId: 'lesson-qa-101',
          conceptText: 'Consonant-Vowel-Consonant (CVC) Blending',
          exampleText: 'c-a-t -> cat',
          keyPoints: const ['Three distinct phonemes', 'Short vowel in center'],
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canSpeakProvider.overrideWithValue(false),
            canListenProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            home: ConceptScreen(
              concepts: sampleConcepts,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionFinder = find.byKey(const Key('concept_in_context_qa_action'));
      expect(actionFinder, findsOneWidget);
      expect(find.byTooltip('Concept Q&A & FAQs'), findsOneWidget);

      await tester.tap(actionFinder);
      await tester.pumpAndSettle();

      expect(find.byType(InContextQaSheet), findsOneWidget);
      expect(find.text('Consonant-Vowel-Consonant (CVC) Blending'), findsWidgets);
    });
  });
}
