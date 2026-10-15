import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/canonical_field.dart';
import 'package:learning_pwa/providers/taxonomy_provider.dart';
import 'package:learning_pwa/services/taxonomy/taxonomy_crosswalk_service.dart';
import 'package:learning_pwa/widgets/taxonomy/field_hierarchy_tile.dart';

class _FakeTaxonomyService extends TaxonomyCrosswalkService {
  _FakeTaxonomyService(this.children) : super(supabaseClient: null);

  final Map<String, FieldChildrenPage> children;
  final List<String> requested = [];
  int failuresRemaining = 0;

  @override
  Future<FieldChildrenPage> getChildFields(String parentId) async {
    requested.add(parentId);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('network down');
    }
    return children[parentId] ?? const FieldChildrenPage(fields: []);
  }
}

const _broad = CanonicalField(
  id: 'broad-11',
  name: 'Computer and Information Sciences',
  slug: 'computer-sciences',
  fieldKind: 'broad_field',
);
const _subfield = CanonicalField(
  id: 'sub-11-07',
  parentId: 'broad-11',
  name: 'Computer Science (group)',
  slug: 'computer-science-cip-11-07',
  fieldKind: 'subfield',
);
const _program = CanonicalField(
  id: 'prog-11-0701',
  parentId: 'sub-11-07',
  name: 'Computer Science (program)',
  slug: 'computer-science-cip-11-0701',
  fieldKind: 'program_classification',
);
const _nativeRoot = CanonicalField(
  id: 'native-foundational-literacy',
  name: 'Foundational Literacy',
  slug: 'foundational-literacy',
  fieldKind: 'native_field',
);
const _nativeChild = CanonicalField(
  id: 'native-phonics',
  parentId: 'native-foundational-literacy',
  name: 'Phonics and Word Decoding',
  slug: 'phonics-and-word-decoding',
  fieldKind: 'native_field',
);

Future<void> _pump(WidgetTester tester, _FakeTaxonomyService service) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [taxonomyServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FieldHierarchyTile(field: _broad)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('drills broad -> subfield -> program, loading each level lazily',
      (tester) async {
    final service = _FakeTaxonomyService({
      'broad-11': const FieldChildrenPage(fields: [_subfield]),
      'sub-11-07': const FieldChildrenPage(fields: [_program]),
    });
    await _pump(tester, service);
    await tester.pumpAndSettle();

    expect(find.text('Broad field'), findsOneWidget);
    expect(service.requested, isEmpty,
        reason: 'children must not load until the field is expanded');

    await tester.tap(find.text(_broad.name));
    await tester.pumpAndSettle();
    expect(service.requested, ['broad-11']);
    expect(find.text(_subfield.name), findsOneWidget);
    expect(find.text('Subfield'), findsOneWidget);
    expect(find.text(_program.name), findsNothing);

    await tester.tap(find.text(_subfield.name));
    await tester.pumpAndSettle();
    expect(service.requested, ['broad-11', 'sub-11-07']);
    expect(find.text(_program.name), findsOneWidget);
    expect(find.text('Program field'), findsOneWidget);

    // Program fields are leaves: no further fetch or expansion.
    await tester.tap(find.text(_program.name));
    await tester.pumpAndSettle();
    expect(service.requested, ['broad-11', 'sub-11-07']);
    expect(find.byKey(const ValueKey('field-tile-prog-11-0701')), findsOneWidget);
  });

  testWidgets('native learning areas use the same lazy hierarchy browser',
      (tester) async {
    final service = _FakeTaxonomyService({
      _nativeRoot.id: const FieldChildrenPage(fields: [_nativeChild]),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taxonomyServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FieldHierarchyTile(field: _nativeRoot),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning area'), findsOneWidget);
    expect(find.text(_nativeChild.name), findsNothing);
    await tester.tap(find.text(_nativeRoot.name));
    await tester.pumpAndSettle();

    expect(service.requested, [_nativeRoot.id]);
    expect(find.text(_nativeChild.name), findsOneWidget);
    expect(find.text('Learning area'), findsNWidgets(2));
  });

  testWidgets('tells the learner when a level is truncated', (tester) async {
    final service = _FakeTaxonomyService({
      'broad-11': const FieldChildrenPage(fields: [_subfield], hasMore: true),
    });
    await _pump(tester, service);
    await tester.tap(find.text(_broad.name));
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing the first 1 narrower fields'),
        findsOneWidget);
  });

  testWidgets('shows a retryable error instead of an empty list',
      (tester) async {
    final service = _FakeTaxonomyService({
      'broad-11': const FieldChildrenPage(fields: [_subfield]),
    })..failuresRemaining = 1;
    await _pump(tester, service);
    await tester.tap(find.text(_broad.name));
    await tester.pumpAndSettle();

    expect(find.text('Could not load narrower fields.'), findsOneWidget);
    expect(find.text(_subfield.name), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_subfield.name), findsOneWidget);
  });

  testWidgets('explains an empty level', (tester) async {
    await _pump(tester, _FakeTaxonomyService({}));
    await tester.tap(find.text(_broad.name));
    await tester.pumpAndSettle();

    expect(find.text('No narrower fields yet.'), findsOneWidget);
  });
}
