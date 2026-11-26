import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/companion/resource_catalog.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/widgets/companion/ways_to_study_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

CurriculumNode node(
  String id,
  String title, {
  String? parent,
  String? code,
  double? weight,
  int order = 0,
}) => CurriculumNode(
  id: id,
  targetVersionId: 'v1',
  parentId: parent,
  nodeType: parent == null ? 'domain' : 'objective',
  title: title,
  code: code,
  weight: weight,
  sortOrder: order,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final nodes = [
  node('d1', 'Algebra', weight: 50, order: 1),
  node('d2', 'Functions', weight: 50, order: 2),
  node('o1', 'Exponents', parent: 'd1', code: '1.1', order: 1),
  node('o2', 'Radicals', parent: 'd1', code: '1.2', order: 2),
  node('o3', 'Graphs', parent: 'd2', code: '2.1', order: 1),
];

Map<String, dynamic> record(
  String id, {
  String access = 'free_no_login',
  String status = 'approved',
  String? band,
}) => {
  'id': id,
  'kind': 'book',
  'publisher': 'Pub $id',
  'title': 'Book $id',
  'canonical_url': 'https://example.org/$id',
  'access': access,
  'price': band == null
      ? null
      : {'band': band, 'currency': 'USD', 'checked_at': '2026-11-01'},
  'has_practice': null,
  'captions': null,
  'metadata_checked_at': '2026-11-26',
  'review': {
    'status': status,
    'reviewer_kind': 'ai',
    'reviewer_model': 'm',
    'reviewed_on': '2026-11-25',
  },
};

Map<String, dynamic> section(
  String label, {
  String depth = 'teaches',
  bool practice = true,
}) => {
  'label': label,
  'locator': 'https://example.org/$label',
  'start_seconds': null,
  'end_seconds': null,
  'depth': depth,
  'has_practice': practice,
  'confidence': 'high',
};

Map<String, dynamic> map(
  String id,
  Map<String, List<Map<String, dynamic>>> coverage, {
  String status = 'approved',
}) => {
  'target_slug': 's1',
  'resource_id': id,
  'review': {'status': status},
  'coverage': [
    for (final e in coverage.entries)
      {'objective': e.key, 'covered': e.value.isNotEmpty, 'sections': e.value},
  ],
};

ResourceCatalog catalogOf(
  List<Map<String, dynamic>> resources,
  List<Map<String, dynamic>> maps,
) => ResourceCatalog.fromJson({
  'format': 'la-resource-catalog/1',
  'resources': resources,
  'maps': maps,
});

final outline = ResourceOutline.fromNodes(nodes);
const goal = (targetId: 't1', targetVersionId: 'v1', targetSlug: 's1');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ranking', () {
    test(
      'only approved records with approved maps for this goal are listed',
      () {
        final c = catalogOf(
          [record('a'), record('b', status: 'pending'), record('c')],
          [
            map('a', {
              '1.1': [section('1 A')],
            }),
            map('b', {
              '1.1': [section('1 B')],
            }),
            map('c', {
              '1.1': [section('1 C')],
            }, status: 'pending'),
          ],
        );
        expect(
          [
            for (final w in waysToStudy(
              targetSlug: 's1',
              outline: outline,
              catalog: c,
            ))
              w.resource.id,
          ],
          ['a'],
        );
        expect(
          waysToStudy(targetSlug: 'other', outline: outline, catalog: c),
          isEmpty,
        );
      },
    );

    test(
      'free first by coverage; paid after, and never without a free one',
      () {
        final c = catalogOf(
          [
            record('small'),
            record('big'),
            record('pricey', access: 'paid', band: '25_to_100'),
          ],
          [
            map('small', {
              '1.1': [section('1')],
            }),
            map('big', {
              '1.1': [section('1')],
              '1.2': [section('2')],
              '2.1': [section('3')],
            }),
            map('pricey', {
              '1.1': [section('1')],
              '1.2': [section('2')],
              '2.1': [section('3')],
            }),
          ],
        );
        final ways = waysToStudy(
          targetSlug: 's1',
          outline: outline,
          catalog: c,
        );
        expect(
          [for (final w in ways) w.resource.id],
          ['big', 'small', 'pricey'],
        );
        expect(ways.first.coverage, closeTo(1.0, 1e-9));
        expect(
          ways[1].coverage,
          closeTo(0.25, 1e-9),
          reason: 'by blueprint weight: half of a 50% area',
        );

        final paidOnly = catalogOf(
          [record('pricey', access: 'paid', band: '25_to_100')],
          [
            map('pricey', {
              '1.1': [section('1')],
            }),
          ],
        );
        expect(
          waysToStudy(targetSlug: 's1', outline: outline, catalog: paidOnly),
          isEmpty,
        );
      },
    );

    test(
      'a part that only introduces an objective does not count as covering it',
      () {
        final c = catalogOf(
          [record('a')],
          [
            map('a', {
              '1.1': [section('1', depth: 'introduces')],
              '1.2': [section('2')],
            }),
          ],
        );
        final w = waysToStudy(
          targetSlug: 's1',
          outline: outline,
          catalog: c,
        ).single;
        expect(w.coverage, closeTo(0.25, 1e-9));
        expect(w.reasons, contains('has practice for most of what it covers'));
        expect(w.reasons.first, 'covers about 25% of this goal');
      },
    );

    test(
      'the ranking code carries no placement, affiliate or sponsor logic',
      () {
        final source = File(
          'lib/models/companion/resource_catalog.dart',
        ).readAsStringSync().toLowerCase();
        for (final word in [
          'affiliate',
          'sponsor',
          'promoted',
          'placement_',
          'boost',
          'commission',
          'referral',
        ]) {
          expect(
            source.contains(word),
            isFalse,
            reason: 'the ranking must not mention $word',
          );
        }
        final card = File(
          'lib/widgets/companion/ways_to_study_card.dart',
        ).readAsStringSync().toLowerCase();
        for (final word in [
          'affiliate_link',
          'sponsor',
          'commission',
          'referral',
        ]) {
          expect(
            card.contains(word),
            isFalse,
            reason: 'the card must not mention $word',
          );
        }
      },
    );

    test(
      'the bundled catalog parses, and only reviewed entries would show',
      () {
        final c = ResourceCatalog.fromJson(
          jsonDecode(
                File(
                  'assets/companion/resource_catalog.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        expect(
          c.resources.map((r) => r.id),
          containsAll([
            'openstax-college-algebra',
            'modern-states-college-algebra',
          ]),
        );
        final m = c.maps.singleWhere(
          (m) => m.resourceId == 'openstax-college-algebra',
        );
        expect(m.approved, isTrue);
        expect(m.coverage.length, 20);
        final openstax = c.resources.singleWhere(
          (r) => r.id == 'openstax-college-algebra',
        );
        expect(openstax.approved, isTrue);
        expect(openstax.reviewerKind, 'ai');
        expect(
          openstax.url,
          startsWith('https://openstax.org/books/college-algebra/pages/'),
          reason: 'the 1st edition the map was checked against, not the 2e',
        );
        expect(
          c.resources
              .singleWhere((r) => r.id == 'modern-states-college-algebra')
              .approved,
          isFalse,
        );
      },
    );
  });

  group('card', () {
    final catalog = catalogOf(
      [record('free'), record('pricey', access: 'paid', band: '25_to_100')],
      [
        map('free', {
          '1.1': [section('1.2 Powers')],
          '1.2': [section('1.3 Roots'), section('1.2 Powers')],
          '2.1': [],
        }),
        map('pricey', {
          '1.1': [section('A')],
          '1.2': [section('B')],
          '2.1': [section('C')],
        }),
      ],
    );

    Future<void> pump(
      WidgetTester tester, {
      bool enabled = true,
      double width = 900,
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resourceRecommendationsEnabledProvider.overrideWithValue(enabled),
            resourceCatalogProvider.overrideWith((ref) async => catalog),
            learnerResourcesEnabledProvider.overrideWithValue(true),
            learnerResourcesUseAccountProvider.overrideWithValue(false),
            learnerResourceStoreProvider.overrideWithValue(
              LocalLearnerResourceStore(),
            ),
            targetCurriculumNodesProvider.overrideWith(
              (ref, id) async => nodes,
            ),
            objectiveReadinessProvider.overrideWith((ref, id) async => null),
            targetCoverageProvider.overrideWith(
              (ref, slug) async => CoverageSummary([]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: WaysToStudyCard(goal: goal)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('with the switch off it takes no space', (tester) async {
      await pump(tester, enabled: false);
      expect(find.byKey(const Key('ways_to_study_card')), findsNothing);
    });

    testWidgets(
      'shows the best free route first, with reasons, dates and no affiliation',
      (tester) async {
        await pump(tester);
        expect(find.byKey(const Key('way_best_free')), findsOneWidget);
        final free = tester.getTopLeft(find.byKey(const Key('way_free'))).dy;
        final paid = tester.getTopLeft(find.byKey(const Key('way_pricey'))).dy;
        expect(free, lessThan(paid));
        expect(
          tester.widget<Text>(find.byKey(const Key('way_reasons_free'))).data,
          'covers about 50% of this goal · Free · no sign-in · has practice for most of what it covers',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('way_checked_free'))).data,
          'Checked 2026-11-26, reviewed by AI. Not affiliated with Pub free.',
        );
        expect(find.text('Open (leaves LearningApp)'), findsNWidgets(2));
      },
    );

    testWidgets(
      '"Use this" adds it with its parts and objectives ticked, nothing studied',
      (tester) async {
        await pump(tester);
        await tester.tap(find.byKey(const Key('way_use_free')));
        await tester.pumpAndSettle();
        final saved = (await LocalLearnerResourceStore().list('t1')).single;
        expect(saved.title, 'Book free (Pub free)');
        expect(saved.url, 'https://example.org/free');
        expect(
          [for (final s in saved.sections) s.title],
          ['1.2 Powers', '1.3 Roots'],
        );
        expect(saved.sections.first.objectiveKeys, {'1.1', '1.2'});
        expect(saved.objectives.keys.toSet(), {'1.1', '1.2'});
        expect(saved.studiedCount, 0);
        expect(
          find.text('Book free (Pub free)'),
          findsOneWidget,
          reason: 'its resource screen opens',
        );
      },
    );

    testWidgets(
      'meets tap-target, label and contrast guidelines at phone width',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, width: 360);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  });
}
