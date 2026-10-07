/// Severity of a migration validation diagnostic issue.
enum MigrationIssueSeverity {
  error,
  warning,
}

/// Diagnostic issue identified during migration history validation.
class MigrationValidationIssue {
  final MigrationIssueSeverity severity;
  final String rule;
  final String filename;
  final String message;

  const MigrationValidationIssue({
    required this.severity,
    required this.rule,
    required this.filename,
    required this.message,
  });

  bool get isError => severity == MigrationIssueSeverity.error;
  bool get isWarning => severity == MigrationIssueSeverity.warning;

  @override
  String toString() {
    final prefix = isError ? 'ERROR' : 'WARNING';
    return '[$prefix] ($rule) $filename: $message';
  }
}

/// Representation of an immutable Supabase migration file.
class MigrationRecord {
  final String filename;
  final String timestamp;
  final String name;
  final String path;
  final int sizeBytes;
  final String content;

  const MigrationRecord({
    required this.filename,
    required this.timestamp,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.content,
  });

  /// Canonical Supabase migration pattern: 14-digit timestamp followed by descriptive name.
  /// Example: 20261009000004_restore_rpc_contracts_and_close_enrollment_oracle.sql
  static final RegExp filenamePattern =
      RegExp(r'^([0-9]{14})_([a-zA-Z0-9_]+)\.sql$');

  /// Attempts to parse a migration filename and its contents into a record.
  static MigrationRecord? parse({
    required String filename,
    required String path,
    required String content,
  }) {
    final match = filenamePattern.firstMatch(filename);
    if (match == null) return null;

    return MigrationRecord(
      filename: filename,
      timestamp: match.group(1)!,
      name: match.group(2)!,
      path: path,
      sizeBytes: content.length,
      content: content,
    );
  }
}

/// Complete report returned by the migration history validator.
class MigrationValidationReport {
  final List<MigrationValidationIssue> issues;
  final List<MigrationRecord> records;
  final List<String> baselineFilenames;
  final List<String> pendingFilenames;

  const MigrationValidationReport({
    required this.issues,
    required this.records,
    required this.baselineFilenames,
    required this.pendingFilenames,
  });

  bool get isValid => issues.every((i) => !i.isError);
  int get errorCount => issues.where((i) => i.isError).length;
  int get warningCount => issues.where((i) => i.isWarning).length;
}

/// Core engine validating Supabase migration history immutability and append-only constraints.
class MigrationHistoryValidator {
  const MigrationHistoryValidator();

  /// Normalizes SQL text to prevent false positives from CRLF / LF line endings
  /// or subtle trailing whitespace introduced across cross-platform environments.
  static String normalizeSql(String sql) {
    var text = sql;
    // Strip UTF-8 byte order mark (BOM) if present
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    // Standardize newline characters
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Strip trailing space on each line and ensure trailing newline
    final lines = text.split('\n').map((l) => l.trimRight()).toList();

    // Remove trailing empty lines at end of file to normalize EOF
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    return '${lines.join('\n')}\n';
  }

  /// Validates standalone static invariants on local migration records.
  List<MigrationValidationIssue> validateLocalRecords(
    List<MigrationRecord> records, {
    List<String> invalidFilenames = const [],
  }) {
    final issues = <MigrationValidationIssue>[];

    // 1. Flag invalid filenames
    for (final filename in invalidFilenames) {
      issues.add(
        MigrationValidationIssue(
          severity: MigrationIssueSeverity.error,
          rule: 'invalid_filename_format',
          filename: filename,
          message:
              'Migration filename does not match canonical pattern: <14-digit timestamp>_<name>.sql (e.g. 20261009000004_fix.sql).',
        ),
      );
    }

    // 2. Validate empty files and duplicate timestamps
    final seenTimestamps = <String, MigrationRecord>{};
    for (final record in records) {
      if (record.content.trim().isEmpty) {
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'empty_migration_file',
            filename: record.filename,
            message: 'Migration file has no SQL content (0 bytes or only whitespace).',
          ),
        );
      }

