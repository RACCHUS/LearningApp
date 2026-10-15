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

  /// Parses table output from `supabase migration list` (including `--linked`).
  ///
  /// Expected table header contains `Local` and `Remote`.
  /// Lines format: ` <local_version> | <remote_version> | <timestamp> `
  ///
  /// Throws [FormatException] if the output indicates an error, connection failure,
  /// or does not contain the expected migration table headers. Never returns an
  /// empty list when an error occurs.
  static Map<String, List<String>> parseMigrationListOutput(String output) {
    final lower = output.toLowerCase();
    if (lower.contains('error:') ||
        lower.contains('failed to') ||
        lower.contains('fatal:') ||
        lower.contains('cannot find') ||
        lower.contains('connection refused') ||
        lower.contains('permission denied') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      throw FormatException('Supabase migration list command failed with error: $output');
    }

    final rawLines = output.split('\n');
    final lines = rawLines.map((l) => l.trim()).toList();
    final headerIndex = lines.indexWhere(
      (l) => l.contains('Local') && l.contains('Remote'),
    );

    if (headerIndex == -1) {
      throw FormatException(
        'Invalid supabase migration list output: missing table header. Output was:\n$output',
      );
    }

    // Verify table divider immediately follows header (or next non-empty line)
    var dividerIndex = -1;
    for (var i = headerIndex + 1; i < lines.length; i++) {
      if (lines[i].isNotEmpty) {
        dividerIndex = i;
        break;
      }
    }

    if (dividerIndex == -1 ||
        (!lines[dividerIndex].startsWith('-') && !lines[dividerIndex].contains('|'))) {
      throw FormatException(
        'Invalid supabase migration list output: missing table divider after header.',
      );
    }

    final localVersions = <String>[];
    final remoteVersions = <String>[];
    final tsRegex = RegExp(r'^[0-9]{14}$');
    var inTable = true;

    for (var i = dividerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        // Empty line indicates end of table rows
        inTable = false;
        continue;
      }

      if (!inTable) {
        // Outside table rows, only accept known CLI notices/banners
        if (line.startsWith('A new version of Supabase CLI') ||
            line.startsWith('We recommend updating') ||
            line.startsWith('http')) {
          continue;
        }
        // If unexpected text appears after table, fail closed
        throw FormatException(
          'Unexpected trailing output after migration table: "$line"',
        );
      }

      // Inside table rows: MUST be a table row with column delimiter '|'
      if (!line.contains('|')) {
        throw FormatException(
          'Malformed migration list row (missing pipe delimiter |): "$line"',
        );
      }

      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.length < 2) {
        throw FormatException(
          'Malformed migration list row (expected at least 2 columns, got ${parts.length}): "$line"',
        );
      }

      final localCol = parts[0];
      final remoteCol = parts[1];

      // Validate localCol format
      if (localCol.isNotEmpty && !tsRegex.hasMatch(localCol)) {
        throw FormatException(
          'Malformed local migration version "$localCol" (must be 14 digits): "$line"',
        );
      }

      // Validate remoteCol format
      if (remoteCol.isNotEmpty && !tsRegex.hasMatch(remoteCol)) {
        throw FormatException(
          'Malformed remote migration version "$remoteCol" (must be 14 digits): "$line"',
        );
      }

      // Both cannot be empty
      if (localCol.isEmpty && remoteCol.isEmpty) {
        throw FormatException(
          'Encountered empty migration row with no local or remote version: "$line"',
        );
      }

      if (localCol.isNotEmpty) {
        localVersions.add(localCol);
      }
      if (remoteCol.isNotEmpty) {
        remoteVersions.add(remoteCol);
      }
    }

    if (localVersions.isEmpty && remoteVersions.isEmpty) {
      throw FormatException('Supabase migration list returned 0 migration records.');
    }

    return {
      'local': localVersions,
      'remote': remoteVersions,
    };
  }

  /// Compares local migration records with remote hosted migration versions for pre-deployment gate.
  ///
  /// Invariants:
  /// 1. Remote versions must be valid 14-digit timestamps.
  /// 2. Remote versions must be monotonic and have no duplicates.
  /// 3. All remote versions must exist as canonical local migrations (blocks remote-only aliases).
  /// 4. All local migrations with timestamp <= latest remote version must be recorded as applied on remote (blocks missing historical).
  /// 5. Any local migrations with timestamp > latest remote version are classified as pending.
  /// 6. Pending migrations must be strictly monotonic.
  HostedMigrationComparisonResult compareWithHosted({
    required List<MigrationRecord> localRecords,
    required List<String> remoteVersions,
  }) {
    final issues = <MigrationValidationIssue>[];
    final localMap = {for (final r in localRecords) r.timestamp: r};
    final appliedVersions = <String>[];
    final pendingVersions = <String>[];
    final remoteOnlyVersions = <String>[];
    final missingRemoteVersions = <String>[];

    final tsRegex = RegExp(r'^[0-9]{14}$');

    // 1. Validate remote version formats & ordering
    final seenRemote = <String>{};
    String maxRemoteTimestamp = '';

    for (var i = 0; i < remoteVersions.length; i++) {
      final rv = remoteVersions[i];
      if (!tsRegex.hasMatch(rv)) {
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'invalid_remote_version_format',
            filename: rv,
            message: 'Hosted migration version "$rv" is not a valid 14-digit timestamp.',
          ),
        );
        continue;
      }

      if (seenRemote.contains(rv)) {
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'duplicate_remote_version',
            filename: rv,
            message: 'Hosted migration ledger contains duplicate version "$rv".',
          ),
        );
      } else {
        seenRemote.add(rv);
      }

      if (i > 0 && rv.compareTo(remoteVersions[i - 1]) <= 0) {
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'out_of_order_remote_version',
            filename: rv,
            message: 'Hosted migration version "$rv" is not in strictly ascending order after "${remoteVersions[i - 1]}".',
          ),
        );
      }

      if (rv.compareTo(maxRemoteTimestamp) > 0) {
        maxRemoteTimestamp = rv;
      }
    }

    // 2. Check for remote-only versions (unknown aliases / uncommitted migrations)
    for (final rv in remoteVersions) {
      if (!localMap.containsKey(rv)) {
        remoteOnlyVersions.add(rv);
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'remote_only_migration_version',
            filename: rv,
            message:
                'Hosted migration ledger records version "$rv" which does not exist in local repository migrations. '
                'This indicates an unknown remote alias or uncommitted migration.',
          ),
        );
      } else {
        appliedVersions.add(rv);
      }
    }

    // 3. Check for missing historical migrations (local <= maxRemoteTimestamp not on remote)
    if (maxRemoteTimestamp.isNotEmpty) {
      for (final record in localRecords) {
        if (record.timestamp.compareTo(maxRemoteTimestamp) <= 0) {
          if (!seenRemote.contains(record.timestamp)) {
            missingRemoteVersions.add(record.timestamp);
            issues.add(
              MigrationValidationIssue(
                severity: MigrationIssueSeverity.error,
                rule: 'missing_remote_historical_migration',
                filename: record.filename,
                message:
                    'Local historical migration "${record.filename}" (timestamp ${record.timestamp}) '
                    'is <= latest applied remote version ($maxRemoteTimestamp) but is missing from hosted ledger. '
                    'This indicates migration history divergence or skipped migrations.',
              ),
            );
          }
        } else {
          // Timestamp is > maxRemoteTimestamp -> pending migration
          pendingVersions.add(record.timestamp);
        }
      }
    } else {
      // Remote is completely empty: all local migrations are pending
      for (final record in localRecords) {
        pendingVersions.add(record.timestamp);
      }
    }

    return HostedMigrationComparisonResult(
      issues: issues,
      appliedVersions: appliedVersions,
      pendingVersions: pendingVersions,
      remoteOnlyVersions: remoteOnlyVersions,
      missingRemoteVersions: missingRemoteVersions,
    );
  }

  /// Compares local migration records with remote migration versions for post-deployment gate.
  ///
  /// Invariants:
  /// Requires EXACT 1:1 parity between local migration versions and remote applied versions.
  /// Reports error on partial deployment, missing versions, or extraneous remote versions.
  HostedMigrationComparisonResult compareHostedPostflight({
    required List<MigrationRecord> localRecords,
    required List<String> remoteVersions,
  }) {
    final comparison = compareWithHosted(
      localRecords: localRecords,
      remoteVersions: remoteVersions,
    );

    final issues = List<MigrationValidationIssue>.from(comparison.issues);

    // In postflight, there must be ZERO pending migrations remaining
    if (comparison.pendingVersions.isNotEmpty) {
      for (final pv in comparison.pendingVersions) {
        final record = localRecords.firstWhere(
          (r) => r.timestamp == pv,
          orElse: () => MigrationRecord(
            filename: pv,
            timestamp: pv,
            name: '',
            path: '',
            sizeBytes: 0,
            content: '',
          ),
        );
        issues.add(
          MigrationValidationIssue(
            severity: MigrationIssueSeverity.error,
            rule: 'partial_deployment_unapplied_migration',
            filename: record.filename,
            message:
                'Post-deployment check failed: migration "${record.filename}" was expected to be applied '
                'but is still missing from the hosted ledger. Deployment was only partially applied!',
          ),
        );
      }
    }

    return HostedMigrationComparisonResult(
      issues: issues,
      appliedVersions: comparison.appliedVersions,
      pendingVersions: comparison.pendingVersions,
      remoteOnlyVersions: comparison.remoteOnlyVersions,
      missingRemoteVersions: comparison.missingRemoteVersions,
    );
  }
}

/// Result of comparing local migration records with hosted remote migration ledger.
class HostedMigrationComparisonResult {
  final List<MigrationValidationIssue> issues;
  final List<String> appliedVersions;
  final List<String> pendingVersions;
  final List<String> remoteOnlyVersions;
  final List<String> missingRemoteVersions;

  const HostedMigrationComparisonResult({
    required this.issues,
    required this.appliedVersions,
    required this.pendingVersions,
    required this.remoteOnlyVersions,
    required this.missingRemoteVersions,
  });

  bool get isValid => issues.every((i) => !i.isError);
  bool get hasPending => pendingVersions.isNotEmpty;
  bool get isExactParity =>
      isValid &&
      pendingVersions.isEmpty &&
      remoteOnlyVersions.isEmpty &&
      missingRemoteVersions.isEmpty;
  int get errorCount => issues.where((i) => i.isError).length;
}

