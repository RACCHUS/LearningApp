import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Another published lesson on the same topic, offered by Learning help
/// when a Bridge is not enough or there is none (master plan v2.6 §10.0:
/// Bridge -> other permitted material -> honest unavailability).
class RescueCandidate {
  const RescueCandidate({
    required this.lessonId,
    required this.title,
    required this.sharedTags,
    required this.reviewed,
    required this.hasExample,
    required this.hasPractice,
    required this.hasCheck,
    this.targetTitle,
  });

  factory RescueCandidate.fromJson(Map<String, dynamic> j) => RescueCandidate(
        lessonId: '${j['lesson_id']}',
        title: '${j['title'] ?? ''}',
        targetTitle: j['target_title'] as String?,
        sharedTags: [for (final t in (j['shared_tags'] as List? ?? const [])) '$t'],
        reviewed: j['reviewed'] == true,
        hasExample: j['has_example'] == true,
        hasPractice: j['has_practice'] == true,
        hasCheck: j['has_check'] == true,
      );

  final String lessonId;
  final String title;
  final String? targetTitle;
  final List<String> sharedTags;
  final bool reviewed;
  final bool hasExample;
  final bool hasPractice;
  final bool hasCheck;

  /// Plain description from this lesson's coverage: where it is from,
  /// whether it is reviewed, and what it has.
  String get summary {
    final has = [
      if (hasExample) 'examples',
      if (hasPractice) 'practice',
      if (hasCheck) 'checks',
    ];
    return [
      targetTitle ?? 'Library',
      reviewed ? 'Reviewed' : 'Imported, not yet reviewed',
      if (has.isNotEmpty) 'has ${has.join(', ')}',
    ].join(' · ');
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Calls `find_rescue_candidates`. Overridable in tests.
final rescueCandidatesLoaderProvider =
    Provider<Future<List<RescueCandidate>> Function(String lessonId)>((ref) {
  return (lessonId) async {
    final res = await Supabase.instance.client.rpc(
      'find_rescue_candidates',
      params: {'p_lesson_id': lessonId, 'p_limit': 5},
    );
    return [
      for (final r in (res as List? ?? const []))
        RescueCandidate.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  };
});

/// Other lessons on this lesson's topic. Empty with Learning help off, for
/// bundled lessons (no server id) and whenever the lookup fails: help must
/// never depend on the network to show what it already has.
final rescueCandidatesProvider =
    FutureProvider.family<List<RescueCandidate>, String>((ref, lessonId) async {
  if (!ref.watch(quickRescueEnabledProvider) || !_uuid.hasMatch(lessonId)) {
    return const [];
  }
  try {
    return await ref.watch(rescueCandidatesLoaderProvider)(lessonId);
  } catch (_) {
    return const [];
  }
});
