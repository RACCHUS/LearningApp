import 'dart:convert';
import 'dart:io';

/// Expected published Florida regulator pathway identities.
const Set<String> kExpectedPublishedPathways = {
  'fl_bon:registered-nurse',
  'fl_bon:licensed-practical-nurse',
  'fl_dfs:general-lines-2-20',
  'fl_dfs:life-health-2-15',
  'dbpr_fl:certified-general-contractor',
  'dbpr_fl:certified-building-contractor',
};

/// Maximum age of source_checked_at before the RLS policy hides the row (180 days).
const int kMaxSourceAgeDays = 180;

/// Age threshold at which a warning is emitted for upcoming expiration (150 days).
const int kWarningSourceAgeDays = 150;

/// Result of evaluating a set of pathway version records against publication rules.
class PathwayVerificationResult {
  final bool isSuccess;
  final List<String> errors;
  final List<String> warnings;
  final int verifiedCount;
  final Set<String> verifiedIdentities;

  const PathwayVerificationResult({
    required this.isSuccess,
    required this.errors,
    required this.warnings,
    required this.verifiedCount,
    required this.verifiedIdentities,
  });
}

/// Evaluates raw pathway version rows against strict production publication invariants.
PathwayVerificationResult verifyPathwayRecords(
  List<dynamic> rows, {
  DateTime? now,
  Set<String>? expectedIdentities,
  int maxAgeDays = kMaxSourceAgeDays,
  int warningAgeDays = kWarningSourceAgeDays,
}) {
  final currentTime = now ?? DateTime.now().toUtc();
  final expected = expectedIdentities ?? kExpectedPublishedPathways;
  final errors = <String>[];
  final warnings = <String>[];
  final foundIdentities = <String>{};
  final seenIdentities = <String>{};

  for (var i = 0; i < rows.length; i++) {
    final raw = rows[i];
    if (raw is! Map) {
      errors.add('Row $i is not a valid JSON map');
      continue;
    }

    final ns = raw['source_namespace'] as String?;
    final key = raw['source_key'] as String?;
    final rev = raw['revision'];
    final title = raw['title'] as String?;
    final status = raw['publication_status'] as String?;
    final review = raw['review_status'] as String?;
    final coverage = raw['coverage'] as String?;
    final routeKind = raw['route_kind'] as String?;
    final sourceUrlStr = raw['source_url'] as String?;
    final sourceCheckedStr = raw['source_checked_at'] as String?;
    final effectiveFromStr = raw['effective_from'] as String?;
    final effectiveUntilStr = raw['effective_until'] as String?;

    if (ns == null || ns.trim().isEmpty || key == null || key.trim().isEmpty) {
      errors.add('Row $i is missing source_namespace or source_key');
      continue;
    }

    final identity = '$ns:$key';

    // Duplicate check
    if (seenIdentities.contains(identity)) {
      errors.add('Duplicate pathway row encountered for identity: $identity');
    }
    seenIdentities.add(identity);

    // Unexpected identity check
    if (!expected.contains(identity)) {
      errors.add('Unexpected pathway identity returned: $identity');
    }

    // Publication status
    if (status != 'published') {
      errors.add('$identity has publication_status "$status" (expected "published")');
    }

    // Review status
    if (review != 'approved') {
      errors.add('$identity has review_status "$review" (expected "approved")');
    }

    // Coverage invariant
    if (coverage != 'selected_steps_only') {
      errors.add('$identity has coverage "$coverage" (expected "selected_steps_only")');
    }

    // Route kind
    if (routeKind != 'examination') {
      errors.add('$identity has route_kind "$routeKind" (expected "examination")');
    }

    // Revision check
    if (rev != 1) {
      errors.add('$identity has revision $rev (expected 1 for current release)');
    }

    // Title validation
    if (title == null || title.trim().length < 8) {
      errors.add('$identity has missing or invalid title: "$title"');
    }

    // Source URL validation
    if (sourceUrlStr == null || !sourceUrlStr.startsWith('https://')) {
      errors.add('$identity has missing or non-HTTPS source_url: "$sourceUrlStr"');
    } else {
      final uri = Uri.tryParse(sourceUrlStr);
      if (uri == null || !uri.hasAuthority) {
        errors.add('$identity has malformed source_url: "$sourceUrlStr"');
      }
    }

    // Source checked date & 180-day RLS expiration policy check
    if (sourceCheckedStr == null) {
      errors.add('$identity is missing source_checked_at timestamp');
    } else {
      final checkedAt = DateTime.tryParse(sourceCheckedStr)?.toUtc();
      if (checkedAt == null) {
        errors.add('$identity has invalid source_checked_at: "$sourceCheckedStr"');
      } else if (checkedAt.isAfter(currentTime)) {
        errors.add('$identity has future source_checked_at: $sourceCheckedStr');
      } else {
        final ageDays = currentTime.difference(checkedAt).inDays;
        if (ageDays > maxAgeDays) {
          errors.add(
            '$identity source review is EXPIRED ($ageDays days old > $maxAgeDays days limit). '
            'Row is hidden or will be hidden by public SELECT RLS policy!',
          );
        } else if (ageDays >= warningAgeDays) {
          final daysRemaining = maxAgeDays - ageDays;
          warnings.add(
            '$identity source review is $ageDays days old ($daysRemaining days remaining before 180-day RLS expiration). '
            'Schedule recertification review before expiration!',
          );
        }
      }
    }

    // Effective dates validation
    if (effectiveFromStr != null) {
      final effectiveFrom = DateTime.tryParse(effectiveFromStr)?.toUtc();
      if (effectiveFrom != null && effectiveFrom.isAfter(currentTime)) {
        errors.add('$identity has future effective_from date: $effectiveFromStr');
      }
    }

    if (effectiveUntilStr != null) {
      final effectiveUntil = DateTime.tryParse(effectiveUntilStr)?.toUtc();
      if (effectiveUntil != null && effectiveUntil.isBefore(currentTime)) {
        errors.add('$identity has past effective_until date: $effectiveUntilStr (expired)');
      }
    }

    foundIdentities.add(identity);
  }

  // Missing expected identities
  final missing = expected.difference(foundIdentities);
  if (missing.isNotEmpty) {
    errors.add(
      'Missing ${missing.length} expected pathway(s): ${missing.toList()..sort()}',
    );
  }

  // Exact count check
  if (foundIdentities.length != expected.length) {
    errors.add(
      'Pathway count mismatch: found ${foundIdentities.length} unique records, expected ${expected.length}',
    );
  }

  final isSuccess = errors.isEmpty;
  return PathwayVerificationResult(
    isSuccess: isSuccess,
    errors: errors,
    warnings: warnings,
    verifiedCount: foundIdentities.length,
    verifiedIdentities: foundIdentities,
  );
}

