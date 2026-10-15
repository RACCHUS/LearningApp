import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/governance/guarded_deployment_manager.dart';

void main() {
  group('GuardedDeploymentManager - Hermetic Invariants and Failure Recovery', () {
    late Directory tempDir;
    late Directory tempReportDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('guarded_manager_test_');
      tempReportDir = Directory('${tempDir.path}/reports')..createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('verifyProjectRef enforces exact project identity', () {
      final manager = GuardedDeploymentManager(workingDirectory: tempDir);

      // 1. Missing file throws StateError
      expect(
        () => manager.verifyProjectRef('xzvkdwebtbxlrxagtzlv'),
        throwsStateError,
      );

      // 2. Mismatched project ref throws StateError
      final tempProjectRefFile = File('${tempDir.path}/supabase/.temp/project-ref');
      tempProjectRefFile.createSync(recursive: true);
      tempProjectRefFile.writeAsStringSync('other_project_999\n');

      expect(
        () => manager.verifyProjectRef('xzvkdwebtbxlrxagtzlv'),
        throwsStateError,
      );

      // 3. Matching project ref passes cleanly
      tempProjectRefFile.writeAsStringSync('xzvkdwebtbxlrxagtzlv\n');
      expect(
        () => manager.verifyProjectRef('xzvkdwebtbxlrxagtzlv'),
        returnsNormally,
      );
    });

    test('atomic lock acquisition prevents simultaneous concurrent deployment', () {
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          // Mock alive process check
          return ProcessResult(0, 0, 'dummy_process.exe 12345 Console 1 10,000 K', '');
        },
      );

      // First acquisition succeeds atomically
      final lockFile = manager.acquireDeploymentLock(
        projectRef: 'xzvkdwebtbxlrxagtzlv',
        customPid: 12345,
      );
      expect(lockFile.existsSync(), isTrue);

      // Second acquisition while PID 12345 is alive throws StateError
      expect(
        () => manager.acquireDeploymentLock(
          projectRef: 'xzvkdwebtbxlrxagtzlv',
          customPid: 54321,
        ),
        throwsStateError,
      );

      // Release lock removes the file
      manager.releaseDeploymentLock();
      expect(lockFile.existsSync(), isFalse);
    });

    test('dead lockfile is automatically recovered if previous process crashed', () {
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          // Mock dead process check (tasklist returning no tasks / kill returning error)
          return ProcessResult(0, 1, 'INFO: No tasks are running which match the specified criteria.', '');
        },
      );

      // Create an existing lock with a dead PID
      final lockFile = File('${tempDir.path}/supabase/.deployment.lock');
      lockFile.createSync(recursive: true);
      final deadLockData = {
        'pid': 999999,
        'user': 'crashed_agent',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'project_ref': 'xzvkdwebtbxlrxagtzlv',
      };
      lockFile.writeAsStringSync(jsonEncode(deadLockData));

      // Acquisition detects dead PID and recovers lock atomically
      final newLock = manager.acquireDeploymentLock(
        projectRef: 'xzvkdwebtbxlrxagtzlv',
        customPid: 1234,
      );
      expect(newLock.existsSync(), isTrue);

      final content = jsonDecode(newLock.readAsStringSync()) as Map<String, dynamic>;
      expect(content['pid'], equals(1234));

      manager.releaseDeploymentLock();
    });

    test('forceUnlock clears existing deployment lock', () {
      final manager = GuardedDeploymentManager(workingDirectory: tempDir);
      final lockFile = File('${tempDir.path}/supabase/.deployment.lock');
      lockFile.createSync(recursive: true);
      lockFile.writeAsStringSync(jsonEncode({'pid': 999999, 'user': 'stuck_agent'}));

      final newLock = manager.acquireDeploymentLock(
        projectRef: 'xzvkdwebtbxlrxagtzlv',
        forceUnlock: true,
        customPid: 42,
      );

      expect(newLock.existsSync(), isTrue);
      final content = jsonDecode(newLock.readAsStringSync()) as Map<String, dynamic>;
      expect(content['pid'], equals(42));

      manager.releaseDeploymentLock();
    });

    test('verifyWorkingTreeCleanliness rejects uncommitted migration files even with allowDirty=true', () {
      // Mock git returning uncommitted migration
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          if (args.contains('supabase/migrations')) {
            return ProcessResult(0, 0, ' M supabase/migrations/20261015010000_uncommitted.sql\n', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(
        () => manager.verifyWorkingTreeCleanliness(allowDirty: true),
        throwsStateError,
      );
      expect(
        () => manager.verifyWorkingTreeCleanliness(allowDirty: false),
        throwsStateError,
      );
    });

    test('verifyWorkingTreeCleanliness allows non-migration dirty files only when allowDirty=true', () {
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          if (args.contains('supabase/migrations')) {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, ' M README.md\n', '');
        },
      );

      // Throws when allowDirty is false
      expect(
        () => manager.verifyWorkingTreeCleanliness(allowDirty: false),
        throwsStateError,
      );

      // Passes when allowDirty is true
      expect(
        () => manager.verifyWorkingTreeCleanliness(allowDirty: true),
        returnsNormally,
      );
    });

    test('verifyCliVersion enforces pinned version 2.67.1', () {
      // 1. Matches pinned version 2.67.1
      final managerPinned = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          return ProcessResult(0, 0, '2.67.1\n', '');
        },
      );
      expect(managerPinned.verifyCliVersion(), equals('2.67.1'));

      // 2. Mismatched version throws StateError
      final managerUnpinned = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          return ProcessResult(0, 0, '2.99.0\n', '');
        },
      );
      expect(
        () => managerUnpinned.verifyCliVersion(),
        throwsStateError,
      );

      // 3. Mismatched version allowed if allowUnpinned is true
      expect(
        managerUnpinned.verifyCliVersion(allowUnpinned: true),
        equals('2.99.0'),
      );
    });

    test('verifyDryRunMatch enforces complete set equality of proposed migrations', () {
      final manager = GuardedDeploymentManager(workingDirectory: tempDir);

      // 1. 0 pending migrations and "Remote database is up to date" passes
      expect(
        () => manager.verifyDryRunMatch(
          pendingVersions: [],
          dryRunOutput: 'Remote database is up to date.\n',
        ),
        returnsNormally,
      );

      // 2. 0 pending migrations but dry-run proposes a migration throws
      expect(
        () => manager.verifyDryRunMatch(
          pendingVersions: [],
          dryRunOutput: 'Would push migration: 20261012000000_catalog.sql\n',
        ),
        throwsStateError,
      );

      // 3. Exact matching set passes
      expect(
        () => manager.verifyDryRunMatch(
          pendingVersions: ['20261015010000', '20261015020000'],
          dryRunOutput: '''
DRY RUN: migrations will not be pushed
Applying migration 20261015010000_alpha.sql...
Applying migration 20261015020000_beta.sql...
''',
        ),
        returnsNormally,
      );

      // 4. Missing a pending migration in dry-run output throws
      expect(
        () => manager.verifyDryRunMatch(
          pendingVersions: ['20261015010000', '20261015020000'],
          dryRunOutput: 'Applying migration 20261015010000_alpha.sql...\n',
        ),
        throwsStateError,
      );

      // 5. Extra unexpected migration in dry-run output throws
      expect(
        () => manager.verifyDryRunMatch(
          pendingVersions: ['20261015010000'],
          dryRunOutput: '''
Applying migration 20261015010000_alpha.sql...
Applying migration 20261015020000_extra.sql...
''',
        ),
        throwsStateError,
      );
    });

    test('emitDeploymentReport produces valid structured non-sensitive audit report', () {
      final manager = GuardedDeploymentManager(workingDirectory: tempDir);
      final reportFile = manager.emitDeploymentReport(
        reportDirectory: tempReportDir,
        status: 'failed',
        phase: 'project_identity_check',
        projectRef: 'xzvkdwebtbxlrxagtzlv',
        cliVersion: '2.67.1',
        error: 'Missing supabase/.temp/project-ref',
      );

      expect(reportFile.existsSync(), isTrue);
      final content = jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content['status'], equals('failed'));
      expect(content['phase'], equals('project_identity_check'));
      expect(content['project_ref'], equals('xzvkdwebtbxlrxagtzlv'));
      expect(content['cli_version'], equals('2.67.1'));
      expect(content['error'], equals('Missing supabase/.temp/project-ref'));
      expect(content['timestamp_utc'], isNotNull);
    });

    test('runDeployment guarantees lock release when deployment fails', () async {
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          if (args.contains('--version')) return ProcessResult(0, 0, '2.67.1\n', '');
          if (args.contains('--porcelain')) return ProcessResult(0, 0, '', '');
          return ProcessResult(0, 0, '', '');
        },
      );

      // Setup project ref
      final refFile = File('${tempDir.path}/supabase/.temp/project-ref');
      refFile.createSync(recursive: true);
      refFile.writeAsStringSync('xzvkdwebtbxlrxagtzlv\n');

      // Execute deployment in dry-run mode
      final result = await manager.runDeployment(
        reportDirPath: 'reports',
        dryRunOnly: true,
      );

      expect(result.exitCode, equals(1)); // Fails cleanly at preflight because fake dir has no DB
      // CRITICAL INVARIANT: Lockfile must NOT remain after runDeployment returns!
      final lockFile = File('${tempDir.path}/supabase/.deployment.lock');
      expect(lockFile.existsSync(), isFalse);
    });

    test('runDeployment releases lock on successful no-op deployment', () async {
      final reportDir = Directory('${tempDir.path}/reports')..createSync(recursive: true);
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          if (args.contains('--version')) return ProcessResult(0, 0, '2.67.1\n', '');
          if (args.contains('--porcelain')) return ProcessResult(0, 0, '', '');
          if (args.contains('--preflight-hosted')) {
            // Write mock preflight report with 0 pending
            final preflightReport = File('${reportDir.path}/preflight_report.json');
            preflightReport.writeAsStringSync(jsonEncode({
              'status': 'passed',
              'pending_versions': <String>[],
              'applied_versions': ['20261012000000'],
            }));
            return ProcessResult(0, 0, 'Preflight passed\n', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      final refFile = File('${tempDir.path}/supabase/.temp/project-ref');
      refFile.createSync(recursive: true);
      refFile.writeAsStringSync('xzvkdwebtbxlrxagtzlv\n');

      final result = await manager.runDeployment(
        reportDirPath: 'reports',
        dryRunOnly: false,
      );

      expect(result.exitCode, equals(0));
      expect(result.status, equals('success'));
      final lockFile = File('${tempDir.path}/supabase/.deployment.lock');
      expect(lockFile.existsSync(), isFalse);
    });

    test('runDeployment releases lock on successful dry-run with pending migrations', () async {
      final reportDir = Directory('${tempDir.path}/reports')..createSync(recursive: true);
      final manager = GuardedDeploymentManager(
        workingDirectory: tempDir,
        processRunner: (executable, args, {workingDirectory, runInShell = false}) {
          if (args.contains('--version')) return ProcessResult(0, 0, '2.67.1\n', '');
          if (args.contains('--porcelain')) return ProcessResult(0, 0, '', '');
          if (args.contains('--preflight-hosted')) {
            final preflightReport = File('${reportDir.path}/preflight_report.json');
            preflightReport.writeAsStringSync(jsonEncode({
              'status': 'passed',
              'pending_versions': ['20261015010000'],
              'applied_versions': ['20261012000000'],
            }));
            return ProcessResult(0, 0, 'Preflight passed\n', '');
          }
          if (args.contains('--dry-run')) {
            return ProcessResult(
              0,
              0,
              'DRY RUN: migrations will not be pushed\nApplying migration 20261015010000_update.sql...\n',
              '',
            );
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      final refFile = File('${tempDir.path}/supabase/.temp/project-ref');
      refFile.createSync(recursive: true);
      refFile.writeAsStringSync('xzvkdwebtbxlrxagtzlv\n');

      final result = await manager.runDeployment(
        reportDirPath: 'reports',
        dryRunOnly: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.status, equals('dry_run_success'));
      final lockFile = File('${tempDir.path}/supabase/.deployment.lock');
      expect(lockFile.existsSync(), isFalse);
    });
  });
}

