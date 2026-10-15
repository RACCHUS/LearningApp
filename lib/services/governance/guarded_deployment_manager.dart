import 'dart:convert';
import 'dart:io';

/// Signature for executing external processes, allowing dependency injection for unit testing.
typedef ProcessRunner = ProcessResult Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell,
});

/// Result of a guarded deployment execution.
class DeploymentExecutionResult {
  final int exitCode;
  final String status;
  final String phase;
  final String? error;
  final List<String> appliedVersions;
  final List<String> pendingVersions;

  const DeploymentExecutionResult({
    required this.exitCode,
    required this.status,
    required this.phase,
    this.error,
    this.appliedVersions = const [],
    this.pendingVersions = const [],
  });

  bool get isSuccess => exitCode == 0;
}

/// Manages and coordinates the single guarded deployment path for Supabase migrations.
///
/// Implements Phase 4 permanent prevention controls:
/// - Pinned Supabase CLI version enforcement
/// - Target project identity assertion
/// - Strict migration cleanliness (never bypassed by --allow-dirty)
/// - Atomic process-level deployment serialization lock with liveness checks
/// - Preflight version validation
/// - Complete set-equality dry-run validation (blocks unexpected extra or missing migrations)
/// - Atomic push execution
/// - Postflight version parity gate
/// - Guaranteed structured reporting and guaranteed lock cleanup
class GuardedDeploymentManager {
  static const String defaultProjectRef = 'xzvkdwebtbxlrxagtzlv';
  static const String pinnedCliVersion = '2.67.1';

  final Directory workingDirectory;
  final ProcessRunner processRunner;
  final IOSink stdoutSink;
  final IOSink stderrSink;

  GuardedDeploymentManager({
    Directory? workingDirectory,
    ProcessRunner? processRunner,
    IOSink? stdoutSink,
    IOSink? stderrSink,
  })  : workingDirectory = workingDirectory ?? Directory.current,
        processRunner = processRunner ?? Process.runSync,
        stdoutSink = stdoutSink ?? stdout,
        stderrSink = stderrSink ?? stderr;

  /// Verifies that the linked Supabase project reference strictly matches the expected target.
  void verifyProjectRef(String expectedRef) {
    final refFile = File('${workingDirectory.path}/supabase/.temp/project-ref');
    if (!refFile.existsSync()) {
      throw StateError(
        'Missing supabase/.temp/project-ref. No linked Supabase project found.\n'
        'To link the project safely, run:\n'
        '  supabase link --project-ref $expectedRef',
      );
    }

    final actualRef = refFile.readAsStringSync().trim();
    if (actualRef != expectedRef) {
      throw StateError(
        'Target Supabase project mismatch!\n'
        '  Expected: $expectedRef\n'
        '  Found:    $actualRef\n'
        'Deployment halted to prevent applying migrations to the wrong database.',
      );
    }
  }

