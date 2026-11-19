import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/learning_support_kinds.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';

/// The learner's *first* answer to one practice check. Retries after seeing
/// feedback are not new evidence (master plan v2.6 §10.7: repeated exposure
/// is discounted).
class CheckAttempt {
  const CheckAttempt({
    required this.itemId,
    required this.firstAttemptCorrect,
    this.disputed = false,
    this.misconceptionId,
  });

  final String itemId;
  final bool firstAttemptCorrect;

  /// The reviewed misconception tag of the wrong option chosen first, if
  /// any. Only the first answer counts (retries follow feedback).
  final String? misconceptionId;

  /// The learner said the question seems wrong. Disputed items never count
  /// as evidence against the learner (§10.0 wrong-answer triage).
  final bool disputed;

  CheckAttempt copyWith({bool? disputed}) => CheckAttempt(
    itemId: itemId,
    firstAttemptCorrect: firstAttemptCorrect,
    disputed: disputed ?? this.disputed,
    misconceptionId: misconceptionId,
  );
}

/// Confidence tiers from §10.2. A suggestion is only made at
/// [supported] or above; one missed item is never enough.
enum GapEvidenceTier { none, suspected, supported }

/// A dismissible, explained suggestion. It is a hypothesis, never a
/// diagnosis, and accepting it is always the learner's choice.
class GapSuggestion {
  const GapSuggestion({
    required this.prerequisite,
    required this.tier,
    required this.missed,
    required this.counted,
  });

  final BridgeLesson prerequisite;
  final GapEvidenceTier tier;

  /// First-attempt misses on undisputed checks.
  final int missed;

  /// Undisputed checks answered at least once.
  final int counted;

  GapKind get hypothesis => GapKind.missingPrerequisite;

  /// Plain-language reason shown with the suggestion.
  String get reason =>
      'You missed $missed of $counted questions here on the first try. '
      'A short refresher on "${prerequisite.title}" might help.';
}

/// A possible mix-up, suggested only after the same reviewed misconception
/// showed up in first answers to at least two different questions (master
/// plan v2.6 §10.6 `concept_misconception`). A hypothesis, never a label on
/// the learner; it offers a contrastive explanation and a *new* question,
/// never the same question again as proof.
class MisconceptionSuggestion {
  const MisconceptionSuggestion({
    required this.misconception,
    required this.questions,
    this.nextItemId,
  });

  final BridgeMisconception misconception;

  /// Distinct questions whose first answer showed it.
  final int questions;

  /// An unanswered question in this Bridge to try next, if any.
  final String? nextItemId;

  String get reason =>
      'Your first answers on $questions questions match a common mix-up: '
      '${misconception.label}.';
}

/// Rules-first gap signals for the Bridge pilot (master plan v2.6 §10.6,
/// PR-D). No learned model, no server data, no mastery writes.
class GapSignalService {
  const GapSignalService._();

  /// Minimum distinct first-attempt misses before anything is suggested.
  static const supportedMisses = 2;

  static GapEvidenceTier tierFor(Iterable<CheckAttempt> attempts) {
    final missed = attempts
        .where((a) => !a.disputed && !a.firstAttemptCorrect)
        .map((a) => a.itemId)
        .toSet()
        .length;
    if (missed >= supportedMisses) return GapEvidenceTier.supported;
    if (missed == 1) return GapEvidenceTier.suspected;
    return GapEvidenceTier.none;
  }

  /// Distinct questions needed before a misconception is suggested.
  static const misconceptionQuestions = 2;

  /// At most one misconception suggestion for [bridge]. Disputed answers
  /// never count; [dismissed] holds misconception ids the learner said
  /// were not the issue.
  static MisconceptionSuggestion? proposeMisconception({
    required BridgeLesson bridge,
    required Iterable<CheckAttempt> attempts,
    required Set<String> dismissed,
  }) {
    final byTag = <String, Set<String>>{};
    for (final a in attempts) {
      final tag = a.misconceptionId;
      if (a.disputed || a.firstAttemptCorrect || tag == null) continue;
      byTag.putIfAbsent(tag, () => {}).add(a.itemId);
    }
    final answered = {for (final a in attempts) a.itemId};
    // Reviewed order: the Bridge's own misconception list.
    for (final m in bridge.misconceptions) {
      final items = byTag[m.misconceptionId] ?? const <String>{};
      if (items.length < misconceptionQuestions ||
          dismissed.contains(m.misconceptionId)) {
        continue;
      }
      String? next;
      for (final c in bridge.checks) {
        if (!answered.contains(c.itemId)) {
          next = c.itemId;
          break;
        }
      }
      return MisconceptionSuggestion(
        misconception: m,
        questions: items.length,
        nextItemId: next,
      );
    }
    return null;
  }

  /// At most one suggestion: the first prerequisite of [bridge] (in its
  /// `builds_on` order) that exists, was not dismissed and can be opened
  /// within the help trail's depth and cycle limits.
  static GapSuggestion? propose({
    required BridgeLesson bridge,
    required Iterable<CheckAttempt> attempts,
    required BridgeLibrary library,
    required Set<String> dismissed,
    required bool Function(BridgeLesson prerequisite) canOpen,
  }) {
    final counted = attempts.where((a) => !a.disputed).toList();
    final tier = tierFor(counted);
    if (tier != GapEvidenceTier.supported) return null;
    for (final id in bridge.buildsOn) {
      final prereq = library[id];
      if (prereq == null || dismissed.contains(id) || !canOpen(prereq)) {
        continue;
      }
      return GapSuggestion(
        prerequisite: prereq,
        tier: tier,
        missed: counted.where((a) => !a.firstAttemptCorrect).length,
        counted: counted.length,
      );
    }
    return null;
  }
}
