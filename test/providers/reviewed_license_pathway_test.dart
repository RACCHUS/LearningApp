import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/verified_destinations_provider.dart';

void main() {
  final checked = {
    'title': 'Florida RN selected requirements',
    'overview': 'Board reviewed selected requirements only.',
    'coverage': 'selected_steps_only',
    'revision': 1,
    'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
    'source_checked_at': '2026-10-12T12:00:00Z',
    'review_status': 'approved',
    'publication_status': 'published',
    'pathway_tree': {
      'op': 'any',
      'children': [
        {
          'op': 'step',
          'label': 'Approved nursing program',
          'stage': 'education',
          'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
        },
        {
          'op': 'step',
          'label': 'Equivalent program',
          'stage': 'education',
          'condition': 'Requires board confirmation',
          'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
        },
      ],
    },
  };

  test('reviewed pathway preserves alternative branch and version', () {
    final value = ReviewedLicensePathway.fromJson(checked);
    expect(value.coverage, 'selected_steps_only');
    expect(value.revision, 1);
    expect(value.pathwayTree['op'], 'any');
    expect((value.pathwayTree['children'] as List).length, 2);
  });

  test('rejects unreviewed or purported complete eligibility', () {
    expect(
      () => ReviewedLicensePathway.fromJson({...checked, 'review_status': 'pending'}),
      throwsFormatException,
    );
    expect(
      () => ReviewedLicensePathway.fromJson({...checked, 'coverage': 'all_requirements'}),
      throwsFormatException,
    );
  });

  test('rejects untrusted regulator URL', () {
    expect(
      () => ReviewedLicensePathway.fromJson({
        ...checked,
        'source_url': 'http://unverified.example/board',
      }),
      throwsFormatException,
    );
  });
}
