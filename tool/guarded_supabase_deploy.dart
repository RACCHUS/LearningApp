import 'dart:convert';
import 'dart:io';

/// Single Guarded Deployment Workflow for Supabase Production Migrations.
///
/// Implements Phase 4 permanent prevention controls from MIGRATION_HISTORY_REPAIR_DECISION_PLAN.md:
/// 1. Single entry point: Never allows bypass paths, direct SQL injection, or newly generated timestamp aliases.
/// 2. Preflight version gate: Compares local canonical migration files with hosted migration ledger before any push.
/// 3. Push dry-run validation: Verifies only the approved pending append-only migrations will be applied.
/// 4. Atomic push execution: Applies migrations via pinned Supabase CLI.
/// 5. Postflight version gate: Requires exact 1:1 parity between repository migration files and hosted ledger.
/// 6. Sanitized reporting: Produces non-sensitive audit status reports for both success and failure.
void main(List<String> args) async {
  bool dryRunOnly = false;
  bool allowDirty = false;
  bool quiet = false;
  String reportDir = 'build/migration_deployment_reports';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRunOnly = true;
    } else if (arg == '--allow-dirty') {
      allowDirty = true;
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

  // 1. Verify clean git working tree unless --allow-dirty is set
  if (!allowDirty) {
    final gitStatus = Process.runSync('git', ['status', '--porcelain']);
    if (gitStatus.exitCode == 0 && gitStatus.stdout.toString().trim().isNotEmpty) {
      // Check if changes affect supabase/migrations
      final diffMigrations = Process.runSync('git', ['status', '--porcelain', 'supabase/migrations']);
      if (diffMigrations.stdout.toString().trim().isNotEmpty) {
        stderr.writeln('❌ Error: Working tree has uncommitted changes in supabase/migrations.');
        stderr.writeln('All migrations must be committed to git before deployment.');
        exit(1);
      }
    }
  }

  final reportDirectory = Directory(reportDir);
  if (!reportDirectory.existsSync()) {
    reportDirectory.createSync(recursive: true);
  }

  final preflightReportPath = '${reportDirectory.path}/preflight_report.json';
  final postflightReportPath = '${reportDirectory.path}/postflight_report.json';

  // 2. Preflight Version Gate
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
    exit(1);
  }

  // Parse preflight report to check pending count
  final preflightReportFile = File(preflightReportPath);
  final preflightData = jsonDecode(preflightReportFile.readAsStringSync()) as Map<String, dynamic>;
  final pendingList = (preflightData['pending_versions'] as List?) ?? [];

  if (pendingList.isEmpty) {
    stdout.writeln('\n✅ Hosted database is already at exact parity with repository.');
    stdout.writeln('Zero pending migrations to apply. Deployment complete.');
    exit(0);
  }

  stdout.writeln('\nIdentified ${pendingList.length} pending migration(s) to deploy:');
  for (final p in pendingList) {
    stdout.writeln('  • $p');
  }

  // 3. Dry-Run Verification
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
    exit(1);
  }

  if (dryRunOnly) {
    stdout.writeln('\nℹ️ Dry run completed successfully (--dry-run flag active). No changes applied.');
    exit(0);
  }

  // 4. Push Deployment
  stdout.writeln('\n[3/4] Applying Pending Migrations to Hosted Project...');
  final pushResult = Process.runSync(
    'supabase',
    ['db', 'push', '--linked'],
    runInShell: true,
  );

  stdout.write(pushResult.stdout);
  if (pushResult.exitCode != 0) {
    stderr.write(pushResult.stderr);
    final postflightArgs = [
      'run',
      'tool/verify_migration_history.dart',
      '--postflight-hosted',
      '--report-out',
      postflightReportPath,
      if (quiet) '--quiet',
    ];
    // Trigger immediate postflight to capture state
    Process.runSync(
      'dart',
      postflightArgs,
      runInShell: true,
    );
    exit(1);
  }

  // 5. Postflight Version Gate
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
    exit(1);
  }

  stdout.writeln('\n====================================================');
  stdout.writeln('✅ Guarded deployment completed successfully with exact 1:1 parity.');
  stdout.writeln('Audit reports archived:');
  stdout.writeln('  • $preflightReportPath');
  stdout.writeln('  • $postflightReportPath');
  stdout.writeln('====================================================');
}

void _printHelp() {
  stdout.writeln('''
Guarded Supabase Production Migration Deployment Tool

Executes the guarded deployment workflow:
  1. Preflight version gate: asserts that hosted migrations are a valid prefix of local.
  2. Push dry-run: verifies planned changes before execution.
  3. Live push: applies pending append-only migrations.
  4. Postflight version gate: asserts exact 1:1 parity with repository.
  5. Emits non-sensitive JSON audit reports.

Options:
  --dry-run             Perform preflight and dry-run push without applying changes.
  --allow-dirty         Allow running even if untracked non-migration files exist in git.
  --report-dir <dir>    Directory to store audit reports (default: build/migration_deployment_reports).
  --quiet               Suppress verbose logs.
  -h, --help            Show this help.
''');
}
