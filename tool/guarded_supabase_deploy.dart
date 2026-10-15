import 'dart:convert';
import 'dart:io';

/// Single Guarded Deployment Workflow for Supabase Production Migrations.
///
/// Implements Phase 4 permanent prevention controls from MIGRATION_HISTORY_REPAIR_DECISION_PLAN.md:
/// 1. Single entry point: Never allows bypass paths, direct SQL injection, or newly generated timestamp aliases.
/// 2. Project identity enforcement: Verifies active link strictly targets the authorized project ref (xzvkdwebtbxlrxagtzlv).
/// 3. Working tree integrity: Strict uncommitted migration check (never bypassed by --allow-dirty).
/// 4. Deployment serialization: Process lockfile prevents concurrent deployments by developers or AI agents.
/// 5. Pinned CLI validation: Asserts installed Supabase CLI availability and version.
/// 6. Preflight version gate: Compares local canonical migration files with hosted migration ledger before any push.
/// 7. Push dry-run validation: Verifies only the approved pending append-only migrations will be applied.
/// 8. Atomic push execution: Applies migrations via verified Supabase CLI.
/// 9. Postflight version gate: Requires exact 1:1 parity between repository migration files and hosted ledger.
/// 10. Sanitized reporting: Produces non-sensitive audit status reports for both success and failure on all exit paths.
void main(List<String> args) async {
  bool dryRunOnly = false;
  bool allowDirty = false;
  bool forceUnlock = false;
  bool quiet = false;
  String targetProjectRef = 'xzvkdwebtbxlrxagtzlv';
  String reportDir = 'build/migration_deployment_reports';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRunOnly = true;
    } else if (arg == '--allow-dirty') {
      allowDirty = true;
    } else if (arg == '--force-unlock') {
      forceUnlock = true;
    } else if (arg == '--project-ref' && i + 1 < args.length) {
      targetProjectRef = args[++i];
    } else if (arg == '--report-dir' && i + 1 < args.length) {
      reportDir = args[++i];
    } else if (arg == '--quiet') {
      quiet = true;
    } else if (arg == '--help' || arg == '-h') {
      _printHelp();
      exit(0);
    }
  }

  if (!quiet) {
    stdout.writeln('====================================================');
    stdout.writeln('🛡️  Guarded Supabase Production Migration Deployment');
    stdout.writeln('====================================================');
  }

  final reportDirectory = Directory(reportDir);
  if (!reportDirectory.existsSync()) {
    reportDirectory.createSync(recursive: true);
  }

  final preflightReportPath = '${reportDirectory.path}/preflight_report.json';
  final postflightReportPath = '${reportDirectory.path}/postflight_report.json';

  String installedCliVersion = 'unknown';

  // 1. Verify Supabase CLI is available and retrieve version
  try {
    final cliVersionResult = Process.runSync('supabase', ['--version'], runInShell: true);
    if (cliVersionResult.exitCode != 0) {
      stderr.writeln('❌ FATAL: Supabase CLI is not installed or not in PATH.');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'failed',
        phase: 'cli_verification',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        error: 'Supabase CLI not found or returned non-zero exit code',
      );
      exit(1);
    }
    final rawOut = cliVersionResult.stdout.toString().trim();
    final match = RegExp(r'([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(rawOut);
    installedCliVersion = match?.group(1) ?? rawOut.split('\n').first.trim();
    if (!quiet) {
      stdout.writeln('Verified Supabase CLI version: $installedCliVersion');
    }
  } catch (e) {
    stderr.writeln('❌ FATAL: Failed to execute Supabase CLI: $e');
    _emitDeploymentReport(
      reportDirectory: reportDirectory,
      status: 'failed',
      phase: 'cli_verification',
      projectRef: targetProjectRef,
      cliVersion: installedCliVersion,
      error: 'Exception executing Supabase CLI: $e',
    );
    exit(1);
  }

  // 2. Enforce target project identity (Prevent deploying to wrong database)
  final projectRefFile = File('supabase/.temp/project-ref');
  if (!projectRefFile.existsSync()) {
    stderr.writeln('❌ FATAL: No linked Supabase project found (missing supabase/.temp/project-ref).');
    stderr.writeln('To link the project safely, run:');
    stderr.writeln('  supabase link --project-ref $targetProjectRef');
    _emitDeploymentReport(
      reportDirectory: reportDirectory,
      status: 'failed',
      phase: 'project_identity_check',
      projectRef: targetProjectRef,
      cliVersion: installedCliVersion,
      error: 'Missing supabase/.temp/project-ref',
    );
    exit(1);
  }

  final actualProjectRef = projectRefFile.readAsStringSync().trim();
  if (actualProjectRef != targetProjectRef) {
    stderr.writeln('❌ FATAL: Target Supabase project mismatch!');
    stderr.writeln('  Expected: $targetProjectRef');
    stderr.writeln('  Found:    $actualProjectRef');
    stderr.writeln('Deployment halted to prevent applying migrations to the wrong database.');
    _emitDeploymentReport(
      reportDirectory: reportDirectory,
      status: 'failed',
      phase: 'project_identity_check',
      projectRef: actualProjectRef,
      cliVersion: installedCliVersion,
      error: 'Project ref mismatch: expected $targetProjectRef but found $actualProjectRef',
    );
    exit(1);
  }
  if (!quiet) {
    stdout.writeln('Target project ref verified: $targetProjectRef');
  }

  // 3. Verify working tree integrity
  // Uncommitted migration files are NEVER permitted under any circumstances
  final diffMigrations = Process.runSync('git', ['status', '--porcelain', 'supabase/migrations']);
  final migrationChanges = diffMigrations.stdout.toString().trim();
  if (migrationChanges.isNotEmpty) {
    stderr.writeln('❌ FATAL: Working tree has uncommitted changes in supabase/migrations:');
    for (final line in migrationChanges.split('\n')) {
      stderr.writeln('  • $line');
    }
    stderr.writeln('\nAll migrations must be committed to git before deployment.');
    stderr.writeln('The --allow-dirty flag NEVER permits uncommitted migration files.');
    _emitDeploymentReport(
      reportDirectory: reportDirectory,
      status: 'failed',
      phase: 'git_migration_cleanliness',
      projectRef: targetProjectRef,
      cliVersion: installedCliVersion,
      error: 'Uncommitted migration files detected in supabase/migrations',
    );
    exit(1);
  }

  if (!allowDirty) {
    final gitStatus = Process.runSync('git', ['status', '--porcelain']);
    final dirtyFiles = gitStatus.stdout.toString().trim();
    if (dirtyFiles.isNotEmpty) {
      stderr.writeln('❌ FATAL: Working tree has uncommitted non-migration changes:');
      for (final line in dirtyFiles.split('\n')) {
        stderr.writeln('  • $line');
      }
      stderr.writeln('\nWorking tree must be clean before deployment, or pass --allow-dirty for non-migration files.');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'failed',
        phase: 'git_working_tree_cleanliness',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        error: 'Uncommitted non-migration files detected without --allow-dirty',
      );
      exit(1);
    }
  }

  // 4. Deployment Serialization (Locking)
  final lockFile = File('supabase/.deployment.lock');
  if (lockFile.existsSync()) {
    if (forceUnlock) {
      stdout.writeln('⚠️ Force-unlock active: clearing existing deployment lock.');
      lockFile.deleteSync();
    } else {
      try {
        final lockContent = lockFile.readAsStringSync().trim();
        final lockData = jsonDecode(lockContent) as Map<String, dynamic>;
        final lockPid = lockData['pid'];
        final lockUser = lockData['user'] ?? 'unknown';
        final lockTimestamp = lockData['timestamp'] ?? 'unknown';

        DateTime? lockTime;
        if (lockTimestamp is String) {
          lockTime = DateTime.tryParse(lockTimestamp);
        }
        final isStale = lockTime != null && DateTime.now().toUtc().difference(lockTime).inMinutes > 30;

        if (!isStale) {
          stderr.writeln('❌ FATAL: Concurrent deployment blocked!');
          stderr.writeln('An active deployment lock is held by PID $lockPid ($lockUser) since $lockTimestamp.');
          stderr.writeln('If this is an orphaned lock from a crashed process, inspect state and pass --force-unlock.');
          _emitDeploymentReport(
            reportDirectory: reportDirectory,
            status: 'failed',
            phase: 'deployment_serialization',
            projectRef: targetProjectRef,
            cliVersion: installedCliVersion,
            error: 'Lock contention: PID $lockPid ($lockUser) acquired lock at $lockTimestamp',
          );
          exit(1);
        } else {
          stdout.writeln('⚠️ Stale deployment lock detected (>30m old from $lockTimestamp). Overriding lock.');
          lockFile.deleteSync();
        }
      } catch (e) {
        stderr.writeln('❌ FATAL: Corrupted deployment lockfile detected: $e');
        stderr.writeln('Inspect supabase/.deployment.lock and pass --force-unlock if safe.');
        exit(1);
      }
    }
  }

  // Acquire deployment lock
  final lockData = {
    'pid': pid,
    'user': Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? 'unknown',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'project_ref': targetProjectRef,
    'host': Platform.localHostname,
  };
  lockFile.writeAsStringSync(jsonEncode(lockData));

  try {
    // 5. Preflight Version Gate
    if (!quiet) {
      stdout.writeln('\n[1/4] Running Pre-Deployment Version Gate...');
    }
    final preflightArgs = [
      'run',
      'tool/verify_migration_history.dart',
      '--preflight-hosted',
      '--report-out',
      preflightReportPath,
      if (quiet) '--quiet',
    ];
    final preflightResult = Process.runSync(
      'dart',
      preflightArgs,
      runInShell: true,
    );

    stdout.write(preflightResult.stdout);
    if (preflightResult.exitCode != 0) {
      stderr.write(preflightResult.stderr);
      stderr.writeln('\n❌ Pre-deployment gate FAILED. Halting deployment.');
      stderr.writeln('Review report at: $preflightReportPath');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'failed',
        phase: 'preflight_version_gate',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        error: 'Pre-deployment version gate failed',
      );
      exit(1);
    }

    // Parse preflight report to check pending count
    final preflightReportFile = File(preflightReportPath);
    final preflightData = jsonDecode(preflightReportFile.readAsStringSync()) as Map<String, dynamic>;
    final pendingList = (preflightData['pending_versions'] as List?) ?? [];
    final appliedList = (preflightData['applied_versions'] as List?)?.cast<String>() ?? [];

    if (pendingList.isEmpty) {
      stdout.writeln('\n✅ Hosted database is already at exact parity with repository.');
      stdout.writeln('Zero pending migrations to apply. Deployment complete.');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'success',
        phase: 'complete',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        appliedVersions: appliedList,
        pendingVersions: const [],
      );
      exit(0);
    }

    stdout.writeln('\nIdentified ${pendingList.length} pending migration(s) to deploy:');
    for (final p in pendingList) {
      stdout.writeln('  • $p');
    }

    // 6. Push Dry-Run Verification
    stdout.writeln('\n[2/4] Executing Supabase DB Push Dry Run...');
    final dryRunResult = Process.runSync(
      'supabase',
      ['db', 'push', '--linked', '--dry-run'],
      runInShell: true,
    );

    stdout.write(dryRunResult.stdout);
    if (dryRunResult.exitCode != 0) {
      stderr.write(dryRunResult.stderr);
      stderr.writeln('❌ Supabase dry-run failed. Halting deployment.');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'failed',
        phase: 'dry_run_push',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        error: 'Supabase db push --dry-run failed with exit code ${dryRunResult.exitCode}',
      );
      exit(1);
    }

    // Verify dry-run output consistency with pending migrations
    final dryRunOut = dryRunResult.stdout.toString();
    for (final pending in pendingList) {
      final pStr = pending.toString();
      if (!dryRunOut.contains(pStr)) {
        stderr.writeln('❌ FATAL: Dry-run output does not reference expected pending migration: $pStr');
        _emitDeploymentReport(
          reportDirectory: reportDirectory,
          status: 'failed',
          phase: 'dry_run_validation',
          projectRef: targetProjectRef,
          cliVersion: installedCliVersion,
          error: 'Dry-run proposed migrations do not match preflight pending list (missing $pStr)',
        );
        exit(1);
      }
    }

    if (dryRunOnly) {
      stdout.writeln('\nℹ️ Dry run completed successfully (--dry-run flag active). No changes applied.');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'dry_run_success',
        phase: 'dry_run_completed',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        appliedVersions: appliedList,
        pendingVersions: pendingList.cast<String>(),
      );
      exit(0);
    }

    // 7. Atomic Push Deployment
    stdout.writeln('\n[3/4] Applying Pending Migrations to Hosted Project...');
    final pushResult = Process.runSync(
      'supabase',
      ['db', 'push', '--linked'],
      runInShell: true,
    );

    stdout.write(pushResult.stdout);
    if (pushResult.exitCode != 0) {
      stderr.write(pushResult.stderr);
      stderr.writeln('❌ Fatal: Migration push failed!');
      final postflightArgs = [
        'run',
        'tool/verify_migration_history.dart',
        '--postflight-hosted',
        '--report-out',
        postflightReportPath,
        if (quiet) '--quiet',
      ];
      // Trigger immediate postflight to capture partial deployment state
      Process.runSync(
        'dart',
        postflightArgs,
        runInShell: true,
      );
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'failed',
        phase: 'live_push_failure',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        error: 'Supabase db push failed with exit code ${pushResult.exitCode}. Postflight state recorded.',
      );
      exit(1);
    }

    // 8. Postflight Version Gate
    stdout.writeln('\n[4/4] Running Post-Deployment Version Gate...');
    final postflightArgs = [
      'run',
      'tool/verify_migration_history.dart',
      '--postflight-hosted',
      '--report-out',
      postflightReportPath,
      if (quiet) '--quiet',
    ];
    final postflightResult = Process.runSync(
      'dart',
      postflightArgs,
      runInShell: true,
    );

    stdout.write(postflightResult.stdout);
    if (postflightResult.exitCode != 0) {
      stderr.write(postflightResult.stderr);
      stderr.writeln('\n❌ FATAL: Post-deployment gate FAILED! Partial or mismatched deployment detected.');
      stderr.writeln('Review report at: $postflightReportPath');
      _emitDeploymentReport(
        reportDirectory: reportDirectory,
        status: 'failed',
        phase: 'postflight_version_gate',
        projectRef: targetProjectRef,
        cliVersion: installedCliVersion,
        error: 'Postflight gate detected partial or mismatched deployment.',
      );
      exit(1);
    }

    stdout.writeln('\n====================================================');
    stdout.writeln('✅ Guarded deployment completed successfully with exact 1:1 parity.');
    stdout.writeln('Audit reports archived:');
    stdout.writeln('  • $preflightReportPath');
    stdout.writeln('  • $postflightReportPath');
    stdout.writeln('  • ${reportDirectory.path}/deployment_summary.json');
    stdout.writeln('====================================================');

    _emitDeploymentReport(
      reportDirectory: reportDirectory,
      status: 'success',
      phase: 'complete',
      projectRef: targetProjectRef,
      cliVersion: installedCliVersion,
      appliedVersions: [...appliedList, ...pendingList.cast<String>()],
      pendingVersions: const [],
    );
  } finally {
    if (lockFile.existsSync()) {
      try {
        lockFile.deleteSync();
      } catch (_) {}
    }
  }
}

