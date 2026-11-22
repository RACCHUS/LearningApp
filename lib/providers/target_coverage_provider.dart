import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads `get_coverage_matrix` for a target slug. Overridable in tests.
final coverageMatrixLoaderProvider =
    Provider<Future<Map<String, dynamic>> Function(String slug)>((ref) {
  return (slug) async {
    final res = await Supabase.instance.client.rpc(
      'get_coverage_matrix',
      params: {'p_target_slug': slug},
    );
    return Map<String, dynamic>.from(res as Map);
  };
});

/// The Coverage Matrix for one target (master plan v2.6 §4.2), as rows the
/// Target Detail chips and the Create chooser's need list read. Only
/// published content is counted, so any signed-in or guest learner may see
/// it. A target without a published curriculum has no rows.
final targetCoverageProvider =
    FutureProvider.family<CoverageSummary, String>((ref, slug) async {
  final bridges = await ref.watch(bridgeLibraryProvider.future);
  final matrix = await ref.watch(coverageMatrixLoaderProvider)(slug);
  return CoverageSummary([
    for (final r in (matrix['objectives'] as List? ?? const []))
      CoverageRow.fromServer(Map<String, dynamic>.from(r as Map), bridges),
  ]);
});
