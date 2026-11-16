import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One concept in the "needs reinforcement" band (UI spec §5.5 / §6.1), with
/// the learner's due review items that practise it.
@immutable
class ReinforcementSuggestion {
  const ReinforcementSuggestion({
    required this.conceptId,
    required this.name,
    required this.confidence,
    required this.dueContentIds,
    this.lastEvidenceAt,
  });

  final String conceptId;
  final String name;
  final ConceptConfidence confidence;

  /// Content ids of due review items linked to this concept. Empty means
  /// there is nothing to review for it right now.
  final List<String> dueContentIds;
  final DateTime? lastEvidenceAt;

  bool get hasDueItems => dueContentIds.isNotEmpty;
}

/// Builds the Progress "needs reinforcement" list (`learning.reinforcement_suggestions`).
///
/// Reads only: the learner's own concept states, concept names, the shared
/// concept-to-content mappings and the learner's due review items. Nothing is
/// written. Retrieval bands are a heuristic about retention (§6.1), so the
/// result carries the band's confidence and never a percentage.
class ReinforcementSuggestionService {
  ReinforcementSuggestionService({
    required SupabaseClient client,
    required Future<Map<String, UserConceptState>> Function(String userId) conceptStates,
    required Future<List<ReviewableItem>> Function() dueItems,
  })  : _client = client,
        _conceptStates = conceptStates,
        _dueItems = dueItems;

  final SupabaseClient _client;
  final Future<Map<String, UserConceptState>> Function(String userId) _conceptStates;
  final Future<List<ReviewableItem>> Function() _dueItems;

  /// At most this many concepts are listed (§8: suggest, never flood).
  static const int maxSuggestions = 8;

  /// Cap on review items per concept, keeping the review link short.
  static const int maxItemsPerConcept = 40;

  /// Weakest-evidence-first: concepts not practised for longest come first.
  Future<List<ReinforcementSuggestion>> load(String userId) async {
    if (userId.isEmpty || userId == 'local-user') return const [];

    final states = (await _conceptStates(userId))
        .values
        .where((s) => s.retrievalBand == RetrievalBand.needsReinforcement)
        .toList()
      ..sort(_oldestEvidenceFirst);
    final weak = states.take(maxSuggestions).toList();
    if (weak.isEmpty) return const [];
    final ids = weak.map((s) => s.conceptId).toList();

    final names = await _names(ids);
    final direct = <String, Set<String>>{};
    for (final (table, column) in const [
      ('flashcard_concepts', 'flashcard_id'),
      ('question_concepts', 'question_id'),
      ('term_concepts', 'term_id'),
    ]) {
      await _collect(table, column, ids, direct);
    }
    // Same rule as concept evidence: lessons only for concepts with no
    // direct item mapping, so a lesson-wide review is the fallback.
    final lessons = <String, Set<String>>{};
    final unmapped = ids.where((id) => direct[id]?.isNotEmpty != true).toList();
    if (unmapped.isNotEmpty) {
      await _collect('lesson_concepts', 'lesson_id', unmapped, lessons);
    }

    List<ReviewableItem> due;
    try {
      due = await _dueItems();
    } catch (e) {
      debugPrint('Reinforcement list: could not load due items: $e');
      due = const [];
    }

    return [
      for (final s in weak)
        if (names[s.conceptId] case final name?)
          ReinforcementSuggestion(
            conceptId: s.conceptId,
            name: name,
            confidence: s.confidence,
            lastEvidenceAt: s.lastEvidenceAt,
            dueContentIds: due
                .where((item) =>
                    (direct[s.conceptId]?.contains(item.contentId) ?? false) ||
                    (item.lessonId != null &&
                        (lessons[s.conceptId]?.contains(item.lessonId) ?? false)))
                .map((item) => item.contentId)
                .toSet()
                .take(maxItemsPerConcept)
                .toList(),
          ),
    ];
  }

  static int _oldestEvidenceFirst(UserConceptState a, UserConceptState b) {
    final at = a.lastEvidenceAt;
    final bt = b.lastEvidenceAt;
    if (at == null && bt == null) return a.conceptId.compareTo(b.conceptId);
    if (at == null) return -1;
    if (bt == null) return 1;
    final byTime = at.compareTo(bt);
    return byTime != 0 ? byTime : a.conceptId.compareTo(b.conceptId);
  }

  /// Concepts without a readable name are left out rather than shown as ids.
  Future<Map<String, String>> _names(List<String> ids) async {
    try {
      final rows = await _client
          .from('knowledge_concepts')
          .select('id, name')
          .inFilter('id', ids);
      return {
        for (final row in rows as List)
          if ((row['name'] as String?)?.trim().isNotEmpty ?? false)
            row['id'] as String: (row['name'] as String).trim(),
      };
    } catch (e) {
      debugPrint('Reinforcement list: could not load concept names: $e');
      return const {};
    }
  }

  Future<void> _collect(
    String table,
    String column,
    List<String> conceptIds,
    Map<String, Set<String>> into,
  ) async {
    try {
      final rows = await _client
          .from(table)
          .select('concept_id, $column')
          .inFilter('concept_id', conceptIds);
      for (final row in rows as List) {
        final concept = row['concept_id'] as String?;
        final target = row[column] as String?;
        if (concept != null && target != null) {
          into.putIfAbsent(concept, () => <String>{}).add(target);
        }
      }
    } catch (e) {
      debugPrint('Reinforcement list: could not read $table: $e');
    }
  }
}
