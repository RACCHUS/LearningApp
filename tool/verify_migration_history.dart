import 'dart:convert';
import 'dart:io';
import 'package:learning_pwa/services/governance/migration_history_validator.dart';

/// CLI Tool: Verify Supabase Migration History Immutability & Upgrade Safety
///
/// Ensures:
///   1. All local migrations conform to canonical format <14-digit timestamp>_<name>.sql.
///   2. Monotonic ascending ordering and no duplicate timestamps.
///   3. Non-empty migration scripts.
///   4. Strict append-only immutability against an authoritative base branch (e.g. origin/main):
///      - Zero deletions of previously merged migrations.
///      - Zero in-place edits to previously merged migrations.
///      - All newly introduced migrations have timestamps newer than the baseline.
///   5. Automated isolation/restoration of pending migrations for incremental upgrade testing in CI.
///
/// Usage:
///   dart run tool/verify_migration_history.dart
///   dart run tool/verify_migration_history.dart --base-ref origin/main
///   dart run tool/verify_migration_history.dart --list-pending
///   dart run tool/verify_migration_history.dart --isolate-pending build/pending_migrations
///   dart run tool/verify_migration_history.dart --restore-pending build/pending_migrations
///   dart run tool/verify_migration_history.dart --preflight-hosted
///   dart run tool/verify_migration_history.dart --postflight-hosted
///   dart run tool/verify_migration_history.dart --report-out build/migration_gate_report.json
void main(List<String> args) async {
  String migrationsDirPath = 'supabase/migrations';
  String? baseRef = 'origin/main';
  bool requireBase = false;
  bool listPendingOnly = false;
  String? isolatePendingDir;
  String? restorePendingDir;
  bool preflightHosted = false;
  bool postflightHosted = false;
  String? remoteListFilePath;
  String? reportOutPath;
  bool quiet = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--migrations-dir' && i + 1 < args.length) {
      migrationsDirPath = args[++i];
    } else if (arg == '--base-ref' && i + 1 < args.length) {
      baseRef = args[++i];
    } else if (arg == '--no-base') {
      baseRef = null;
    } else if (arg == '--require-base') {
      requireBase = true;
    } else if (arg == '--list-pending') {
      listPendingOnly = true;
    } else if (arg == '--isolate-pending' && i + 1 < args.length) {
      isolatePendingDir = args[++i];
    } else if (arg == '--restore-pending' && i + 1 < args.length) {
      restorePendingDir = args[++i];
    } else if (arg == '--preflight-hosted') {
      preflightHosted = true;
    } else if (arg == '--postflight-hosted') {
      postflightHosted = true;
    } else if (arg == '--remote-list-file' && i + 1 < args.length) {
      remoteListFilePath = args[++i];
    } else if (arg == '--report-out' && i + 1 < args.length) {
      reportOutPath = args[++i];
    } else if (arg == '--quiet') {
      quiet = true;
    } else if (arg == '--help' || arg == '-h') {
      _printHelp();
      exit(0);
    }
  }

  // Handle restore-pending operation
  if (restorePendingDir != null) {
    _handleRestorePending(
      sourceDirPath: restorePendingDir,
      targetDirPath: migrationsDirPath,
      quiet: quiet,
    );
    exit(0);
  }


  final migrationsDir = Directory(migrationsDirPath);
  if (!migrationsDir.existsSync()) {
    stderr.writeln('❌ Error: Migrations directory not found at: $migrationsDirPath');
    exit(1);
  }

  // Read and parse all local migrations
  final localFiles = migrationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList();

  localFiles.sort((a, b) {
    final aName = a.uri.pathSegments.last;
    final bName = b.uri.pathSegments.last;
    return aName.compareTo(bName);
  });

  final currentRecords = <MigrationRecord>[];
  final invalidFilenames = <String>[];
  final currentFilesMap = <String, String>{};

  for (final file in localFiles) {
    final filename = file.uri.pathSegments.last;
    final content = file.readAsStringSync();
    currentFilesMap[filename] = content;

    final record = MigrationRecord.parse(
      filename: filename,
      path: file.path,
      content: content,
    );

    if (record != null) {
      currentRecords.add(record);
    } else {
      invalidFilenames.add(filename);
    }
  }

  final validator = const MigrationHistoryValidator();
  final allIssues = <MigrationValidationIssue>[];

  // 1. Run local static checks
  final localIssues = validator.validateLocalRecords(
    currentRecords,
    invalidFilenames: invalidFilenames,
  );
  allIssues.addAll(localIssues);

  // 2. Fetch baseline from git if requested
  Map<String, String>? baselineFilesMap;
  String? resolvedBaseRef;

  if (baseRef != null) {
    resolvedBaseRef = _resolveGitBaseRef(baseRef);
    if (resolvedBaseRef != null) {
      baselineFilesMap = _loadGitBaselineFiles(
        baseRef: resolvedBaseRef,
        migrationsDirPath: migrationsDirPath,
      );
    } else if (requireBase || preflightHosted || postflightHosted) {
      stderr.writeln('❌ Error: Could not resolve git base reference "$baseRef".');
      stderr.writeln('Production deployment gates require a valid Git baseline to verify migration immutability.');
      exit(1);
    } else if (!quiet) {
      stdout.writeln('ℹ️ Note: Git base ref "$baseRef" not found. Falling back to local verification only.');
    }
  }

  List<String> pendingMigrations = [];
  if (baselineFilesMap != null) {
    // 3. Compare current files against baseline
    final baselineIssues = validator.compareWithBaseline(
      baselineFiles: baselineFilesMap,
      currentFiles: currentFilesMap,
    );
    allIssues.addAll(baselineIssues);

    pendingMigrations = validator.findPendingMigrations(
      baselineFilenames: baselineFilesMap.keys.toSet(),
      currentFilenames: currentFilesMap.keys,
    );
  }

  // Handle list-pending
  if (listPendingOnly) {
    for (final filename in pendingMigrations) {
      stdout.writeln(filename);
    }
    exit(0);
  }

  // Handle isolate-pending operation
  if (isolatePendingDir != null) {
    _handleIsolatePending(
      pendingMigrations: pendingMigrations,
      migrationsDirPath: migrationsDirPath,
      targetDirPath: isolatePendingDir,
      quiet: quiet,
    );
    exit(0);
  }

  // Handle hosted preflight or postflight gate if requested
  if (preflightHosted || postflightHosted) {
    _handleHostedGate(
      isPreflight: preflightHosted,
      isPostflight: postflightHosted,
      remoteListFilePath: remoteListFilePath,
      reportOutPath: reportOutPath,
      currentRecords: currentRecords,
      allIssues: allIssues,
      validator: validator,
      quiet: quiet,
    );
    // _handleHostedGate will report and exit appropriately
    return;
  }

  // Display verification report for local static / git baseline checks
  if (!quiet) {
    stdout.writeln('====================================================');
    stdout.writeln('  Supabase Migration Immutability & Upgrade Gate    ');
    stdout.writeln('====================================================');
    stdout.writeln('📁 Migrations Directory: $migrationsDirPath');
    stdout.writeln('📊 Local Migrations:     ${currentRecords.length} file(s)');
    if (resolvedBaseRef != null && baselineFilesMap != null) {
      stdout.writeln('🌿 Git Base Reference:   $resolvedBaseRef');
      stdout.writeln('🔒 Baseline Migrations:  ${baselineFilesMap.length} file(s)');
      stdout.writeln('🚀 Pending (New) Files:  ${pendingMigrations.length} file(s)');
      if (pendingMigrations.isNotEmpty) {
        for (final pending in pendingMigrations) {
          stdout.writeln('   • $pending');
        }
      }
    }
    stdout.writeln('----------------------------------------------------');
  }

  if (allIssues.isNotEmpty) {
    for (final issue in allIssues) {
      if (issue.isError) {
        stderr.writeln('❌ ${issue.toString()}');
      } else {
        stdout.writeln('⚠️ ${issue.toString()}');
      }
    }
    stdout.writeln('====================================================');
    final errorCount = allIssues.where((i) => i.isError).length;
    if (errorCount > 0) {
      stderr.writeln('FAILED: $errorCount migration immutability violation(s) detected.');
      stderr.writeln('Rule: Once merged into main, migrations are immutable.');
      stderr.writeln('      Never edit or delete an existing migration in-place.');
      stderr.writeln('      Always add a new sequential migration instead.');
      exit(1);
    }
  }

  if (reportOutPath != null) {
    _writeSanitizedReport(
      reportOutPath: reportOutPath,
      mode: 'local_baseline',
      localCount: currentRecords.length,
      remoteCount: 0,
      appliedVersions: currentRecords.map((r) => r.timestamp).toList(),
      pendingVersions: pendingMigrations,
      remoteOnlyVersions: [],
      missingRemoteVersions: [],
      issues: allIssues,
      status: allIssues.any((i) => i.isError) ? 'FAILED' : 'PASSED',
    );
  }

  if (!quiet) {
    stdout.writeln('✅ All migration invariants verified cleanly.');
    stdout.writeln('   - Monotonic 14-digit timestamps valid.');
    stdout.writeln('   - Strict append-only history preserved.');
    stdout.writeln('====================================================');
  }
}


