import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/governance/migration_history_validator.dart';

void main() {
  group('MigrationHistoryValidator - Local Records Static Invariants', () {
    const validator = MigrationHistoryValidator();

    test('valid records pass cleanly with 0 issues', () {
      final records = [
        const MigrationRecord(
          filename: '20261001000000_first.sql',
          timestamp: '20261001000000',
          name: 'first',
          path: '/path/to/20261001000000_first.sql',
          sizeBytes: 50,
          content: 'select 1;',
        ),
        const MigrationRecord(
          filename: '20261002000000_second.sql',
          timestamp: '20261002000000',
          name: 'second',
          path: '/path/to/20261002000000_second.sql',
          sizeBytes: 60,
          content: 'select 2;',
        ),
      ];

      final issues = validator.validateLocalRecords(records);
      expect(issues, isEmpty);
    });

    test('flags invalid filename formats as errors', () {
      final issues = validator.validateLocalRecords(
        [],
        invalidFilenames: ['bad_migration_name.sql', '2026_bad.sql'],
      );

      expect(issues.length, equals(2));
      expect(issues.every((i) => i.isError), isTrue);
      expect(issues[0].rule, equals('invalid_filename_format'));
      expect(issues[0].filename, equals('bad_migration_name.sql'));
    });

    test('flags empty migration files as errors', () {
      final records = [
        const MigrationRecord(
          filename: '20261001000000_empty.sql',
          timestamp: '20261001000000',
          name: 'empty',
          path: '/path/to/20261001000000_empty.sql',
          sizeBytes: 0,
          content: '   \n  \t  \n',
        ),
      ];

      final issues = validator.validateLocalRecords(records);
      expect(issues.length, equals(1));
      expect(issues.first.rule, equals('empty_migration_file'));
      expect(issues.first.isError, isTrue);
    });

    test('flags timestamp collisions (duplicate timestamps) as errors', () {
      final records = [
        const MigrationRecord(
          filename: '20261001000000_alpha.sql',
          timestamp: '20261001000000',
          name: 'alpha',
          path: '/path/to/20261001000000_alpha.sql',
          sizeBytes: 10,
          content: 'select 1;',
        ),
        const MigrationRecord(
          filename: '20261001000000_beta.sql',
          timestamp: '20261001000000',
          name: 'beta',
          path: '/path/to/20261001000000_beta.sql',
          sizeBytes: 10,
          content: 'select 2;',
        ),
      ];

      final issues = validator.validateLocalRecords(records);
      expect(issues.length, equals(1));
      expect(issues.first.rule, equals('duplicate_timestamp'));
      expect(issues.first.isError, isTrue);
      expect(issues.first.message, contains('Timestamp collision'));
    });

    test('flags out-of-order / non-monotonic timestamps as errors', () {
      final records = [
        const MigrationRecord(
          filename: '20261002000000_later.sql',
          timestamp: '20261002000000',
          name: 'later',
          path: '/path/to/20261002000000_later.sql',
          sizeBytes: 10,
          content: 'select 1;',
        ),
        const MigrationRecord(
          filename: '20261001000000_earlier.sql',
          timestamp: '20261001000000',
          name: 'earlier',
          path: '/path/to/20261001000000_earlier.sql',
          sizeBytes: 10,
          content: 'select 2;',
        ),
      ];

      final issues = validator.validateLocalRecords(records);
      expect(issues.length, equals(1));
      expect(issues.first.rule, equals('out_of_order_timestamp'));
      expect(issues.first.isError, isTrue);
      expect(issues.first.message, contains('earlier than previous migration'));
    });
  });

  group('MigrationHistoryValidator - Baseline Comparison & Immutability', () {
    const validator = MigrationHistoryValidator();

    test('identical baseline and current files pass with zero issues', () {
      final baseline = {
        '20261001000000_init.sql': 'create table t1 (id int);',
        '20261002000000_update.sql': 'alter table t1 add col text;',
      };
      final current = Map<String, String>.from(baseline);

      final issues = validator.compareWithBaseline(
        baselineFiles: baseline,
        currentFiles: current,
      );
      expect(issues, isEmpty);
    });

    test('normalizes line endings and whitespace to prevent false positives', () {
      final baseline = {
        '20261001000000_init.sql': 'create table t1 (id int);\n',
      };
      final current = {
        '20261001000000_init.sql': 'create table t1 (id int);\r\n\r\n',
      };

      final issues = validator.compareWithBaseline(
        baselineFiles: baseline,
        currentFiles: current,
      );
      expect(issues, isEmpty);
    });

    test('detects and flags in-place modifications to baseline migrations (PR #11 regression scenario)', () {
      final baseline = {
        '20261001000000_init.sql': 'create table t1 (id int);',
        '20261009000003_control_auth.sql': 'create or replace function auth_v1() returns void as \$\$ begin null; end; \$\$ language plpgsql;',
      };
      // In-place modification of 00003:
      final current = {
        '20261001000000_init.sql': 'create table t1 (id int);',
        '20261009000003_control_auth.sql': 'create or replace function auth_v1() returns void as \$\$ begin perform 1; end; \$\$ language plpgsql;',
      };

      final issues = validator.compareWithBaseline(
        baselineFiles: baseline,
        currentFiles: current,
      );

      expect(issues.length, equals(1));
      expect(issues.first.rule, equals('modified_baseline_migration'));
      expect(issues.first.filename, equals('20261009000003_control_auth.sql'));
      expect(issues.first.isError, isTrue);
      expect(issues.first.message, contains('modified in-place'));
    });

    test('detects and flags deletion of baseline migrations', () {
      final baseline = {
        '20261001000000_init.sql': 'create table t1 (id int);',
        '20261002000000_update.sql': 'alter table t1 add col text;',
      };
      // 000002 deleted:
      final current = {
        '20261001000000_init.sql': 'create table t1 (id int);',
      };

      final issues = validator.compareWithBaseline(
        baselineFiles: baseline,
        currentFiles: current,
      );

      expect(issues.length, equals(1));
      expect(issues.first.rule, equals('deleted_baseline_migration'));
      expect(issues.first.filename, equals('20261002000000_update.sql'));
      expect(issues.first.isError, isTrue);
      expect(issues.first.message, contains('was deleted'));
    });

    test('allows valid newly appended migrations with newer timestamps (PR #12 pattern)', () {
      final baseline = {
        '20261001000000_init.sql': 'create table t1 (id int);',
        '20261009000003_control_auth.sql': 'create function f() returns void as \$\$ begin null; end; \$\$ language plpgsql;',
      };
      // Strictly append-only 00004:
      final current = {
        '20261001000000_init.sql': 'create table t1 (id int);',
        '20261009000003_control_auth.sql': 'create function f() returns void as \$\$ begin null; end; \$\$ language plpgsql;',
        '20261009000004_restore_contracts.sql': 'create or replace function f() returns void as \$\$ begin perform 1; end; \$\$ language plpgsql;',
      };

      final issues = validator.compareWithBaseline(
        baselineFiles: baseline,
        currentFiles: current,
      );

      expect(issues, isEmpty);

      final pending = validator.findPendingMigrations(
        baselineFilenames: baseline.keys.toSet(),
        currentFilenames: current.keys,
      );
      expect(pending, equals(['20261009000004_restore_contracts.sql']));
    });

    test('flags newly added migrations with backdated timestamps', () {
      final baseline = {
        '20261009000003_control_auth.sql': 'create table t1 (id int);',
      };
      // New file but timestamp is older than baseline's 20261009000003:
      final current = {
        '20261009000003_control_auth.sql': 'create table t1 (id int);',
        '20261005000000_backdated.sql': 'create table t2 (id int);',
      };

      final issues = validator.compareWithBaseline(
        baselineFiles: baseline,
        currentFiles: current,
      );

      expect(issues.length, equals(1));
      expect(issues.first.rule, equals('backdated_new_migration'));
      expect(issues.first.filename, equals('20261005000000_backdated.sql'));
      expect(issues.first.isError, isTrue);
      expect(issues.first.message, contains('which is <= latest baseline migration'));
    });
  });
}
