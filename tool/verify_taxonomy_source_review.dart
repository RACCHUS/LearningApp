import 'dart:convert';
import 'dart:io';

/// Fail-closed validation of the proposed external-source access review queue.
/// This does NOT approve licenses, use source data, or contact publishers.
///
/// dart run tool/verify_taxonomy_source_review.dart
void main(List<String> args) {
  if (args.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/verify_taxonomy_source_review.dart');
    exitCode = 2;
    return;
  }
  try {
    final registry = Map<String, dynamic>.from(
      jsonDecode(File('data/taxonomy/source_registry.json').readAsStringSync())
          as Map,
    );
    final access = Map<String, dynamic>.from(
      jsonDecode(
        File('data/taxonomy/source_access_review.json').readAsStringSync(),
      ) as Map,
    );

    if (access['schema_version'] != 1) {
      throw FormatException('Unsupported access review schema version.');
    }
    final ids = (registry['sources'] as List)
        .map((item) => (item as Map)['id'] as String)
        .toSet();
    final records = (access['sources'] as List).cast<Map<String, dynamic>>();
    final seen = <String>{};
    const priorities = {'P0', 'P1', 'P2', 'P3'};
    const accessStates = {
      'existing_importer',
      'token_required',
      'developer_agreement_required',
      'key_or_bulk_download',
      'bulk_download',
      'manual_blueprint_review',
      'per_issuer',
      'issuer_api_or_download',
      'future_import',
    };

    for (final record in records) {
      final id = record['id'] as String;
      if (!seen.add(id)) {
        throw FormatException('Duplicate source review ID: $id');
      }
      if (!ids.contains(id)) {
        throw FormatException('Review for unknown source: $id');
      }
      if (!priorities.contains(record['priority']) ||
          !accessStates.contains(record['access'])) {
        throw FormatException('Invalid priority/access status for $id');
      }
      final uri = Uri.tryParse((record['evidence'] ?? '').toString());
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
        throw FormatException('Invalid source evidence URL for $id');
      }
      for (final field in [
        'owner',
        'publication_rights',
        'blocker',
      ]) {
        if ((record[field] ?? '').toString().trim().isEmpty) {
          throw FormatException('Empty $field for $id');
        }
      }
      if (record['ingestion_approved_for_new_sources'] != false) {
        throw FormatException(
          'Source $id cannot auto-approve external ingestion in registry',
        );
      }
    }
    if (seen.length != ids.length) {
      throw FormatException(
        'Missing source reviews: ${ids.difference(seen).join(', ')}',
      );
    }
    stdout.writeln(
      'Source access review verified: ${seen.length} records, '
      'no new bulk-ingestion approvals.',
    );
  } catch (error) {
    stderr.writeln('Source access review invalid: $error');
    exitCode = 1;
  }
}