String? _resolveGitBaseRef(String candidate) {
  try {
    final candidates = [
      candidate,
      if (Platform.environment['GITHUB_BASE_REF'] != null) ...[
        'origin/${Platform.environment['GITHUB_BASE_REF']}',
        Platform.environment['GITHUB_BASE_REF']!,
      ],
      if (candidate == 'origin/main') 'main',
      'origin/HEAD',
      'HEAD~1',
    ];

    for (final c in candidates) {
      final result = Process.runSync(
        'git',
        ['rev-parse', '--verify', c],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode == 0) return c;
    }

    // Try finding merge base with HEAD if remote ref exists
    final mergeBaseResult = Process.runSync(
      'git',
      ['merge-base', 'HEAD', candidate],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (mergeBaseResult.exitCode == 0) return candidate;
  } catch (_) {
    return null;
  }
  return null;
}

Map<String, String> _loadGitBaselineFiles({
  required String baseRef,
  required String migrationsDirPath,
}) {
  final filesMap = <String, String>{};

  // Convert directory path to git relative path format with forward slashes
  final gitDirPath = migrationsDirPath.replaceAll('\\', '/');

  final listResult = Process.runSync(
    'git',
    [
      'ls-tree',
      '-r',
      '--name-only',
      baseRef,
      gitDirPath,
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (listResult.exitCode != 0) {
    return filesMap;
  }

  final lines = (listResult.stdout as String).split('\n');
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || !line.endsWith('.sql')) continue;

    final filename = line.split('/').last;

    // Fetch file contents at baseRef
    final showResult = Process.runSync(
      'git',
      [
        'show',
        '$baseRef:$line',
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (showResult.exitCode == 0) {
      filesMap[filename] = showResult.stdout as String;
    }
  }

  return filesMap;
}

void _handleIsolatePending({
  required List<String> pendingMigrations,
  required String migrationsDirPath,
  required String targetDirPath,
  required bool quiet,
}) {
  final targetDir = Directory(targetDirPath);
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
  }

  if (pendingMigrations.isEmpty) {
    if (!quiet) stdout.writeln('ℹ️ No pending migrations to isolate.');
    return;
  }

  for (final filename in pendingMigrations) {
    final sourceFile = File('$migrationsDirPath/$filename');
    final destFile = File('${targetDir.path}/$filename');
    if (sourceFile.existsSync()) {
      sourceFile.copySync(destFile.path);
      sourceFile.deleteSync();
      if (!quiet) stdout.writeln('📦 Isolated pending migration: $filename');
    }
  }

  if (!quiet) {
    stdout.writeln('✅ Isolated ${pendingMigrations.length} pending migration(s) into $targetDirPath.');
  }
}

void _handleRestorePending({
  required String sourceDirPath,
  required String targetDirPath,
  required bool quiet,
}) {
  final sourceDir = Directory(sourceDirPath);
  if (!sourceDir.existsSync()) {
    if (!quiet) stdout.writeln('ℹ️ No isolated migrations directory found at $sourceDirPath.');
    return;
  }

  final files = sourceDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList();

  if (files.isEmpty) {
    if (!quiet) stdout.writeln('ℹ️ No isolated migrations found in $sourceDirPath.');
    return;
  }

  final targetDir = Directory(targetDirPath);
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
  }

  for (final file in files) {
    final filename = file.uri.pathSegments.last;
    final destFile = File('${targetDir.path}/$filename');
    file.copySync(destFile.path);
    file.deleteSync();
    if (!quiet) stdout.writeln('🔄 Restored pending migration: $filename');
  }

  try {
    sourceDir.deleteSync(recursive: true);
  } catch (_) {}

  if (!quiet) {
    stdout.writeln('✅ Restored ${files.length} pending migration(s) into $targetDirPath.');
  }
}

void _handleHostedGate({
  required bool isPreflight,
  required bool isPostflight,
  required String? remoteListFilePath,
  required String? reportOutPath,
  required List<MigrationRecord> currentRecords,
  required List<MigrationValidationIssue> allIssues,
  required MigrationHistoryValidator validator,
  required bool quiet,
}) {
  final mode = isPostflight ? 'postflight' : 'preflight';

  if (!quiet) {
    stdout.writeln('====================================================');
    stdout.writeln('  Supabase Hosted Migration Version Gate ($mode)   ');
    stdout.writeln('====================================================');
    stdout.writeln('📊 Local Migrations:  ${currentRecords.length} file(s)');
  }

  // 1. Fetch remote migration output
  String cliOutput;
  try {
    cliOutput = _fetchRemoteMigrationListOutput(remoteListFilePath);
  } catch (e) {
    stderr.writeln('❌ Error reading remote migration list: $e');
    stderr.writeln('Fatal: Cannot verify hosted migration history. Halting gate.');
    if (reportOutPath != null) {
      _writeSanitizedReport(
        reportOutPath: reportOutPath,
        mode: mode,
        localCount: currentRecords.length,
        remoteCount: 0,
        appliedVersions: [],
        pendingVersions: [],
        remoteOnlyVersions: [],
        missingRemoteVersions: [],
        issues: [
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'remote_ledger_read_failure',
            filename: 'schema_migrations',
            message: e.toString(),
          )
        ],
        status: 'FAILED',
      );
    }
    exit(1);
  }

  // 2. Parse table output
  Map<String, List<String>> parsed;
  try {
    parsed = MigrationHistoryValidator.parseMigrationListOutput(cliOutput);
  } catch (e) {
    stderr.writeln('❌ Error parsing migration list table: $e');
    if (reportOutPath != null) {
      _writeSanitizedReport(
        reportOutPath: reportOutPath,
        mode: mode,
        localCount: currentRecords.length,
        remoteCount: 0,
        appliedVersions: [],
        pendingVersions: [],
        remoteOnlyVersions: [],
        missingRemoteVersions: [],
        issues: [
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'migration_list_parse_failure',
            filename: 'schema_migrations',
            message: e.toString(),
          )
        ],
        status: 'FAILED',
      );
    }
    exit(1);
  }

  final remoteVersions = parsed['remote'] ?? [];
  if (!quiet) {
    stdout.writeln('📡 Remote Migrations: ${remoteVersions.length} applied record(s)');
    stdout.writeln('----------------------------------------------------');
  }

  // 3. Run comparison
  final HostedMigrationComparisonResult result;
  if (isPostflight) {
    result = validator.compareHostedPostflight(
      localRecords: currentRecords,
      remoteVersions: remoteVersions,
    );
  } else {
    result = validator.compareWithHosted(
      localRecords: currentRecords,
      remoteVersions: remoteVersions,
    );
  }

  final totalIssues = <MigrationValidationIssue>[...allIssues, ...result.issues];

  if (totalIssues.isNotEmpty) {
    for (final issue in totalIssues) {
      if (issue.isError) {
        stderr.writeln('❌ ${issue.toString()}');
      } else {
        stdout.writeln('⚠️ ${issue.toString()}');
      }
    }
  }

  final hasErrors = totalIssues.any((i) => i.isError);

  if (!quiet) {
    stdout.writeln('----------------------------------------------------');
    stdout.writeln('Applied on Remote: ${result.appliedVersions.length} migration(s)');
    stdout.writeln('Pending to Deploy: ${result.pendingVersions.length} migration(s)');
    if (result.pendingVersions.isNotEmpty) {
      for (final p in result.pendingVersions) {
        stdout.writeln('   • $p');
      }
    }
    if (result.remoteOnlyVersions.isNotEmpty) {
      stdout.writeln('Remote-Only:       ${result.remoteOnlyVersions.length} migration(s)');
      for (final r in result.remoteOnlyVersions) {
        stdout.writeln('   ❌ $r (UNKNOWN HOSTED ALIAS)');
      }
    }
    if (result.missingRemoteVersions.isNotEmpty) {
      stdout.writeln('Missing on Remote: ${result.missingRemoteVersions.length} historical migration(s)');
      for (final m in result.missingRemoteVersions) {
        stdout.writeln('   ❌ $m (SKIPPED OR OUT OF SYNC)');
      }
    }
  }

  // 4. Save sanitized report if path provided
  if (reportOutPath != null) {
    _writeSanitizedReport(
      reportOutPath: reportOutPath,
      mode: mode,
      localCount: currentRecords.length,
      remoteCount: remoteVersions.length,
      appliedVersions: result.appliedVersions,
      pendingVersions: result.pendingVersions,
      remoteOnlyVersions: result.remoteOnlyVersions,
      missingRemoteVersions: result.missingRemoteVersions,
      issues: totalIssues,
      status: hasErrors ? 'FAILED' : 'PASSED',
    );
  }

  stdout.writeln('====================================================');
  if (hasErrors) {
    stderr.writeln('FAILED: Hosted migration gate detected violation(s).');
    stderr.writeln('Rule: Production database must match exact canonical migration versions.');
    stderr.writeln('      No timestamp aliases, remote-only entries, or partial deployments allowed.');
    stderr.writeln('      Never run migration repair to mask a version difference.');
    exit(1);
  }

  if (isPostflight) {
    stdout.writeln('✅ Post-deployment check PASSED: exact 1:1 version parity confirmed.');
  } else {
    if (result.hasPending) {
      stdout.writeln('✅ Pre-deployment check PASSED: valid pending append-only suffix ready for push.');
    } else {
      stdout.writeln('✅ Pre-deployment check PASSED: remote database is fully up to date.');
    }
  }
  stdout.writeln('====================================================');
}

