import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/taxonomy/taxonomy.dart';
import 'package:learning_pwa/providers/taxonomy_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/widgets/targets/create_target_dialog.dart';

void main() {
  LearningTarget example({
    required String id,
    required String title,
    required bool official,
    String? provider,
    String? description,
  }) {
    return LearningTarget(
      id: id,
      title: title,
      slug: id,
      targetType: TargetType.career,
      isOfficial: official,
      isPublic: true,
      status: TargetStatus.published,
      reviewStatus: TargetReviewStatus.approved,
      createdBy: official ? null : 'community-creator',
      providerName: provider,
      description: description,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }

  test('catalog provenance distinguishes reviewed from user drafts', () {
    final official = example(id: 'one', title: 'Official A', official: true);
    final community = example(id: 'two', title: 'Reviewed B', official: false);
    final draft = LearningTarget(
      id: 'three',
      title: 'Custom C',
      slug: 'three',
      targetType: TargetType.career,
      isPublic: false,
      createdBy: 'owner',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    expect(official.sourceLabel, 'Official');
    expect(community.sourceLabel, 'Community · reviewed');
    expect(draft.sourceLabel, 'My draft');
    expect(official.isTrustedPublic, isTrue);
    expect(community.isTrustedPublic, isTrue);
    expect(draft.isTrustedPublic, isFalse);
  });

  testWidgets('SOC reference fills a custom career without claiming official status',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        targetSuggestionsProvider(TargetType.career)
            .overrideWith((ref) async => []),
        taxonomySearchProvider('engineer').overrideWith((ref) async => [
          const TaxonomySearchMatch(
            id: 'soc-1',
            code: '15-1252',
            title: 'Software Developers',
            description: 'Research and design software.',
            kind: TaxonomyItemKind.occupation,
            level: 'detailed_occupation',
            system: 'bls_soc',
          ),
        ]),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CreateTargetDialog()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goal-title')), 'engineer');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final source = find.byKey(const Key('goal-taxonomy-suggestion-15-1252'));
    expect(source, findsOneWidget);
    await tester.ensureVisible(source);
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('goal-title')))
          .controller!.text,
      'Software Developers',
    );
    expect(find.byKey(const Key('goal-open-existing')), findsNothing);
    expect(find.textContaining('private, editable draft'), findsOneWidget);
  });

  testWidgets('database examples suggest all editable text fields',
      (tester) async {
    final data = [
      example(
        id: 'software',
        title: 'Software Engineer',
        official: true,
        provider: 'US Department of Labor',
        description: 'Build and maintain software applications.',
      ),
      example(
        id: 'data',
        title: 'Data Engineer',
        official: false,
        provider: 'Community Learning Group',
        description: 'Design data platforms and pipelines.',
      ),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        targetSuggestionsProvider(TargetType.career)
            .overrideWith((ref) async => data),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CreateTargetDialog()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal-type')), findsOneWidget);
    expect(find.byKey(const Key('goal-title-suggestion-software')),
        findsOneWidget);
    expect(find.byKey(const Key('goal-title-suggestion-data')),
        findsOneWidget);
    expect(find.text('Official'), findsOneWidget);
    expect(find.text('Community · reviewed'), findsOneWidget);

    await tester.ensureVisible(
        find.byKey(const Key('goal-title-suggestion-software')));
    await tester.tap(find.byKey(const Key('goal-title-suggestion-software')));
    await tester.pumpAndSettle();

    expect(
        tester.widget<TextFormField>(find.byKey(const Key('goal-title')))
            .controller!.text,
        'Software Engineer');
    expect(
        tester.widget<TextFormField>(find.byKey(const Key('goal-provider')))
            .controller!.text,
        'US Department of Labor');
    expect(
        tester.widget<TextFormField>(find.byKey(const Key('goal-description')))
            .controller!.text,
        'Build and maintain software applications.');
    expect(find.byKey(const Key('goal-open-existing')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('goal-title')), 'My Own Career Idea');
    await tester.pump();
    expect(
        tester.widget<TextFormField>(find.byKey(const Key('goal-title')))
            .controller!.text,
        'My Own Career Idea');
    expect(find.byKey(const Key('goal-open-existing')), findsNothing);
    expect(find.textContaining('private, editable draft'), findsOneWidget);
  });
}
