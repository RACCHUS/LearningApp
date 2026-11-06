import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/services/video/video_learning_service.dart';
import 'package:learning_pwa/widgets/video/interactive_video_player.dart';

void main() {
  group('InteractiveVideoPlayer Widget Tests (OPP-2, ER-10)', () {
    const sampleItem = AssessmentItemCore(
      id: 'cp-item-1',
      stem: 'What is the specific effect size of prequestioning on targeted concepts?',
      options: [
        AssessmentOptionCore(
          text: 'g = .54 (specific priming effect)',
          isCorrect: true,
          rationale: 'St. Hilaire, Chan & Ahn (2024) meta-analysis found g = .54 on targeted items.',
        ),
        AssessmentOptionCore(
          text: 'g = .04 (general spillover)',
          isCorrect: false,
          misconception: 'g = .04 is the general spillover across untested material in the lesson.',
        ),
        AssessmentOptionCore(
          text: 'g = 1.50 (complete mastery)',
          isCorrect: false,
        ),
      ],
      explanation: 'Prequestioning primes attention specifically to targeted concepts.',
      sourceRef: 'St. Hilaire et al. (2024)',
    );

    final sampleModule = VideoInteractiveModule(
      id: 'mod-transformers',
      title: 'Attention Is All You Need Explained',
      sourceType: VideoSourceType.youtube,
      rawVideoUrl: 'https://www.youtube.com/watch?v=mock_video_id',
      durationSeconds: 600,
      chapters: const [
        VideoChapter(
          startSeconds: 0,
          endSeconds: 120,
          title: 'Introduction & Prequestions',
        ),
        VideoChapter(
          startSeconds: 121,
          endSeconds: 600,
          title: 'Self-Attention Mechanism',
        ),
      ],
      checkpoints: const [
        VideoCheckpoint(
          id: 'cp-pre-0',
          timestampSeconds: 0,
          type: VideoCheckpointType.prequestion,
          item: sampleItem,
        ),
        VideoCheckpoint(
          id: 'cp-retrieval-200',
          timestampSeconds: 200,
          type: VideoCheckpointType.retrievalPractice,
          item: sampleItem,
        ),
      ],
      measuredLearningGain: 0.62,
    );

    testWidgets('displays initial ER-10 prequestion modal at t = 0 with priming banner',
        (tester) async {
      final service = VideoLearningService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVideoPlayer(
              module: sampleModule,
              learningService: service,
            ),
          ),
        ),
      );

      // Verify header components
      expect(find.text('Attention Is All You Need Explained'), findsOneWidget);
      expect(find.text('Introduction & Prequestions'), findsOneWidget);
      expect(find.text('Gain: 62%'), findsOneWidget);

      // Verify ER-10 Priming Badge is visible at t = 0
      expect(find.byKey(const Key('er10_priming_badge')), findsOneWidget);
      expect(find.textContaining('Concept Priming Prequestion (ER-10: g = .54)'), findsOneWidget);

      // Verify question stem and options
      expect(find.text(sampleItem.stem), findsOneWidget);
      expect(find.text('g = .54 (specific priming effect)'), findsOneWidget);
      expect(find.text('g = .04 (general spillover)'), findsOneWidget);
    });

    testWidgets('learner selects option, submits answer, views feedback, and continues video',
        (tester) async {
      final service = VideoLearningService();
      bool? completedCorrect;
      VideoCheckpoint? completedCheckpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVideoPlayer(
              module: sampleModule,
              learningService: service,
              onCheckpointCompleted: (cp, isCorrect) {
                completedCheckpoint = cp;
                completedCorrect = isCorrect;
              },
            ),
          ),
        ),
      );

      // Select correct option (index 0)
      final optFinder = find.byKey(const Key('checkpoint_option_0'));
      await tester.ensureVisible(optFinder);
      await tester.tap(optFinder);
      await tester.pumpAndSettle();

      // Tap Submit Answer
      final submitFinder = find.byKey(const Key('checkpoint_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verify callback triggered with correct=true
      expect(completedCheckpoint?.id, equals('cp-pre-0'));
      expect(completedCorrect, isTrue);

      // Verify service logged prequestion event
      expect(service.emittedEvents.length, equals(1));
      expect(service.emittedEvents.first.eventType, equals('prequestion_answered'));
      expect(service.emittedEvents.first.score, equals(1.0));

      // Explanation is displayed
      expect(find.textContaining('Explanation: Prequestioning primes attention'), findsOneWidget);

      // Tap Continue Video
      final resumeFinder = find.byKey(const Key('checkpoint_resume_button'));
      await tester.ensureVisible(resumeFinder);
      await tester.tap(resumeFinder);
      await tester.pumpAndSettle();

      // Modal is dismissed, video resumes
      expect(find.byKey(const Key('checkpoint_modal_cp-pre-0')), findsNothing);
      expect(find.text('Playing...'), findsOneWidget);
    });

    testWidgets('shows misconception note when distractor option is selected',
        (tester) async {
      final service = VideoLearningService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveVideoPlayer(
              module: sampleModule,
              learningService: service,
            ),
          ),
        ),
      );

      // Select distractor (index 1)
      final optFinder = find.byKey(const Key('checkpoint_option_1'));
      await tester.ensureVisible(optFinder);
      await tester.tap(optFinder);
      await tester.pumpAndSettle();

      // Submit
      final submitFinder = find.byKey(const Key('checkpoint_submit_button'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verify service logged score = 0.0
      expect(service.emittedEvents.first.score, equals(0.0));

      // Misconception is explicitly rendered
      expect(find.textContaining('Misconception: g = .04 is the general spillover'), findsOneWidget);
    });
  });
}