  /// Verifies that the installed Supabase CLI version matches the pinned version.
  String verifyCliVersion({
    String expectedVersion = pinnedCliVersion,
    bool allowUnpinned = false,
  }) {
    final result = processRunner(
      'supabase',
      ['--version'],
      workingDirectory: workingDirectory.path,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw StateError(
        'Supabase CLI is not installed or not in PATH (exit code ${result.exitCode}).',
      );
    }

    final rawOut = result.stdout.toString().trim();
    final match = RegExp(r'([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(rawOut);
    final installedVersion = match?.group(1) ?? rawOut.split('\n').first.trim();

    if (!allowUnpinned && installedVersion != expectedVersion) {
      throw StateError(
        'Supabase CLI version mismatch!\n'
        '  Approved pinned version: $expectedVersion\n'
        '  Installed version:       $installedVersion\n'
        'Pass --allow-unpinned-cli to override during development.',
      );
    }

    return installedVersion;
  }

  /// Verifies working tree cleanliness.
  ///
  /// CRITICAL: Any uncommitted change in supabase/migrations/ strictly halts deployment,
  /// even when allowDirty is true.
  void verifyWorkingTreeCleanliness({bool allowDirty = false}) {
    final migrationResult = processRunner(
      'git',
      ['status', '--porcelain', 'supabase/migrations'],
      workingDirectory: workingDirectory.path,
      runInShell: true,
    );

    final migrationChanges = migrationResult.stdout.toString().trim();
    if (migrationChanges.isNotEmpty) {
      final changedFiles = migrationChanges.split('\n').map((l) => '  • $l').join('\n');
      throw StateError(
        'Working tree has uncommitted changes in supabase/migrations:\n'
        '$changedFiles\n'
        'All migration files must be committed before deployment.\n'
        'The --allow-dirty flag NEVER permits uncommitted migration files.',
      );
    }

    if (!allowDirty) {
      final gitResult = processRunner(
        'git',
        ['status', '--porcelain'],
        workingDirectory: workingDirectory.path,
        runInShell: true,
      );

      final dirtyFiles = gitResult.stdout.toString().trim();
      if (dirtyFiles.isNotEmpty) {
        final list = dirtyFiles.split('\n').map((l) => '  • $l').join('\n');
        throw StateError(
          'Working tree has uncommitted non-migration changes:\n'
          '$list\n'
          'Working tree must be clean before deployment, or pass --allow-dirty for non-migration files.',
        );
      }
    }
  }

  /// Checks whether a process with [pid] is currently running on the system.
  bool isProcessAlive(int pid) {
    if (pid <= 0) return false;
    try {
      if (Platform.isWindows) {
        final res = processRunner(
          'tasklist',
          ['/FI', 'PID eq $pid', '/NH'],
          runInShell: true,
        );
        final out = res.stdout.toString();
        return out.contains(pid.toString()) && !out.contains('No tasks');
      } else {
        final res = processRunner('kill', ['-0', '$pid'], runInShell: true);
        return res.exitCode == 0;
      }
    } catch (_) {
      // If unable to query process table, assume alive for safety
      return true;
    }
  }

  /// Atomically acquires the deployment lockfile using `File.createSync(exclusive: true)`.
  ///
  /// CRITICAL DISTRIBUTED LOCK LIMITATION:
  /// The deployment lockfile is a local-filesystem mutex (`supabase/.deployment.lock`).
  /// It prevents concurrent deployment processes on the same developer workstation,
  /// dev container, or CI runner from racing or corrupting migration state.
  /// It CANNOT coordinate deployments from separate physical machines. Multi-developer
  /// deployment coordination must be enforced through branch protections, serialized CI pipelines,
  /// or remote database-level advisory locks.
  ///
  /// Checks process liveness via OS process inspection (`tasklist` on Windows, `kill -0` on POSIX)
  /// before allowing recovery. Age alone NEVER causes an active process's lock to be stolen.
  File acquireDeploymentLock({
    required String projectRef,
    bool forceUnlock = false,
    int? customPid,
  }) {
    final lockDir = Directory('${workingDirectory.path}/supabase');
    if (!lockDir.existsSync()) {
      lockDir.createSync(recursive: true);
    }
    final lockFile = File('${lockDir.path}/.deployment.lock');
    final targetPid = customPid ?? pid;

    if (forceUnlock && lockFile.existsSync()) {
      stdoutSink.writeln('⚠️ Force-unlock active: removing existing deployment lock.');
      try {
        lockFile.deleteSync();
      } catch (_) {}
    }

    // Attempt atomic lock acquisition
    final lockData = {
      'pid': targetPid,
      'user': Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? 'unknown',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'project_ref': projectRef,
      'host': Platform.localHostname,
    };

    try {
      lockFile.createSync(exclusive: true);
      lockFile.writeAsStringSync(jsonEncode(lockData));
      return lockFile;
    } on FileSystemException {
      // Lock already exists. Check ownership and liveness.
      Map<String, dynamic>? existingData;
      try {
        existingData = jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}

      final existingPid = existingData?['pid'] as int?;
      final existingUser = existingData?['user'] ?? 'unknown';
      final existingTime = existingData?['timestamp'] ?? 'unknown';

      if (existingPid != null && isProcessAlive(existingPid)) {
        throw StateError(
          'Concurrent deployment blocked!\n'
          'An active deployment lock is held by PID $existingPid ($existingUser) since $existingTime.\n'
          'The process is actively running. Simultaneous deployments are prohibited.',
        );
      }

      // Process is confirmed DEAD (crashed without cleanup)
      stdoutSink.writeln(
        '⚠️ Detected dead lockfile from crashed PID $existingPid ($existingUser from $existingTime). Recovering lock.',
      );
      try {
        lockFile.deleteSync();
      } catch (_) {}

      // Retry atomic creation after clearing dead lock
      lockFile.createSync(exclusive: true);
      lockFile.writeAsStringSync(jsonEncode(lockData));
      return lockFile;
    }
  }

  /// Releases the deployment lockfile if it exists.
  void releaseDeploymentLock() {
    final lockFile = File('${workingDirectory.path}/supabase/.deployment.lock');
    if (lockFile.existsSync()) {
      try {
        lockFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Verifies that the proposed migrations in dry-run output match the preflight pending migrations.
  ///
  /// Enforces COMPLETE set equality:
  /// - All pending migrations must be proposed.
  /// - NO extra unexpected migrations may be proposed.
  void verifyDryRunMatch({
    required List<String> pendingVersions,
    required String dryRunOutput,
  }) {
    final versionRegex = RegExp(r'(?<!\d)(20\d{12})(?!\d)');
    final proposedMatches = versionRegex.allMatches(dryRunOutput).map((m) => m.group(1)!).toSet();

    if (pendingVersions.isEmpty) {
      if (!dryRunOutput.contains('Remote database is up to date')) {
        if (proposedMatches.isNotEmpty) {
          throw StateError(
            'Inconsistency: preflight reported 0 pending migrations, but dry-run proposed applying: ${proposedMatches.toList()}',
          );
        }
      }
      return;
    }

    final pendingSet = pendingVersions.toSet();
    final missingInDryRun = pendingSet.difference(proposedMatches);
    final extraInDryRun = proposedMatches.difference(pendingSet);

    if (missingInDryRun.isNotEmpty || extraInDryRun.isNotEmpty) {
      final buffer = StringBuffer('Dry-run proposed migrations do not match preflight pending list!\n');
      if (missingInDryRun.isNotEmpty) {
        buffer.writeln('  • Missing from dry-run: ${missingInDryRun.toList()}');
      }
      if (extraInDryRun.isNotEmpty) {
        buffer.writeln('  • Extra unexpected migrations in dry-run: ${extraInDryRun.toList()}');
      }
      throw StateError(buffer.toString().trim());
    }
  }

  /// Emits a structured, non-sensitive deployment summary report.
  File emitDeploymentReport({
    required Directory reportDirectory,
    required String status,
    required String phase,
    required String projectRef,
    required String cliVersion,
    String? error,
    List<String>? appliedVersions,
    List<String>? pendingVersions,
  }) {
    if (!reportDirectory.existsSync()) {
      reportDirectory.createSync(recursive: true);
    }
    final reportFile = File('${reportDirectory.path}/deployment_summary.json');
    String gitCommit = 'unknown';
    try {
      final commitResult = processRunner(
        'git',
        ['rev-parse', 'HEAD'],
        workingDirectory: workingDirectory.path,
        runInShell: true,
      );
      if (commitResult.exitCode == 0) {
        gitCommit = commitResult.stdout.toString().trim();
      }
    } catch (_) {}

    final report = {
      'deployment_id': DateTime.now().toUtc().toIso8601String(),
      'status': status,
      'phase': phase,
      'project_ref': projectRef,
      'cli_version': cliVersion,
      'git_commit': gitCommit,
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      if (error != null) 'error': error,
      if (appliedVersions != null) 'applied_versions': appliedVersions,
      if (pendingVersions != null) 'pending_versions': pendingVersions,
    };
    reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return reportFile;
  }

  /// Runs the full guarded deployment workflow.
  ///
  /// Returns a [DeploymentExecutionResult] with the final exitCode (0 for success, 1 for failure).
  /// NEVER calls [exit()] internally, ensuring active finally blocks and lockfile cleanup always run.
  Future<DeploymentExecutionResult> runDeployment({
    String targetProjectRef = defaultProjectRef,
    String reportDirPath = 'build/migration_deployment_reports',
    bool dryRunOnly = false,
    bool allowDirty = false,
    bool forceUnlock = false,
    bool allowUnpinnedCli = false,
    bool quiet = false,
  }) async {
    final reportDirectory = Directory('${workingDirectory.path}/$reportDirPath');
    if (!reportDirectory.existsSync()) {
      reportDirectory.createSync(recursive: true);
    }

    final preflightReportPath = '${reportDirectory.path}/preflight_report.json';
    final postflightReportPath = '${reportDirectory.path}/postflight_report.json';

    String detectedCliVersion = 'unknown';
    bool lockAcquired = false;

    try {
      // 1. Verify CLI version
      try {
        detectedCliVersion = verifyCliVersion(
          expectedVersion: pinnedCliVersion,
          allowUnpinned: allowUnpinnedCli,
        );
      } catch (e) {
        stderrSink.writeln('❌ FATAL: CLI verification failed: $e');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'cli_verification',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: e.toString(),
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'cli_verification',
          error: e.toString(),
        );
      }

      // 2. Enforce Project Identity
      try {
        verifyProjectRef(targetProjectRef);
      } catch (e) {
        stderrSink.writeln('❌ FATAL: Project identity check failed: $e');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'project_identity_check',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: e.toString(),
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'project_identity_check',
          error: e.toString(),
        );
      }

      // 3. Verify Working Tree Cleanliness
      try {
        verifyWorkingTreeCleanliness(allowDirty: allowDirty);
      } catch (e) {
        stderrSink.writeln('❌ FATAL: Working tree check failed: $e');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'working_tree_cleanliness',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: e.toString(),
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'working_tree_cleanliness',
          error: e.toString(),
        );
      }

      // 4. Atomic Deployment Lock
      try {
        acquireDeploymentLock(
          projectRef: targetProjectRef,
          forceUnlock: forceUnlock,
        );
        lockAcquired = true;
      } catch (e) {
        stderrSink.writeln('❌ FATAL: Deployment locking failed: $e');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'deployment_serialization',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: e.toString(),
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'deployment_serialization',
          error: e.toString(),
        );
      }

      // 5. Preflight Version Gate
      if (!quiet) {
        stdoutSink.writeln('\n[1/4] Running Pre-Deployment Version Gate...');
      }
      final preflightResult = processRunner(
        'dart',
        [
          'run',
          'tool/verify_migration_history.dart',
          '--preflight-hosted',
          '--report-out',
          preflightReportPath,
          if (quiet) '--quiet',
        ],
        workingDirectory: workingDirectory.path,
        runInShell: true,
      );

      stdoutSink.write(preflightResult.stdout);
      if (preflightResult.exitCode != 0) {
        stderrSink.write(preflightResult.stderr);
        stderrSink.writeln('\n❌ Pre-deployment gate FAILED. Halting deployment.');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'preflight_version_gate',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: 'Pre-deployment version gate failed with exit code ${preflightResult.exitCode}',
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'preflight_version_gate',
          error: 'Preflight version gate failed',
        );
      }

      // Read preflight report
      final preflightFile = File(preflightReportPath);
      if (!preflightFile.existsSync()) {
        final error = 'Preflight succeeded but report file not found at $preflightReportPath';
        stderrSink.writeln('❌ FATAL: $error');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'preflight_version_gate',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: error,
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'preflight_version_gate',
          error: error,
        );
      }