String _fetchRemoteMigrationListOutput(String? fileOverridePath) {
  if (fileOverridePath != null) {
    final f = File(fileOverridePath);
    if (!f.existsSync()) {
      throw FileSystemException('Remote migration list file not found', fileOverridePath);
    }
    return f.readAsStringSync();
  }

  final result = Process.runSync(
    'supabase',
    ['migration', 'list', '--linked'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw ProcessException(
      'supabase',
      ['migration', 'list', '--linked'],
      'Process failed with exit code ${result.exitCode}:\n${result.stderr}\n${result.stdout}',
      result.exitCode,
    );
  }

  return result.stdout.toString();
}

void _writeSanitizedReport({
  required String reportOutPath,
  required String mode,
  required int localCount,
  required int remoteCount,
  required List<String> appliedVersions,
  required List<String> pendingVersions,
  required List<String> remoteOnlyVersions,
  required List<String> missingRemoteVersions,
  required List<MigrationValidationIssue> issues,
  required String status,
}) {
  final projectRef = _getSanitizedProjectRef();
  final gitCommit = _getGitCommit();
  final cliVersion = _getSupabaseCliVersion();

  final report = {
    'schema_version': '1.0',
    'mode': mode,
    'status': status,
    'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
    'project_ref': projectRef,
    'git_commit': gitCommit,
    'supabase_cli_version': cliVersion,
    'summary': {
      'local_migration_count': localCount,
      'remote_applied_count': remoteCount,
      'pending_to_apply_count': pendingVersions.length,
      'remote_only_count': remoteOnlyVersions.length,
      'missing_remote_count': missingRemoteVersions.length,
      'error_count': issues.where((i) => i.isError).length,
      'warning_count': issues.where((i) => i.isWarning).length,
    },
    'applied_versions': appliedVersions,
    'pending_versions': pendingVersions,
    'remote_only_versions': remoteOnlyVersions,
    'missing_remote_versions': missingRemoteVersions,
    'issues': issues.map((i) => {
      'severity': i.severity.name,
      'rule': i.rule,
      'filename': i.filename,
      'message': i.message,
    }).toList(),
  };

  final outFile = File(reportOutPath);
  final parent = outFile.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }

  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );

  stdout.writeln('📄 Sanitized status report saved: $reportOutPath');
}

