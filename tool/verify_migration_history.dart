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
void main(List<String> args) async {
  String migrationsDirPath = 'supabase/migrations';
  String? baseRef = 'origin/main';
  bool requireBase = false;
  bool listPendingOnly = false;
  String? isolatePendingDir;
  String? restorePendingDir;
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
    } else if (requireBase) {
      stderr.writeln('❌ Error: Could not resolve git base reference "$baseRef".');
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

  // Display verification report
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
  --quiet                     Suppress informational output.
  -h, --help                  Show this help message.
''');
}