      Map<String, dynamic> preflightData;
      try {
        preflightData = jsonDecode(preflightFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (e) {
        final error = 'Malformed preflight report at $preflightReportPath: $e';
        stderrSink.writeln('❌ FATAL: $error');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'preflight_version_gate',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: error,
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'preflight_version_gate',
          error: error,
        );
      }

      final pendingList = (preflightData['pending_versions'] as List?)?.cast<String>() ?? [];
      final appliedList = (preflightData['applied_versions'] as List?)?.cast<String>() ?? [];

      if (pendingList.isEmpty) {
        stdoutSink.writeln('\n✅ Hosted database is already at exact parity with repository.');
        stdoutSink.writeln('Zero pending migrations to apply. Deployment complete.');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'success',
          phase: 'complete',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          appliedVersions: appliedList,
          pendingVersions: const [],
        );
        return DeploymentExecutionResult(
          exitCode: 0,
          status: 'success',
          phase: 'complete',
          appliedVersions: appliedList,
          pendingVersions: const [],
        );
      }

      stdoutSink.writeln('\nIdentified ${pendingList.length} pending migration(s) to deploy:');
      for (final p in pendingList) {
        stdoutSink.writeln('  • $p');
      }

      // 6. Push Dry-Run Verification
      stdoutSink.writeln('\n[2/4] Executing Supabase DB Push Dry Run...');
      final dryRunResult = processRunner(
        'supabase',
        ['db', 'push', '--linked', '--dry-run'],
        workingDirectory: workingDirectory.path,
        runInShell: true,
      );

