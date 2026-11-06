import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/widgets/video/creator_channel_card.dart';

void main() {
  group('CreatorChannelCard Widget Tests (OPP-2)', () {
    const creator = CreatorProfileCore(
      id: 'creator-science-hub',
      channelName: 'NeuroScienceHub',
      displayName: 'Dr. Evelyn Carter',
      bio: 'Cognitive neurology professor researching retention algorithms and spaced repetition.',
    );

    final modules = [
      const VideoInteractiveModule(
        id: 'mod-1',
        title: 'Memory Consolidation During Sleep',
        sourceType: VideoSourceType.youtube,
        rawVideoUrl: 'https://youtube.com/watch?v=mod1',
        durationSeconds: 720,
        measuredLearningGain: 0.72,
        checkpoints: [
          VideoCheckpoint(
            id: 'cp-1',
            timestampSeconds: 0,
            type: VideoCheckpointType.prequestion,
            item: AssessmentItemCore(
              id: 'item-1',
              stem: 'When does synaptic consolidation peak?',
              options: [AssessmentOptionCore(text: 'SWS slow-wave sleep', isCorrect: true)],
            ),
          ),
        ],
      ),
      const VideoInteractiveModule(
        id: 'mod-2',
        title: 'Spaced Retrieval Mechanisms',
        sourceType: VideoSourceType.youtube,
        rawVideoUrl: 'https://youtube.com/watch?v=mod2',
        durationSeconds: 480,
        measuredLearningGain: 0.68,
      ),
    ];

    testWidgets('renders creator information and evidence-based gain ranking badge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatorChannelCard(
              creator: creator,
              modules: modules,
            ),
          ),
        ),
      );

      // Verify creator identity
      expect(find.text('Dr. Evelyn Carter'), findsOneWidget);
      expect(find.text('@NeuroScienceHub'), findsOneWidget);
      expect(find.textContaining('Cognitive neurology professor'), findsOneWidget);

      // Verify OPP-2 ranking philosophy subtitle
      expect(
        find.text('Ranked by measured learning gain (Hake g) - Not by likes or view counts'),
        findsOneWidget,
      );

      // Verify aggregate gain badge: avg(0.72, 0.68) = 0.70 -> 70% HIGH
      expect(find.byKey(const Key('channel_gain_badge')), findsOneWidget);
      expect(find.text('Gain: 70%'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);

      // Verify modules list
      expect(find.text('Interactive Modules (2)'), findsOneWidget);
      expect(find.text('Memory Consolidation During Sleep'), findsOneWidget);
      expect(find.text('1 prequestions'), findsOneWidget);
      expect(find.text('Spaced Retrieval Mechanisms'), findsOneWidget);
    });

    testWidgets('triggers onSelectModule callback when a module is tapped', (tester) async {
      VideoInteractiveModule? selectedModule;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatorChannelCard(
              creator: creator,
              modules: modules,
              onSelectModule: (mod) {
                selectedModule = mod;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('module_tile_mod-1')));
      await tester.pump();

      expect(selectedModule?.id, equals('mod-1'));
    });
  });
}
