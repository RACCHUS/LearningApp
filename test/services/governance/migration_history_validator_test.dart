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

  group('MigrationHistoryValidator - Hosted Version Parsing & Pre/Postflight Gates', () {
    const validator = MigrationHistoryValidator();

    MigrationRecord makeRecord(String filename, String content) {
      return MigrationRecord.parse(
        filename: filename,
        path: '/dummy/$filename',
        content: content,
      )!;
    }

    test('parseMigrationListOutput successfully parses local and remote versions', () {
      const cliOutput = '''
Initialising login role...
Connecting to remote database...

   Local          | Remote         | Time (UTC)          
  ----------------|----------------|---------------------
   20261001000000 | 20261001000000 | 2026-10-01 00:00:00 
   20261002000000 | 20261002000000 | 2026-10-02 00:00:00 
   20261003000000 |                | 
                  | 20261004000000 | 2026-10-04 00:00:00 
''';

      final parsed = MigrationHistoryValidator.parseMigrationListOutput(cliOutput);
      expect(parsed['local'], equals(['20261001000000', '20261002000000', '20261003000000']));
      expect(parsed['remote'], equals(['20261001000000', '20261002000000', '20261004000000']));
    });

    test('parseMigrationListOutput throws FormatException on connection/fatal errors', () {
      const errOutput = 'Error: connection refused to db.xzvkdwebtbxlrxagtzlv.supabase.co:5432';
      expect(
        () => MigrationHistoryValidator.parseMigrationListOutput(errOutput),
        throwsA(isA<FormatException>()),
      );
    });

    test('parseMigrationListOutput throws FormatException when header is missing', () {
      const missingHeader = 'Random unexpected text without table';
      expect(
        () => MigrationHistoryValidator.parseMigrationListOutput(missingHeader),
        throwsA(isA<FormatException>()),
      );
    });

    test('compareWithHosted passes with exact parity when remote and local match', () {
      final records = [
        makeRecord('20261001000000_alpha.sql', 'select 1;'),
        makeRecord('20261002000000_beta.sql', 'select 2;'),
      ];
      final remote = ['20261001000000', '20261002000000'];

      final result = validator.compareWithHosted(
        localRecords: records,
        remoteVersions: remote,
      );

      expect(result.isValid, isTrue);
      expect(result.isExactParity, isTrue);
      expect(result.hasPending, isFalse);
      expect(result.appliedVersions, equals(remote));
      expect(result.pendingVersions, isEmpty);
      expect(result.issues, isEmpty);
    });

    test('compareWithHosted detects valid pending migrations strictly newer than remote', () {
      final records = [
        makeRecord('20261001000000_alpha.sql', 'select 1;'),
        makeRecord('20261002000000_beta.sql', 'select 2;'),
        makeRecord('20261003000000_gamma.sql', 'select 3;'),
      ];
      // Remote only has first two:
      final remote = ['20261001000000', '20261002000000'];

      final result = validator.compareWithHosted(
        localRecords: records,
        remoteVersions: remote,
      );

      expect(result.isValid, isTrue);
      expect(result.isExactParity, isFalse);
      expect(result.hasPending, isTrue);
      expect(result.pendingVersions, equals(['20261003000000']));
      expect(result.appliedVersions, equals(['20261001000000', '20261002000000']));
      expect(result.issues, isEmpty);
    });

    test('compareWithHosted flags remote-only versions (unknown aliases / Oct 12 defect scenario)', () {
      final records = [
        makeRecord('20261012000000_intake.sql', 'select 1;'),
      ];
      // Remote has timestamp alias 20261012024727 instead of canonical 20261012000000:
      final remote = ['20261012024727'];

      final result = validator.compareWithHosted(
        localRecords: records,
        remoteVersions: remote,
      );

      expect(result.isValid, isFalse);
      expect(result.remoteOnlyVersions, equals(['20261012024727']));
      expect(result.missingRemoteVersions, equals(['20261012000000']));
      expect(result.issues.any((i) => i.rule == 'remote_only_migration_version'), isTrue);
      expect(result.issues.any((i) => i.rule == 'missing_remote_historical_migration'), isTrue);
    });

    test('compareWithHosted flags missing historical local migration', () {
      final records = [
        makeRecord('20261001000000_first.sql', 'select 1;'),
        makeRecord('20261002000000_second.sql', 'select 2;'),
        makeRecord('20261003000000_third.sql', 'select 3;'),
      ];
      // Remote has 001 and 003, but missed 002:
      final remote = ['20261001000000', '20261003000000'];

      final result = validator.compareWithHosted(
        localRecords: records,
        remoteVersions: remote,
      );

      expect(result.isValid, isFalse);
      expect(result.missingRemoteVersions, equals(['20261002000000']));
      expect(result.issues.first.rule, equals('missing_remote_historical_migration'));
    });

    test('compareWithHosted flags duplicate or out-of-order remote versions', () {
      final records = [
        makeRecord('20261001000000_first.sql', 'select 1;'),
        makeRecord('20261002000000_second.sql', 'select 2;'),
      ];
      // Remote has duplicate:
      final resultDup = validator.compareWithHosted(
        localRecords: records,
        remoteVersions: ['20261001000000', '20261001000000'],
      );
      expect(resultDup.issues.any((i) => i.rule == 'duplicate_remote_version'), isTrue);

      // Remote out of order:
      final resultOrder = validator.compareWithHosted(
        localRecords: records,
        remoteVersions: ['20261002000000', '20261001000000'],
      );
      expect(resultOrder.issues.any((i) => i.rule == 'out_of_order_remote_version'), isTrue);
    });

    test('compareHostedPostflight passes on exact 1:1 parity', () {
      final records = [
        makeRecord('20261001000000_first.sql', 'select 1;'),
        makeRecord('20261002000000_second.sql', 'select 2;'),
      ];
      final remote = ['20261001000000', '20261002000000'];

      final postflight = validator.compareHostedPostflight(
        localRecords: records,
        remoteVersions: remote,
      );

      expect(postflight.isValid, isTrue);
      expect(postflight.isExactParity, isTrue);
      expect(postflight.issues, isEmpty);
    });

    test('compareHostedPostflight flags partial deployment when pending migrations remain', () {
      final records = [
        makeRecord('20261001000000_first.sql', 'select 1;'),
        makeRecord('20261002000000_second.sql', 'select 2;'),
        makeRecord('20261003000000_third.sql', 'select 3;'),
      ];
      // Deployed only up to second; third is unapplied:
      final remote = ['20261001000000', '20261002000000'];

      final postflight = validator.compareHostedPostflight(
        localRecords: records,
        remoteVersions: remote,
      );

      expect(postflight.isValid, isFalse);
      expect(postflight.issues.any((i) => i.rule == 'partial_deployment_unapplied_migration'), isTrue);
      expect(postflight.issues.first.message, contains('Deployment was only partially applied'));
    });
  });
}