String _getSanitizedProjectRef() {
  final envRef = Platform.environment['SUPABASE_PROJECT_REF'] ??
      Platform.environment['PROJECT_REF'];
  if (envRef != null && envRef.trim().isNotEmpty) {
    return envRef.trim();
  }

  final refFile = File('supabase/.temp/project-ref');
  if (refFile.existsSync()) {
    final content = refFile.readAsStringSync().trim();
    if (content.isNotEmpty) return content;
  }

  return 'unknown_project';
}

String _getGitCommit() {
  try {
    final result = Process.runSync('git', ['rev-parse', 'HEAD']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
  } catch (_) {}
  return 'unknown_commit';
}

String _getSupabaseCliVersion() {
  try {
    final result = Process.runSync('supabase', ['--version'], runInShell: true);
    if (result.exitCode == 0) {
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.contains('A new version')) {
          return trimmed;
        }
      }
    }
  } catch (_) {}
  return 'unknown_cli';
}

void _printHelp() {
  stdout.writeln('''
Supabase Migration Immutability & Upgrade Gate

Verifies that migration files follow the canonical pattern, maintain monotonic
timestamp ordering, and strictly preserve append-only immutability against an
authoritative baseline ref (default: origin/main).

Options:
  --base-ref <ref>            Git reference to compare against (default: origin/main).
  --no-base                   Disable git baseline comparison and perform local checks only.
  --require-base              Fail if the git base reference cannot be resolved.
  --migrations-dir <dir>      Path to migrations folder (default: supabase/migrations).
  --list-pending              Print pending migration filenames (one per line) and exit.
  --isolate-pending <dir>     Move pending migrations into target folder to stage baseline.
  --restore-pending <dir>     Restore isolated pending migrations back into migrations folder.
  --preflight-hosted          Run pre-deployment version comparison against linked Supabase ledger.
  --postflight-hosted         Run post-deployment exact 1:1 parity check against linked Supabase ledger.
  --remote-list-file <path>   Use local file containing `supabase migration list` output instead of live CLI.
  --report-out <path>         Write sanitized JSON deployment/status report.
  --quiet                     Suppress informational output.
  -h, --help                  Show this help message.
''');
}

