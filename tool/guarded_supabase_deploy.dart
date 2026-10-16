import 'dart:io';

import '../lib/services/governance/guarded_deployment_manager.dart';

/// Single Guarded Deployment CLI Entrypoint for Supabase Production Migrations.
void main(List<String> args) async {
  bool dryRunOnly = false;
  bool allowDirty = false;
  bool forceUnlock = false;
  bool allowUnpinnedCli = false;
  bool requireBase = true;
  String baseRef = 'origin/main';
  bool quiet = false;
  String targetProjectRef = GuardedDeploymentManager.defaultProjectRef;
  String reportDir = 'build/migration_deployment_reports';
  String workingDir = '.';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRunOnly = true;
    } else if (arg == '--allow-dirty') {
      allowDirty = true;
    } else if (arg == '--force-unlock') {
      forceUnlock = true;
    } else if (arg == '--allow-unpinned-cli') {
      allowUnpinnedCli = true;
    } else if (arg == '--allow-no-base') {
      requireBase = false;
    } else if (arg == '--base-ref' && i + 1 < args.length) {
      baseRef = args[++i];
    } else if (arg == '--project-ref' && i + 1 < args.length) {
      targetProjectRef = args[++i];
    } else if (arg == '--report-dir' && i + 1 < args.length) {
      reportDir = args[++i];
    } else if (arg == '--working-dir' && i + 1 < args.length) {
      workingDir = args[++i];
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

  final manager = GuardedDeploymentManager(
    workingDirectory: Directory(workingDir),
  );

  final result = await manager.runDeployment(
    targetProjectRef: targetProjectRef,
    reportDirPath: reportDir,
    baseRef: baseRef,
    requireBase: requireBase,
    dryRunOnly: dryRunOnly,
    allowDirty: allowDirty,
    forceUnlock: forceUnlock,
    allowUnpinnedCli: allowUnpinnedCli,
    quiet: quiet,
  );

  // Exit cleanly with the computed result code
  exit(result.exitCode);
}

void _printHelp() {
  stdout.writeln('''
Guarded Supabase Production Migration Deployment Tool

Executes the single guarded deployment workflow:
  1. CLI verification: asserts Supabase CLI is pinned to ${GuardedDeploymentManager.pinnedCliVersion}.
  2. Project identity enforcement: ensures linked project ref matches expected target (xzvkdwebtbxlrxagtzlv).
  3. Working tree check: ensures all migration files are committed (never bypassed by --allow-dirty).
  4. Deployment serialization: acquires atomic lockfile to block concurrent deployments.
  5. Preflight version gate: asserts that hosted migrations are a valid prefix of local and matches git baseline.
  6. Push dry-run: verifies planned changes before execution and validates set equality.
  7. Live push: applies pending append-only migrations.
  8. Postflight version gate: asserts exact 1:1 parity with repository.
  9. Emits non-sensitive JSON audit reports for every stage and exit path.

Options:
  --dry-run               Perform preflight and dry-run push without applying changes.
  --allow-dirty           Allow non-migration uncommitted working tree files (migrations still blocked).
  --force-unlock          Clear an existing deployment lock if previous deployment crashed.
  --allow-unpinned-cli    Allow running with an unpinned Supabase CLI version for testing.
  --base-ref <ref>        Git reference to verify migration immutability against (default: origin/main).
  --allow-no-base         Allow deployment without a resolved git baseline (not recommended in production).
  --project-ref <id>      Expected Supabase project ref (default: xzvkdwebtbxlrxagtzlv).
  --report-dir <dir>      Directory to store audit reports (default: build/migration_deployment_reports).
  --working-dir <dir>     Base repository directory (default: .).
  --quiet                 Suppress verbose logs.
  -h, --help              Show this help.
''');
}
