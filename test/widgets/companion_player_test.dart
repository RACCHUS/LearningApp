import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/companion/video_embed.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/screens/companion/companion_screen.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/services/companion/outline_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

const goal = (targetId: 't1', targetVersionId: 'v1', targetSlug: 's1');
const video = 'https://www.youtube.com/watch?v=abcdefghijk';

final nodes = [
  CurriculumNode(
    id: 'd1',
    targetVersionId: 'v1',
    nodeType: 'domain',
    title: 'Algebra',
    sortOrder: 1,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  CurriculumNode(
    id: 'o1',
    targetVersionId: 'v1',
    parentId: 'd1',
    nodeType: 'objective',
    title: 'Exponents',
    code: '1.1',
    sortOrder: 1,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

Future<String> seed({String? url = video}) async {
  final store = LocalLearnerResourceStore();
  final id = await store.save(
    targetId: 't1',
    title: 'My video',
    kind: LearnerResourceKind.video,
    url: url,
  );
  await store.setSections(id, const [
    ResourceSection(title: 'Intro', startSeconds: 0, minutes: 3),
    ResourceSection(
      title: 'Exponents',
      objectiveKeys: {'1.1'},
      startSeconds: 135,
    ),
    ResourceSection(title: 'No start time'),
  ]);
  return id;
}

Future<void> pump(
  WidgetTester tester,
  String id, {
  bool embeds = true,
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learnerResourcesEnabledProvider.overrideWithValue(true),
        companionEmbedsEnabledProvider.overrideWithValue(embeds),
        learnerResourcesUseAccountProvider.overrideWithValue(false),
        learnerResourceStoreProvider.overrideWithValue(
          LocalLearnerResourceStore(),
        ),
        targetCurriculumNodesProvider.overrideWith((ref, id) async => nodes),
        objectiveReadinessProvider.overrideWith((ref, id) async => null),
        targetCoverageProvider.overrideWith(
          (ref, slug) async => CoverageSummary([]),
        ),
      ],
      child: MaterialApp(
        home: CompanionScreen(goal: goal, resourceId: id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String frameUrl(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('embed_frame_stub')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('which links can play here', () {
    test('a single YouTube video in any of its usual forms', () {
      for (final url in [
        'https://www.youtube.com/watch?v=abcdefghijk',
        'https://youtube.com/watch?v=abcdefghijk&t=30',
        'https://m.youtube.com/watch?v=abcdefghijk',
        'https://youtu.be/abcdefghijk',
        'https://www.youtube.com/embed/abcdefghijk',
        'https://www.youtube.com/shorts/abcdefghijk',
        'https://www.youtube.com/live/abcdefghijk',
      ]) {
        expect(VideoEmbed.youTubeId(url), 'abcdefghijk', reason: url);
      }
    });

    test(
      'nothing else: playlists, channels, other sites, look-alikes, bad ids',
      () {
        expect(VideoEmbed.youTubeId(null), isNull);
        expect(VideoEmbed.youTubeId(''), isNull);
        expect(VideoEmbed.youTubeId('https://vimeo.com/123456789'), isNull);
        expect(
          VideoEmbed.youTubeId('https://www.youtube.com/@somechannel'),
          isNull,
        );
        expect(
          VideoEmbed.youTubeId('https://www.youtube.com/watch?v=short'),
          isNull,
        );
        expect(
          VideoEmbed.youTubeId(
            'https://www.youtube.com.evil.example/watch?v=abcdefghijk',
          ),
          isNull,
        );
        expect(
          VideoEmbed.youTubeId(
            'https://evil.example/?u=https://youtu.be/abcdefghijk',
          ),
          isNull,
        );
        expect(
          VideoEmbed.youTubeId('http://www.youtube.com/watch?v=abcdefghijk'),
          isNull,
        );
        expect(
          VideoEmbed.youTubeId(
            'https://www.youtube.com/watch?v=abcdefghijk"><script>',
          ),
          isNull,
        );
        expect(
          VideoEmbed.youTubeId(
            'https://www.youtube.com/playlist?list=PL1234567890',
          ),
          isNull,
        );
      },
    );

    test(
      'the player address is the privacy-enhanced domain with only documented parameters',
      () {
        final plain = VideoEmbed.youTubeEmbedUri('abcdefghijk');
        expect(
          plain.toString(),
          'https://www.youtube-nocookie.com/embed/abcdefghijk?playsinline=1',
        );
        final from = VideoEmbed.youTubeEmbedUri(
          'abcdefghijk',
          startSeconds: 135,
        );
        expect(from.queryParameters, {'playsinline': '1', 'start': '135'});
        expect(from.queryParameters.containsKey('autoplay'), isFalse);
        expect(VideoEmbed.clock(135), '2:15');
        expect(VideoEmbed.clock(3753), '1:02:33');
      },
    );
  });

  test(
    'a video chapter list gives each part a start and a length up to the next start',
    () {
      final parsed = OutlineMapper.parse(
        [
          '0:00 Intro',
          '2:15 Exponents',
          '10:00 - Radicals (5 min)',
          'Wrap-up',
        ].join('\n'),
      );
      expect(parsed.titles, ['Intro', 'Exponents', 'Radicals', 'Wrap-up']);
      expect(parsed.starts, [0, 135, 600, null]);
      expect(parsed.minutes, [3, 8, 5, null]);
    },
  );

  testWidgets('with the switch off there is no player and no offer', (
    tester,
  ) async {
    await pump(tester, await seed(), embeds: false);
    expect(find.byKey(const Key('companion_player_offer')), findsNothing);
    expect(find.byKey(const Key('companion_player')), findsNothing);
    expect(find.byKey(const Key('companion_play_part_0')), findsNothing);
    expect(find.text('Open (leaves LearningApp)'), findsOneWidget);
  });

  testWidgets(
    'a link that is not a single YouTube video is never played here',
    (tester) async {
      await pump(tester, await seed(url: 'https://example.org/course'));
      expect(find.byKey(const Key('companion_player_offer')), findsNothing);
      expect(find.byKey(const Key('companion_play_part_0')), findsNothing);
    },
  );

  testWidgets(
    'nothing is loaded until the learner taps play, and the notice says who sees what',
    (tester) async {
      await pump(tester, await seed());
      expect(find.byKey(const Key('embed_frame_stub')), findsNothing);
      final notice = tester
          .widget<Text>(find.byKey(const Key('companion_player_notice')))
          .data!;
      expect(notice, contains('loads the video from YouTube'));
      expect(notice, contains('LearningApp does not record what you watch'));
      expect(notice, contains('never counts as studied'));
      expect(notice, contains("you agree to YouTube's Terms of Service"));
      expect(find.byKey(const Key('companion_player_terms')), findsOneWidget);
      expect(find.byKey(const Key('companion_player_privacy')), findsOneWidget);

      await tester.tap(find.byKey(const Key('companion_play_here')));
      await tester.pumpAndSettle();
      expect(
        frameUrl(tester),
        'https://www.youtube-nocookie.com/embed/abcdefghijk?playsinline=1',
      );
      expect(find.byKey(const Key('companion_player_offer')), findsNothing);

      await tester.tap(find.byKey(const Key('companion_player_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('embed_frame_stub')), findsNothing);
      expect(find.byKey(const Key('companion_play_here')), findsOneWidget);
    },
  );

  testWidgets(
    '"play this part" starts at its time, and playing marks nothing studied',
    (tester) async {
      final id = await seed();
      await LocalLearnerResourceStore().setSectionStudied(id, 0, true);
      await pump(tester, id);
      expect(
        find.text('Play this part here, from 2:15 (loads YouTube)'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('companion_play_part_1')));
      await tester.pumpAndSettle();
      expect(frameUrl(tester), contains('start=135'));

      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(
        saved.studiedSectionCount,
        1,
        reason: 'only the part marked by hand',
      );
      expect(saved.sections[1].studied, isFalse);
      expect(saved.studiedCount, 0);
      expect(
        find.byKey(const Key('companion_done_1')),
        findsOneWidget,
        reason: 'the checks and the mark stay below',
      );
    },
  );

  testWidgets(
    'the player is at least 200 by 200 in a 320-wide pane and nothing overlaps it',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, await seed(), width: 320);
      await tester.tap(find.byKey(const Key('companion_play_here')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final frame = tester.getRect(find.byKey(const Key('embed_frame_stub')));
      expect(frame.width, greaterThanOrEqualTo(200));
      expect(frame.height, greaterThanOrEqualTo(200));
      final close = tester.getRect(
        find.byKey(const Key('companion_player_close')),
      );
      expect(
        close.top,
        greaterThanOrEqualTo(frame.bottom),
        reason: 'controls sit below the player, not on it',
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  test(
    'start times survive device storage and are dropped when out of range',
    () async {
      final id = await seed();
      final r = (await LocalLearnerResourceStore().list('t1')).single;
      expect(r.id, id);
      expect([for (final s in r.sections) s.startSeconds], [0, 135, null]);
      expect(
        ResourceSection.fromJson({
          'title': 'x',
          'start_seconds': -4,
        }).startSeconds,
        isNull,
      );
      expect(
        ResourceSection.fromJson({
          'title': 'x',
          'start_seconds': 999999,
        }).startSeconds,
        isNull,
      );
      expect(
        const ResourceSection(title: 'x').toRpcJson().containsKey('start'),
        isFalse,
      );
    },
  );
}
