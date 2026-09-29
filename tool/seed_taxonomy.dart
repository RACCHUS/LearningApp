import 'taxonomy_status.dart' as status;

/// Canonical Taxonomy CLI Tool
///
/// Dispatches to `taxonomy_status.dart` for taxonomy status and slug verification.
/// Future enhancements can add ingestion pipeline flags (--ingest-cip, --ingest-soc).
Future<void> main(List<String> args) async {
  await status.main(args);
}
