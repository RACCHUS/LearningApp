import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/screens/library/catalog_source.dart';

/// The Library "Source" filter: trusted sources never list private or
/// unreviewed goals, and "My goals" lists only the signed-in user's own.
void main() {
  const me = 'user-me';

  LearningTarget target(
    String id, {
    bool isPublic = true,
    bool isOfficial = false,
    TargetStatus status = TargetStatus.published,
    TargetReviewStatus reviewStatus = TargetReviewStatus.approved,
    String? createdBy,
  }) =>
      LearningTarget(
        id: id,
        title: 'Goal $id',
        slug: id,
        targetType: TargetType.career,
        isPublic: isPublic,
        isOfficial: isOfficial,
        status: status,
        reviewStatus: reviewStatus,
        createdBy: createdBy,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  final all = [
    target('official', isOfficial: true),
    target('catalog'),
    target('reviewed', createdBy: 'someone-else'),
    target('pending', createdBy: 'someone-else', reviewStatus: TargetReviewStatus.pending),
    target('my-draft',
        isPublic: false,
        status: TargetStatus.draft,
        reviewStatus: TargetReviewStatus.pending,
        createdBy: me),
    target('my-reviewed', createdBy: me),
  ];

  List<String> listed(CatalogSource source, {String? userId = me}) =>
      [for (final t in all) if (source.shows(t, userId: userId)) t.id];

  test('trusted lists only approved public goals', () {
    expect(listed(CatalogSource.trusted), ['official', 'catalog', 'reviewed', 'my-reviewed']);
  });

  test('official lists only official goals', () {
    expect(listed(CatalogSource.official), ['official']);
  });

  test('reviewed lists approved community goals, never pending ones', () {
    expect(listed(CatalogSource.reviewed), ['reviewed', 'my-reviewed']);
  });

  test('my goals lists only the user\'s own, including private drafts', () {
    expect(listed(CatalogSource.mine), ['my-draft', 'my-reviewed']);
  });

  test('a guest sees no "my goals" and never a private draft', () {
    expect(listed(CatalogSource.mine, userId: null), isEmpty);
    for (final source in CatalogSource.values) {
      expect(listed(source, userId: null), isNot(contains('my-draft')), reason: source.name);
    }
  });

  test('labels shown in the Source menu', () {
    expect(CatalogSource.values.map((s) => s.label),
        ['Trusted catalog', 'Official', 'Reviewed community', 'My goals']);
  });
}
