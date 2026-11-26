import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/screens/companion/companion_for_link_screen.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const goals = <CaptureGoal>[
  (targetId: 't1', label: 'CLEP College Algebra'),
  (targetId: 't2', label: 'GRE General Test'),
];

Future<void> pump(
  WidgetTester tester, {
  String? url,
  String? title,
  bool enabled = true,
  List<CaptureGoal> withGoals = goals,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        companionExtensionEnabledProvider.overrideWithValue(enabled),
        companionCaptureEnabledProvider.overrideWithValue(false),
        companionEmbedsEnabledProvider.overrideWithValue(false),
        captureGoalsProvider.overrideWithValue(withGoals),
        learnerResourcesEnabledProvider.overrideWithValue(true),
        learnerResourcesUseAccountProvider.overrideWithValue(false),
        learnerResourceStoreProvider.overrideWithValue(
          LocalLearnerResourceStore(),
        ),
        targetDetailProvider.overrideWith((ref, id) async => _target(id)),
        targetVersionProvider.overrideWith((ref, id) async => _version(id)),
        targetCurriculumNodesProvider.overrideWith(
          (ref, id) async => const <CurriculumNode>[],
        ),
        objectiveReadinessProvider.overrideWith((ref, id) async => null),
        targetCoverageProvider.overrideWith(
          (ref, slug) async => CoverageSummary([]),
        ),
      ],
      child: MaterialApp(
        home: CompanionForLinkScreen(url: url, title: title),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LearningTarget _target(String id) => LearningTarget.fromJson({
  'id': id,
  'target_type': 'curriculum_standard',
  'title': 'Goal $id',
  'slug': 'goal-$id',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
});

TargetVersion _version(String id) => TargetVersion.fromJson({
  'id': 'v-$id',
  'target_id': id,
  'version_code': 'A',
  'status': 'published',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
});

String field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'two links are the same resource when they are the same video or the same address',
    () {
      expect(
        sameResourceLink(
          'https://example.org/course',
          'https://example.org/course/',
        ),
        isTrue,
      );
      expect(
        sameResourceLink(
          'https://example.org/course#unit-2',
          'https://example.org/course',
        ),
        isTrue,
      );
      expect(
        sameResourceLink(
          'https://example.org/course?id=1',
          'https://example.org/course?id=2',
        ),
        isFalse,
      );
      expect(
        sameResourceLink('https://example.org/a', 'https://example.com/a'),
        isFalse,
      );
      expect(
        sameResourceLink(
          'https://www.youtube.com/watch?v=abcdefghijk&t=90',
          'https://youtu.be/abcdefghijk',
        ),
        isTrue,
      );
      expect(
        sameResourceLink(
          'https://www.youtube.com/watch?v=abcdefghijk',
          'https://www.youtube.com/watch?v=zzzzzzzzzzz',
        ),
        isFalse,
      );
      expect(
        sameResourceLink(
          'https://www.youtube.com/watch?v=abcdefghijk',
          'https://example.org/x',
        ),
        isFalse,
      );
    },
  );

  testWidgets('with the switch off it says so and offers nothing', (
    tester,
  ) async {
    await pump(
      tester,
      url: 'https://example.org/course',
      title: 'A course',
      enabled: false,
    );
    expect(find.byKey(const Key('extension_unavailable')), findsOneWidget);
    expect(find.byKey(const Key('capture_save')), findsNothing);
    expect(find.byKey(const Key('help-action')), findsOneWidget);
  });

  testWidgets(
    'a page that is one of the learner\'s resources opens its companion',
    (tester) async {
      final store = LocalLearnerResourceStore();
      await store.save(
        targetId: 't1',
        title: 'Other',
        kind: LearnerResourceKind.book,
      );
      final id = await store.save(
        targetId: 't2',
        title: 'My GRE course',
        kind: LearnerResourceKind.course,
        url: 'https://example.org/gre/course',
      );
      await store.setSections(id, const [
        ResourceSection(title: 'Unit 1', minutes: 20),
      ]);
      await pump(
        tester,
        url: 'https://example.org/gre/course/?utm_source=mail#week-2',
        title: 'GRE course',
        // Found even though the learner has not started learning that goal.
        withGoals: const [],
      );
      expect(find.text('My GRE course'), findsOneWidget);
      expect(find.byKey(const Key('companion_summary')), findsOneWidget);
      expect(find.byKey(const Key('companion_done_0')), findsOneWidget);
      expect(find.byKey(const Key('capture_save')), findsNothing);
    },
  );

  testWidgets(
    'a page that is not a resource yet opens the add form, with no bookmark tip',
    (tester) async {
      await pump(
        tester,
        url: 'https://example.org/new?fbclid=1',
        title: ' New  course ',
      );
      expect(field(tester, 'capture_title'), 'New course');
      expect(field(tester, 'capture_link'), 'https://example.org/new');
      expect(find.byKey(const Key('capture_how')), findsNothing);
      expect(
        await LocalLearnerResourceStore().listAll(),
        isEmpty,
        reason: 'nothing is saved by opening it',
      );

      await tester.tap(find.byKey(const Key('capture_save')));
      await tester.pumpAndSettle();
      expect(
        (await LocalLearnerResourceStore().listAll()).single.url,
        'https://example.org/new',
      );
    },
  );

  testWidgets(
    'a browser page or a missing address falls back to the plain form',
    (tester) async {
      await pump(tester, url: 'about:config', title: 'Settings');
      expect(field(tester, 'capture_link'), '');
      expect(field(tester, 'capture_title'), 'Settings');
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(field(tester, 'capture_link'), '');
    },
  );

  group('the extension files', () {
    Map<String, dynamic> manifest(String browser) =>
        jsonDecode(File('extension/$browser/manifest.json').readAsStringSync())
            as Map<String, dynamic>;

    test('ask for one permission and nothing that reads pages', () {
      for (final browser in ['firefox', 'chrome']) {
        final m = manifest(browser);
        expect(m['manifest_version'], 3, reason: browser);
        expect(m['permissions'], ['activeTab'], reason: browser);
        for (final key in [
          'host_permissions',
          'optional_permissions',
          'optional_host_permissions',
          'content_scripts',
        ]) {
          expect(
            m.containsKey(key),
            isFalse,
            reason: '$browser must not declare $key',
          );
        }
        expect(
          m.containsKey('externally_connectable'),
          isFalse,
          reason: browser,
        );
        expect(File('extension/$browser/icon-192.png').existsSync(), isTrue);
      }
      expect(manifest('chrome')['background'], {
        'service_worker': 'background.js',
      });
      expect(manifest('firefox')['background'], {
        'scripts': ['background.js'],
      });
      expect(
        (manifest('firefox')['sidebar_action'] as Map)['default_panel'],
        'panel.html',
      );
    });

    test('share one script, which keeps the page address in the fragment', () {
      final firefox = File(
        'extension/firefox/background.js',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final chrome = File(
        'extension/chrome/background.js',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(chrome, firefox, reason: 'the two copies must stay identical');
      expect(firefox, contains("APP_ORIGIN + '/#/companion-for'"));
      expect(
        firefox,
        contains("const APP_ORIGIN = 'https://learningapp-2ed8a.web.app';"),
      );
      for (final banned in [
        'fetch(',
        'XMLHttpRequest',
        'storage.',
        'cookies',
        'history.',
        'scripting',
        'executeScript',
        'eval(',
      ]) {
        expect(
          firefox.contains(banned),
          isFalse,
          reason: 'the extension must not use $banned',
        );
      }
    });

    test('the built-in panel is static: no script, no outside request', () {
      final panel = File('extension/firefox/panel.html').readAsStringSync();
      expect(panel.contains('<script'), isFalse);
      expect(panel.contains('http'), isFalse);
    });
  });
}
