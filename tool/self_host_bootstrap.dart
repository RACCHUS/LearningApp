import 'dart:io';

/// Model representing a single discovered migration file.
class MigrationItem {
  final String version;
  final String name;
  final String filename;
  final File file;

  MigrationItem({
    required this.version,
    required this.name,
    required this.filename,
    required this.file,
  });
}

/// Result of scanning and validating a migrations directory.
class MigrationScanResult {
  final List<MigrationItem> migrations;
  final List<String> errors;
  final List<String> warnings;

  MigrationScanResult({
    required this.migrations,
    required this.errors,
    required this.warnings,
  });

  bool get isValid => errors.isEmpty;
}

/// Engine for discovering, validating, and bundling migrations for turnkey self-hosting.
class SelfHostBootstrap {
  static final RegExp _regex = RegExp(r'^(\d{14})_(.+)\.sql$');

  /// Scans [migrationsDir] and asserts strict monotonicity and zero duplicate versions.
  static MigrationScanResult scanAndValidate(String migrationsDir) {
    final dir = Directory(migrationsDir);
    if (!dir.existsSync()) {
      return MigrationScanResult(
        migrations: [],
        errors: ['Migrations directory not found at $migrationsDir'],
        warnings: [],
      );
    }

    final migrationFiles = <MigrationItem>[];
    final warnings = <String>[];
    final errors = <String>[];

    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.sql')) {
        final filename = entity.uri.pathSegments.last;
        final match = _regex.firstMatch(filename);
        if (match != null) {
          final version = match.group(1)!;
          final name = match.group(2)!;
          migrationFiles.add(MigrationItem(
            version: version,
            name: name,
            filename: filename,
            file: entity,
          ));
        } else {
          warnings.add('Skipping non-conforming file in migrations dir: $filename');
        }
      }
    }

    // Sort strictly by 14-digit timestamp
    migrationFiles.sort((a, b) => a.version.compareTo(b.version));

    // Validate ordering and duplicates
    final seenVersions = <String>{};
    String? prevVersion;
    for (final m in migrationFiles) {
      if (seenVersions.contains(m.version)) {
        errors.add('Duplicate migration version timestamp found: ${m.version}');
      }
      seenVersions.add(m.version);
      if (prevVersion != null && m.version.compareTo(prevVersion) <= 0) {
        errors.add('Non-monotonic migration timestamp order: ${m.version} after $prevVersion');
      }
      prevVersion = m.version;
    }

    return MigrationScanResult(
      migrations: migrationFiles,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Compiles all [migrations] into a single deterministic transactional SQL bundle.
  static String generateBundleSql(List<MigrationItem> migrations) {
    final sb = StringBuffer();
    sb.writeln('-- ====================================================================');
    sb.writeln('-- LearningApp Consolidated Turnkey Self-Hosting Database Schema Bundle');
    sb.writeln('-- Automatically compiled from ${migrations.length} immutable migrations');
    sb.writeln('-- Generated: ${DateTime.now().toUtc().toIso8601String()}');
    sb.writeln('-- ====================================================================');
    sb.writeln();
    sb.writeln('BEGIN;');
    sb.writeln();

    for (var i = 0; i < migrations.length; i++) {
      final m = migrations[i];
      sb.writeln('-- --------------------------------------------------------------------');
      sb.writeln('-- [${i + 1}/${migrations.length}] Migration: ${m.filename}');
      sb.writeln('-- --------------------------------------------------------------------');
      final content = m.file.readAsStringSync();
      sb.writeln(content.trim());
      sb.writeln();
      sb.writeln('INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES (\'${m.version}\', \'${m.name}\') ON CONFLICT (version) DO NOTHING;');
      sb.writeln();
    }

    sb.writeln('COMMIT;');
    sb.writeln();
    return sb.toString();
  }
}

/// CLI Entrypoint
void main(List<String> args) async {
  String migrationsDir = 'supabase/migrations';
  String? bundleOutputPath;
  bool dryRun = false;
  bool checkSequential = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--migrations-dir' && i + 1 < args.length) {
      migrationsDir = args[++i];
    } else if (arg == '--generate-bundle' && i + 1 < args.length) {
      bundleOutputPath = args[++i];
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--check-sequential') {
      checkSequential = true;
    } else if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
    }
  }

  final scanResult = SelfHostBootstrap.scanAndValidate(migrationsDir);

  for (final warning in scanResult.warnings) {
    stderr.writeln('⚠️ Warning: $warning');
  }

  if (!scanResult.isValid) {
    for (final error in scanResult.errors) {
      stderr.writeln('❌ Error: $error');
    }
    exit(1);
  }

  stdout.writeln('====================================================');
  stdout.writeln('  LearningApp Turnkey Self-Host Migration Bootstrap ');
  stdout.writeln('====================================================');
  stdout.writeln('📦 Discovered ${scanResult.migrations.length} valid migrations.');
  if (scanResult.migrations.isNotEmpty) {
    stdout.writeln('   • Baseline timestamp: ${scanResult.migrations.first.version} (${scanResult.migrations.first.name})');
    stdout.writeln('   • Latest timestamp:   ${scanResult.migrations.last.version} (${scanResult.migrations.last.name})');
  }

  if (checkSequential) {
    stdout.writeln('✅ Sequential ordering check passed cleanly.');
    exit(0);
  }

  if (bundleOutputPath != null) {
    final outputFile = File(bundleOutputPath);
    outputFile.parent.createSync(recursive: true);

    final sql = SelfHostBootstrap.generateBundleSql(scanResult.migrations);
    outputFile.writeAsStringSync(sql);
    stdout.writeln('✅ Consolidated bundle successfully written to: $bundleOutputPath (${(outputFile.lengthSync() / 1024).toStringAsFixed(1)} KB)');
  }

  if (dryRun) {
    stdout.writeln('🔍 Dry-run complete. All ${scanResult.migrations.length} migrations validated.');
  }
}

void _printUsage() {
  stdout.writeln('''
Usage: dart run tool/self_host_bootstrap.dart [options]

Options:
  --migrations-dir <dir>    Path to migrations directory (default: supabase/migrations)
  --generate-bundle <path>  Generate consolidated SQL schema bundle at <path>
  --check-sequential        Verify sequential ordering without outputting files
  --dry-run                 Run validation in dry-run mode
  --help, -h                Show this help message
''');
}