      stdoutSink.write(dryRunResult.stdout);
      if (dryRunResult.exitCode != 0) {
        stderrSink.write(dryRunResult.stderr);
        stderrSink.writeln('❌ Supabase dry-run failed. Halting deployment.');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'dry_run_push',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: 'Supabase db push --dry-run failed with exit code ${dryRunResult.exitCode}',
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'dry_run_push',
          error: 'Dry run failed',
        );
      }

      try {
        verifyDryRunMatch(
          pendingVersions: pendingList,
          dryRunOutput: dryRunResult.stdout.toString(),
        );
      } catch (e) {
        stderrSink.writeln('❌ FATAL: Dry run verification failed: $e');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'dry_run_validation',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: e.toString(),
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'dry_run_validation',
          error: e.toString(),
        );
      }

      if (dryRunOnly) {
        stdoutSink.writeln('\nℹ️ Dry run completed successfully (--dry-run flag active). No changes applied.');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'dry_run_success',
          phase: 'dry_run_completed',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          appliedVersions: appliedList,
          pendingVersions: pendingList,
        );
        return DeploymentExecutionResult(
          exitCode: 0,
          status: 'dry_run_success',
          phase: 'dry_run_completed',
          appliedVersions: appliedList,
          pendingVersions: pendingList,
        );
      }

      // 7. Push Live Migrations
      stdoutSink.writeln('\n[3/4] Applying Pending Migrations to Hosted Project...');
      final pushResult = processRunner(
        'supabase',
        ['db', 'push', '--linked'],
        workingDirectory: workingDirectory.path,
        runInShell: true,
      );

      stdoutSink.write(pushResult.stdout);
      if (pushResult.exitCode != 0) {
        stderrSink.write(pushResult.stderr);
        stderrSink.writeln('❌ Fatal: Migration push failed!');
        // Trigger postflight to capture state
        processRunner(
          'dart',
          [
            'run',
            'tool/verify_migration_history.dart',
            '--postflight-hosted',
            '--report-out',
            postflightReportPath,
            if (quiet) '--quiet',
          ],
          workingDirectory: workingDirectory.path,
          runInShell: true,
        );
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'live_push_failure',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: 'Supabase db push failed with exit code ${pushResult.exitCode}. Postflight state recorded.',
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'live_push_failure',
          error: 'Push failed',
        );
      }

      // 8. Postflight Version Gate
      stdoutSink.writeln('\n[4/4] Running Post-Deployment Version Gate...');
      final postflightResult = processRunner(
        'dart',
        [
          'run',
          'tool/verify_migration_history.dart',
          '--postflight-hosted',
          '--report-out',
          postflightReportPath,
          if (quiet) '--quiet',
        ],
        workingDirectory: workingDirectory.path,
        runInShell: true,
      );

      stdoutSink.write(postflightResult.stdout);
      if (postflightResult.exitCode != 0) {
        stderrSink.write(postflightResult.stderr);
        stderrSink.writeln('\n❌ FATAL: Post-deployment gate FAILED! Partial or mismatched deployment detected.');
        emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'postflight_version_gate',
          projectRef: targetProjectRef,
          cliVersion: detectedCliVersion,
          error: 'Postflight gate detected partial or mismatched deployment.',
        );
        return DeploymentExecutionResult(
          exitCode: 1,
          status: 'failed',
          phase: 'postflight_version_gate',
          error: 'Postflight gate failed',
        );
      }

      stdoutSink.writeln('\n====================================================');
      stdoutSink.writeln('✅ Guarded deployment completed successfully with exact 1:1 parity.');
      stdoutSink.writeln('====================================================');

      emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'success',
        phase: 'complete',
        projectRef: targetProjectRef,
        cliVersion: detectedCliVersion,
        appliedVersions: [...appliedList, ...pendingList],
        pendingVersions: const [],
      );
      return DeploymentExecutionResult(
        exitCode: 0,
        status: 'success',
        phase: 'complete',
        appliedVersions: [...appliedList, ...pendingList],
      );
    } finally {
      if (lockAcquired) {
        releaseDeploymentLock();
      }
    }
  }
}