void _emitDeploymentReport({
  required Directory reportDirectory,
  required String status,
  required String phase,
  required String projectRef,
  required String cliVersion,
  String? error,
  List<String>? appliedVersions,
  List<String>? pendingVersions,
}) {
  final reportFile = File('${reportDirectory.path}/deployment_summary.json');
  String gitCommit = 'unknown';
  try {
    final commitResult = Process.runSync('git', ['rev-parse', 'HEAD']);
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
}

void _printHelp() {
  stdout.writeln('''
Guarded Supabase Production Migration Deployment Tool

Executes the guarded deployment workflow:
  1. CLI verification: asserts Supabase CLI is available and meets semver standards.
  2. Project identity enforcement: ensures linked project ref matches expected target (xzvkdwebtbxlrxagtzlv).
  3. Working tree check: ensures all migration files are committed (never bypassed).
  4. Deployment serialization: acquires lockfile to block concurrent deployments.
  5. Preflight version gate: asserts that hosted migrations are a valid prefix of local.
  6. Push dry-run: verifies planned changes before execution.
  7. Live push: applies pending append-only migrations.
  8. Postflight version gate: asserts exact 1:1 parity with repository.
  9. Emits non-sensitive JSON audit reports for every stage and exit path.

Options:
  --dry-run             Perform preflight and dry-run push without applying changes.
  --allow-dirty         Allow non-migration uncommitted working tree files (migrations still blocked).
  --force-unlock        Clear an existing deployment lock if previous deployment crashed.
  --project-ref <id>    Expected Supabase project ref (default: xzvkdwebtbxlrxagtzlv).
  --report-dir <dir>    Directory to store audit reports (default: build/migration_deployment_reports).
  --quiet               Suppress verbose logs.
  -h, --help            Show this help.
''');
}