Map<String, String> loadDotenv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    var value = trimmed.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    env[trimmed.substring(0, eq).trim()] = value;
  }
  return env;
}

Future<void> main() async {
  final env = loadDotenv();
  final url = env['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  final anonKey = env['SUPABASE_ANON_KEY'] ?? Platform.environment['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    stderr.writeln('ERROR: Missing SUPABASE_URL or SUPABASE_ANON_KEY in environment or .env');
    exit(1);
  }

  stdout.writeln('================================================================');
  stdout.writeln('Catalog License Pathway Versions Verification (Anonymous REST)');
  stdout.writeln('Target: $url');
  stdout.writeln('================================================================\n');

  final client = HttpClient();
  final uri = Uri.parse(
    '$url/rest/v1/catalog_license_pathway_versions?'
    'select=source_namespace,source_key,revision,jurisdiction,route_kind,title,'
    'coverage,source_url,source_checked_at,reviewed_at,reviewer,review_status,'
    'publication_status,effective_from,effective_until'
    '&order=source_namespace,source_key',
  );

  final req = await client.getUrl(uri);
  req.headers.set('apikey', anonKey);
  req.headers.set('Authorization', 'Bearer $anonKey');
  req.headers.set('Accept', 'application/json');

  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();

  if (resp.statusCode != 200) {
    stderr.writeln('FAILED: Anonymous REST returned HTTP ${resp.statusCode}: $body');
    exit(1);
  }

  List<dynamic> rows;
  try {
    rows = jsonDecode(body) as List<dynamic>;
  } catch (e) {
    stderr.writeln('FAILED: Response body is not valid JSON array: $e');
    exit(1);
  }

  stdout.writeln('Retrieved ${rows.length} published pathway record(s) via anonymous RLS:');

  for (final r in rows) {
    if (r is Map) {
      final ns = r['source_namespace'];
      final key = r['source_key'];
      final rev = r['revision'];
      final title = r['title'];
      final status = r['publication_status'];
      final review = r['review_status'];
      final checked = r['source_checked_at'];
      stdout.writeln('• [$ns] $key (rev $rev)');
      stdout.writeln('  Title: "$title"');
      stdout.writeln('  Status: $status | Review: $review | Checked: $checked');
    }
  }
  stdout.writeln();

  final result = verifyPathwayRecords(rows);

  if (result.warnings.isNotEmpty) {
    stdout.writeln('⚠️ WARNINGS (${result.warnings.length}):');
    for (final w in result.warnings) {
      stdout.writeln('  - $w');
    }
    stdout.writeln();
  }

  if (!result.isSuccess) {
    stderr.writeln('❌ VERIFICATION FAILED (${result.errors.length} error(s)):');
    for (final err in result.errors) {
      stderr.writeln('  • $err');
    }
    stderr.writeln('\nExiting with code 1.');
    exit(1);
  }

  stdout.writeln(
    '✅ PASSED: All ${result.verifiedCount} target Florida pathways are published, '
    'approved, current within 180-day RLS limits, and publicly visible under anonymous RLS!',
  );
}
