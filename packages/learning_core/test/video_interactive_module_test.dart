import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('VideoInteractiveModule & Checkpoints', () {
    const sampleItem = AssessmentItemCore(
      id: 'item-v1',
      stem: 'What is the primary benefit of prequestioning before instruction?',
      options: [
        AssessmentOptionCore(
          text: 'It primes attention specifically to targeted concepts',
          isCorrect: true,
          rationale: 'St. Hilaire et al. (2024) meta-analysis found g = .54 specific effect.',
        ),
        AssessmentOptionCore(
          text: 'It increases general memory across all subsequent material',
          isCorrect: false,
          misconception: 'Spillover effect is statistically indistinguishable from zero (g = .04).',
        ),
        AssessmentOptionCore(
          text: 'It replaces the need to study the video',
          isCorrect: false,
        ),
        AssessmentOptionCore(
          text: 'It eliminates forgetting curves permanently',
          isCorrect: false,
        ),
      ],
      sourceRef: 'St. Hilaire, Chan & Ahn (2024)',
    );

    test('VideoInteractiveModule serializes and deserializes accurately', () {
      final module = VideoInteractiveModule(
        id: 'mod-101',
        title: 'Deep Learning with Attention Mechanisms',
        description: 'Comprehensive breakdown of transformer attention layers.',
        sourceType: VideoSourceType.youtube,
        rawVideoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        durationSeconds: 900,
        creator: const CreatorProfileCore(
          id: 'creator-42',
          channelName: 'ScienceExplained',
          displayName: 'Dr. Sarah Connor',
          bio: 'Cognitive scientist and educational researcher.',
        ),
        chapters: const [
          VideoChapter(
            startSeconds: 0,
            endSeconds: 180,
            title: 'Introduction & Intuition',
            conceptSlug: 'attention-intro',
          ),
          VideoChapter(
            startSeconds: 181,
            endSeconds: 900,
            title: 'Scaled Dot-Product Attention',
            conceptSlug: 'dot-product-attention',
          ),
        ],
        checkpoints: [
          VideoCheckpoint(
            id: 'cp-retrieval-1',
            timestampSeconds: 180,
            type: VideoCheckpointType.retrievalPractice,
            item: sampleItem,
            targetConceptSlug: 'attention-intro',
          ),
          VideoCheckpoint(
            id: 'cp-prequestion-1',
            timestampSeconds: 0,
            type: VideoCheckpointType.prequestion,
            item: sampleItem,
            targetConceptSlug: 'attention-intro',
          ),
        ],
        measuredLearningGain: 0.58,
      );

      final json = module.toJson();
      final roundTrip = VideoInteractiveModule.fromJson(json);

      expect(roundTrip.id, equals('mod-101'));
      expect(roundTrip.sourceType, equals(VideoSourceType.youtube));
      expect(roundTrip.durationSeconds, equals(900));
      expect(roundTrip.creator?.channelName, equals('ScienceExplained'));
      expect(roundTrip.chapters.length, equals(2));
      expect(roundTrip.measuredLearningGain, equals(0.58));

      // Checkpoints must be automatically sorted by timestamp ascending
      expect(roundTrip.checkpoints.first.timestampSeconds, equals(0));
      expect(roundTrip.checkpoints.last.timestampSeconds, equals(180));
      expect(roundTrip.checkpoints.first.type, equals(VideoCheckpointType.prequestion));
    });

    test('checkpoint accessor properties filter by type correctly', () {
      final module = VideoInteractiveModule(
        id: 'mod-filter',
        title: 'Filtering Checkpoints',
        sourceType: VideoSourceType.vimeo,
        rawVideoUrl: 'https://vimeo.com/123456789',
        durationSeconds: 600,
        checkpoints: [
          VideoCheckpoint(
            id: 'cp-pre',
            timestampSeconds: 0,
            type: VideoCheckpointType.prequestion,
            item: sampleItem,
          ),
          VideoCheckpoint(
            id: 'cp-retrieval',
            timestampSeconds: 200,
            type: VideoCheckpointType.retrievalPractice,
            item: sampleItem,
          ),
          VideoCheckpoint(
            id: 'cp-refl',
            timestampSeconds: 400,
            type: VideoCheckpointType.reflection,
            item: sampleItem,
          ),
        ],
      );

      expect(module.prequestions.length, equals(1));
      expect(module.prequestions.first.id, equals('cp-pre'));
      expect(module.retrievalCheckpoints.length, equals(1));
      expect(module.retrievalCheckpoints.first.id, equals('cp-retrieval'));
      expect(module.reflectionCheckpoints.length, equals(1));
      expect(module.reflectionCheckpoints.first.id, equals('cp-refl'));
    });

    test('chapterForTimestamp, checkpointAt and nextCheckpoint behave predictably', () {
      final module = VideoInteractiveModule(
        id: 'mod-nav',
        title: 'Navigating Video',
        sourceType: VideoSourceType.youtube,
        rawVideoUrl: 'https://youtube.com/watch?v=test1234567',
        durationSeconds: 1000,
        chapters: const [
          VideoChapter(startSeconds: 0, endSeconds: 300, title: 'Part 1'),
          VideoChapter(startSeconds: 301, endSeconds: 600, title: 'Part 2'),
        ],
        checkpoints: [
          VideoCheckpoint(
            id: 'cp-100',
            timestampSeconds: 100,
            type: VideoCheckpointType.retrievalPractice,
            item: sampleItem,
          ),
          VideoCheckpoint(
            id: 'cp-500',
            timestampSeconds: 500,
            type: VideoCheckpointType.retrievalPractice,
            item: sampleItem,
          ),
        ],
      );

      expect(module.chapterForTimestamp(50)?.title, equals('Part 1'));
      expect(module.chapterForTimestamp(450)?.title, equals('Part 2'));
      expect(module.chapterForTimestamp(800), isNull);

      expect(module.checkpointAt(100)?.id, equals('cp-100'));
      expect(module.checkpointAt(101)?.id, equals('cp-100')); // tolerance = 1s
      expect(module.checkpointAt(105), isNull);

      expect(module.nextCheckpoint(50)?.id, equals('cp-100'));
      expect(module.nextCheckpoint(100)?.id, equals('cp-500'));
      expect(module.nextCheckpoint(500), isNull);
    });
  });
}
