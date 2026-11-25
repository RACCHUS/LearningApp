import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';

CurriculumNode node(String id, String title, {String? parent, String? code, double? weight, int order = 0}) =>
    CurriculumNode(
      id: id,
      targetVersionId: 'v',
      parentId: parent,
      nodeType: parent == null ? 'domain' : 'objective',
      title: title,
      code: code,
      weight: weight,
      sortOrder: order,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('normalizeLearnerLink', () {
    test('an empty field is allowed: a resource needs no link', () {
      final r = normalizeLearnerLink('   ');
      expect(r.url, isNull);
      expect(r.error, isNull);
    });

    test('adds https when no scheme is typed', () {
      expect(normalizeLearnerLink('Example.org/course').url, 'https://example.org/course');
    });

    test('refuses http, sign-in details and non-links', () {
      expect(normalizeLearnerLink('http://example.org').error, contains('https://'));
      expect(normalizeLearnerLink('https://me:pw@example.org/x').error, contains('sign-in'));
      expect(normalizeLearnerLink('not a link').error, isNotNull);
      expect(normalizeLearnerLink('https://localhost').error, isNotNull);
    });

    test('removes tracking parameters and keeps the rest', () {
      expect(
        normalizeLearnerLink('https://example.org/watch?v=abc&utm_source=x&si=123&fbclid=9#t=40').url,
        'https://example.org/watch?v=abc#t=40',
      );
      expect(normalizeLearnerLink('https://example.org/a?utm_campaign=x').url, 'https://example.org/a');
    });

    test('refuses a link that is too long', () {
      expect(normalizeLearnerLink('https://example.org/${'a' * 2100}').error, contains('too long'));
    });
  });

  group('ResourceOutline', () {
    final nodes = [
      node('d1', 'Algebra', weight: 75, order: 1),
      node('d2', 'Functions', weight: 25, order: 2),
      node('o1', 'Exponents', parent: 'd1', code: '1.1', order: 1),
      node('o2', 'Radicals', parent: 'd1', code: '1.2', order: 2),
      node('o3', 'Graphs', parent: 'd2', order: 1),
    ];

    test('ticks the smallest nodes, keyed by code or by title without one', () {
      final outline = ResourceOutline.fromNodes(nodes);
      expect(outline.groups.map((g) => g.title), ['Algebra', 'Functions']);
      expect(outline.keys, {'1.1', '1.2', 'Graphs'});
      expect(outline.groups.first.items.first.label, '1.1 Exponents');
    });

    test('coverage uses blueprint weights when every area has one', () {
      final outline = ResourceOutline.fromNodes(nodes);
      expect(outline.usesWeights, isTrue);
      expect(outline.coverageShare({'1.1'}), closeTo(0.375, 1e-9));
      expect(outline.coverageShare({'Graphs'}), closeTo(0.25, 1e-9));
      expect(outline.coverageShare({'1.1', '1.2', 'Graphs', 'unknown'}), closeTo(1.0, 1e-9));
    });

    test('coverage falls back to a plain count without weights', () {
      final outline = ResourceOutline.fromNodes([
        node('d1', 'A', order: 1),
        node('o1', 'X', parent: 'd1', code: '1'),
        node('o2', 'Y', parent: 'd1', code: '2'),
      ]);
      expect(outline.usesWeights, isFalse);
      expect(outline.coverageShare({'1'}), 0.5);
    });

    test('areas that are ticked directly use their own weights', () {
      final outline = ResourceOutline.fromNodes([
        node('d1', 'A', code: 'A', weight: 80, order: 1),
        node('d2', 'B', code: 'B', weight: 20, order: 2),
      ]);
      expect(outline.usesWeights, isTrue);
      expect(outline.coverageShare({'B'}), closeTo(0.2, 1e-9));
    });

    test('an empty goal covers nothing', () {
      expect(const ResourceOutline([]).coverageShare({'1'}), 0);
    });
  });

  test('a resource survives a JSON round trip', () {
    final at = DateTime.utc(2026, 11, 25, 10);
    final r = LearnerResource(
      id: 'r1',
      targetId: 't1',
      title: 'My course',
      kind: LearnerResourceKind.videoSeries,
      url: 'https://example.org',
      access: ExternalAccess.paid,
      objectives: {'1.1': at, '1.2': null},
    );
    final back = LearnerResource.fromJson(r.toJson());
    expect(back.title, 'My course');
    expect(back.kind, LearnerResourceKind.videoSeries);
    expect(back.access, ExternalAccess.paid);
    expect(back.objectives, {'1.1': at, '1.2': null});
    expect(back.studiedCount, 1);
    expect(LearnerResource.fromJson({'id': 1, 'target_id': 2, 'kind': 'nope'}).kind, LearnerResourceKind.other);
  });
}
