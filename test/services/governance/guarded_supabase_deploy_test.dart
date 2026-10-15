import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuardedSupabaseDeploy - Safety Invariants and Failure Recovery', () {
    late Directory tempDir;
    late Directory tempReportDir;
    late File tempProjectRef;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('guarded_deploy_test_');
      tempReportDir = Directory('${tempDir.path}/reports')..createSync(recursive: true);
      final supabaseTempDir = Directory('${tempDir.path}/supabase/.temp')..createSync(recursive: true);
      tempProjectRef = File('${supabaseTempDir.path}/project-ref');
      tempProjectRef.writeAsStringSync('xzvkdwebtbxlrxagtzlv\n');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('rejects deployment when project ref does not match expected target', () {
      final result = Process.runSync(
        'dart',
        [
          'run',
          'tool/guarded_supabase_deploy.dart',
          '--project-ref',
          'wrong_project_id_12345',
          '--report-dir',
          tempReportDir.path,
        ],
        runInShell: true,
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr.toString(), contains('Target Supabase project mismatch'));
      expect(result.stderr.toString(), contains('wrong_project_id_12345'));

      final summaryFile = File('${tempReportDir.path}/deployment_summary.json');
      expect(summaryFile.existsSync(), isTrue);
      final summary = jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
      expect(summary['status'], equals('failed'));
      expect(summary['phase'], equals('project_identity_check'));
      expect(summary['error'], contains('Project ref mismatch'));
    });

    test('rejects deployment when active lockfile exists and blocks concurrent deployment', () {
      final lockFile = File('supabase/.deployment.lock');
      // Create active lock
      final activeLockData = {
        'pid': 999999,
        'user': 'other_agent',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'project_ref': 'xzvkdwebtbxlrxagtzlv',
        'host': 'test_runner',
      };
      lockFile.writeAsStringSync(jsonEncode(activeLockData));

      try {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/guarded_supabase_deploy.dart',
            '--allow-dirty',
            '--report-dir',
            tempReportDir.path,
          ],
          runInShell: true,
        );

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('Concurrent deployment blocked'));
        expect(result.stderr.toString(), contains('999999'));

        final summaryFile = File('${tempReportDir.path}/deployment_summary.json');
        expect(summaryFile.existsSync(), isTrue);
        final summary = jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
        expect(summary['status'], equals('failed'));
        expect(summary['phase'], equals('deployment_serialization'));
      } finally {
        if (lockFile.existsSync()) {
          lockFile.deleteSync();
        }
      }
    });

    test('force-unlock clears active lockfile and allows deployment preflight to proceed', () {
      final lockFile = File('supabase/.deployment.lock');
      final activeLockData = {
        'pid': 999999,
        'user': 'other_agent',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'project_ref': 'xzvkdwebtbxlrxagtzlv',
        'host': 'test_runner',
      };
      lockFile.writeAsStringSync(jsonEncode(activeLockData));

      try {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/guarded_supabase_deploy.dart',
            '--force-unlock',
            '--dry-run',
            '--allow-dirty',
            '--report-dir',
            tempReportDir.path,
          ],
          runInShell: true,
        );

        expect(result.stdout.toString(), contains('Force-unlock active'));
        // Result code 0 means force unlock succeeded and proceeded through preflight
        expect(result.exitCode, equals(0));
      } finally {
        if (lockFile.existsSync()) {
          lockFile.deleteSync();
        }
      }
    });

    test('rejects deployment when uncommitted migration file exists even if --allow-dirty is passed', () {
      final fakeMigration = File('supabase/migrations/20990101000000_uncommitted_test.sql');
      fakeMigration.writeAsStringSync('-- uncommitted migration test');

      try {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/guarded_supabase_deploy.dart',
            '--allow-dirty',
            '--report-dir',
            tempReportDir.path,
          ],
          runInShell: true,
        );

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('Working tree has uncommitted changes in supabase/migrations'));
        expect(result.stderr.toString(), contains('The --allow-dirty flag NEVER permits uncommitted migration files'));

        final summaryFile = File('${tempReportDir.path}/deployment_summary.json');
        expect(summaryFile.existsSync(), isTrue);
        final summary = jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
        expect(summary['status'], equals('failed'));
        expect(summary['phase'], equals('git_migration_cleanliness'));
      } finally {
        if (fakeMigration.existsSync()) {
          fakeMigration.deleteSync();
        }
      }
    });
  });
}