      if (seenTimestamps.containsKey(record.timestamp)) {
        final existing = seenTimestamps[record.timestamp]!;
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'duplicate_timestamp',
            filename: record.filename,
            message:
                'Timestamp collision: timestamp ${record.timestamp} is already used by ${existing.filename}. Migration timestamps must be unique.',
          ),
        );
      } else {
        seenTimestamps[record.timestamp] = record;
      }
    }

    // 3. Validate chronological ordering
    // In Supabase, migrations are sorted alphabetically by filename.
    // Alphabetical order must match ascending timestamp order.
    for (var i = 1; i < records.length; i++) {
      final prev = records[i - 1];
      final curr = records[i];

      if (curr.timestamp.compareTo(prev.timestamp) < 0) {
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'out_of_order_timestamp',
            filename: curr.filename,
            message:
                'Migration timestamp ${curr.timestamp} is earlier than previous migration ${prev.timestamp} (${prev.filename}). Migrations must be ordered monotonically.',
          ),
        );
      }
    }

    return issues;
  }

  /// Compares current branch migration files against an authoritative baseline (e.g. origin/main)
  /// to enforce strict immutability of previously merged migrations.
  List<MigrationValidationIssue> compareWithBaseline({
    required Map<String, String> baselineFiles,
    required Map<String, String> currentFiles,
  }) {
    final issues = <MigrationValidationIssue>[];

    // Find the latest timestamp present in baseline
    String maxBaseTimestamp = '';
    for (final filename in baselineFiles.keys) {
      final match = MigrationRecord.filenamePattern.firstMatch(filename);
      if (match != null) {
        final ts = match.group(1)!;
        if (ts.compareTo(maxBaseTimestamp) > 0) {
          maxBaseTimestamp = ts;
        }
      }
    }

    // 1. Check for deleted baseline migrations
    for (final baseFilename in baselineFiles.keys) {
      if (!currentFiles.containsKey(baseFilename)) {
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'deleted_baseline_migration',
            filename: baseFilename,
            message:
                'Baseline migration was deleted. Migrations already merged to main must remain permanently immutable and must never be removed.',
          ),
        );
      }
    }

    // 2. Check for in-place modifications to baseline migrations
    for (final entry in baselineFiles.entries) {
      final filename = entry.key;
      final baseContent = entry.value;

      if (currentFiles.containsKey(filename)) {
        final currentContent = currentFiles[filename]!;
        final normBase = normalizeSql(baseContent);
        final normCurrent = normalizeSql(currentContent);

        if (normBase != normCurrent) {
          issues.add(
            MigrationValidationIssue(
              severity: MigrationIssueSeverity.error,
              rule: 'modified_baseline_migration',
              filename: filename,
              message:
                  'Baseline migration was modified in-place! Migrations already merged into main are immutable because already-deployed databases will skip them. You must add a new sequential migration instead of editing an existing one.',
            ),
          );
        }
      }
    }

    // 3. Check for newly introduced migrations that have retrofitted/out-of-order timestamps
    for (final filename in currentFiles.keys) {
      if (!baselineFiles.containsKey(filename)) {
        final match = MigrationRecord.filenamePattern.firstMatch(filename);
        if (match != null && maxBaseTimestamp.isNotEmpty) {
          final newTimestamp = match.group(1)!;
          if (newTimestamp.compareTo(maxBaseTimestamp) <= 0) {
            issues.add(
              MigrationValidationIssue(
                severity: MigrationIssueSeverity.error,
                rule: 'backdated_new_migration',
                filename: filename,
                message:
                    'New migration has timestamp $newTimestamp which is <= latest baseline migration ($maxBaseTimestamp). New migrations must be appended with a strictly newer timestamp.',
              ),
            );
          }
        }
      }
    }

    return issues;
  }

  /// Identifies all newly added migrations in current files that do not exist in the baseline.
  List<String> findPendingMigrations({
    required Set<String> baselineFilenames,
    required Iterable<String> currentFilenames,
  }) {
    final pending = currentFilenames
        .where((f) => !baselineFilenames.contains(f) && MigrationRecord.filenamePattern.hasMatch(f))
        .toList();
    pending.sort();
    return pending;
  }
}
