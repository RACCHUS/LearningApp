import 'dart:collection';

import 'package:learning_pwa/models/learning_support/learning_support_kinds.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

/// An objective that lacks suitable content, found by a planner or asked
/// for by a learner (master plan v2.6 §5.1, §12.1).
///
/// A need is derived on demand. It is not an AI call, not a generation job
/// and not a diagnosis of the learner. Only a `ContentResolutionDecision`
/// of kind `generate` may lead to a job; reuse, links, ingestion and
/// deterministic fills come first.
class ContentNeed {
  ContentNeed({
    required this.needId,
    required this.objectiveId,
    required Iterable<String> missingAssetKinds,
    required this.reason,
    required this.evidenceClass,
    required this.privacyClass,
  }) : missingAssetKinds = List.unmodifiable(
         LinkedHashSet<String>.of(missingAssetKinds),
       ) {
    if (!SupportIdentifiers.isId(needId)) {
      throw ArgumentError.value(needId, 'needId');
    }
    if (!SupportIdentifiers.isId(objectiveId)) {
      throw ArgumentError.value(objectiveId, 'objectiveId');
    }
    if (this.missingAssetKinds.isEmpty) {
      throw ArgumentError('A need must name at least one missing asset kind');
    }
    for (final k in this.missingAssetKinds) {
      if (!SupportIdentifiers.isToken(k)) {
        throw ArgumentError.value(k, 'missingAssetKinds');
      }
    }
    if (!SupportIdentifiers.isToken(privacyClass)) {
      throw ArgumentError.value(privacyClass, 'privacyClass');
    }
  }

  final String needId;
  final String objectiveId;

  /// Distinct asset kinds, in first-seen order (e.g. `explanation`, `mcq`).
  final List<String> missingAssetKinds;

  /// A hypothesis, not a finding about the learner.
  final GapKind reason;
  final NeedEvidenceClass evidenceClass;

  /// Privacy class controlling where the need may be shown or sent.
  final String privacyClass;

  /// A tentative need may suggest help but must not drive automatic
  /// generation or claims about the learner.
  bool get isTentative => evidenceClass == NeedEvidenceClass.tentative;
}
