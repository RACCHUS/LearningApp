import 'package:flutter_test/flutter_test.dart';
import '../../tool/verify_published_pathways.dart';

void main() {
  final baseTime = DateTime.utc(2026, 10, 16, 12, 0, 0);

  Map<String, dynamic> makeRow({
    required String ns,
    required String key,
    int rev = 1,
    String title = 'Valid Pathway Title With Requirements',
    String status = 'published',
    String review = 'approved',
    String coverage = 'selected_steps_only',
    String routeKind = 'examination',
    String sourceUrl = 'https://floridasnursing.gov/nurse-rn-lpn/',
    String? sourceCheckedAt,
  }) {
    return {
      'source_namespace': ns,
      'source_key': key,
      'revision': rev,
      'title': title,
      'publication_status': status,
      'review_status': review,
      'coverage': coverage,
      'route_kind': routeKind,
      'source_url': sourceUrl,
      'source_checked_at': sourceCheckedAt ?? '2026-10-13T12:00:00Z',
    };
  }

  List<Map<String, dynamic>> makeValidSet() {
    return [
      makeRow(ns: 'fl_bon', key: 'registered-nurse'),
      makeRow(ns: 'fl_bon', key: 'licensed-practical-nurse'),
      makeRow(
        ns: 'fl_dfs',
        key: 'general-lines-2-20',
        sourceUrl:
            'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications',
      ),
      makeRow(
        ns: 'fl_dfs',
        key: 'life-health-2-15',
        sourceUrl:
            'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications',
      ),
      makeRow(
        ns: 'dbpr_fl',
        key: 'certified-general-contractor',
        sourceUrl:
            'https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0605',
      ),
      makeRow(
        ns: 'dbpr_fl',
        key: 'certified-building-contractor',
        sourceUrl:
            'https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0602',
      ),
    ];
  }

  group('PathwayVerificationResult Tests', () {
    test('valid 6-pathway baseline succeeds with 0 errors and 0 warnings', () {
      final rows = makeValidSet();
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.verifiedCount, equals(6));
      expect(result.verifiedIdentities, equals(kExpectedPublishedPathways));
    });

    test('missing pathway identity fails closed with error', () {
      final rows = makeValidSet()..removeLast(); // 5 rows
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('Missing 1 expected pathway(s)')), isTrue);
      expect(result.errors.any((e) => e.contains('dbpr_fl:certified-building-contractor')), isTrue);
    });

    test('unexpected pathway identity fails closed with error', () {
      final rows = makeValidSet()
        ..add(makeRow(ns: 'other_state', key: 'unauthorized-license'));
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('Unexpected pathway identity returned: other_state:unauthorized-license')), isTrue);
    });

    test('duplicate pathway row fails closed with error', () {
      final valid = makeValidSet();
      final rows = [...valid, valid.first]; // 7 rows with duplicate
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('Duplicate pathway row encountered')), isTrue);
    });

    test('non-published status fails closed with error', () {
      final rows = makeValidSet();
      rows[0]['publication_status'] = 'draft';
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('has publication_status "draft"')), isTrue);
    });

    test('non-approved review status fails closed with error', () {
      final rows = makeValidSet();
      rows[1]['review_status'] = 'pending';
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('has review_status "pending"')), isTrue);
    });

    test('coverage mismatch fails closed with error', () {
      final rows = makeValidSet();
      rows[2]['coverage'] = 'complete_eligibility';
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('has coverage "complete_eligibility"')), isTrue);
    });

    test('revision mismatch fails closed with error', () {
      final rows = makeValidSet();
      rows[3]['revision'] = 2;
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('has revision 2')), isTrue);
    });

    test('non-HTTPS source_url fails closed with error', () {
      final rows = makeValidSet();
      rows[4]['source_url'] = 'http://insecure-source.com';
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('non-HTTPS source_url')), isTrue);
    });

    test('expired source check (> 180 days) fails closed with error', () {
      final rows = makeValidSet();
      // Checked 185 days before baseTime
      final expiredDate = baseTime.subtract(const Duration(days: 185)).toIso8601String();
      rows[0]['source_checked_at'] = expiredDate;
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isFalse);
      expect(result.errors.any((e) => e.contains('source review is EXPIRED (185 days old > 180 days limit)')), isTrue);
    });

    test('source check approaching expiration (150-180 days) emits warning but passes', () {
      final rows = makeValidSet();
      // Checked 160 days before baseTime
      final warningDate = baseTime.subtract(const Duration(days: 160)).toIso8601String();
      rows[0]['source_checked_at'] = warningDate;
      final result = verifyPathwayRecords(rows, now: baseTime);

      expect(result.isSuccess, isTrue); // still succeeds
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first, contains('source review is 160 days old (20 days remaining before 180-day RLS expiration)'));
    });
  });
}
