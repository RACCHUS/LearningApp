import 'package:learning_pwa/models/learning_support/return_anchor.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

/// One nested help step: the anchor to return to and the concept the help
/// opened for (used for cycle detection).
class AnchorStackEntry {
  const AnchorStackEntry(this.anchor, {this.conceptId});

  final ReturnAnchor anchor;
  final String? conceptId;
}

enum AnchorPushRejection {
  /// The configured maximum nesting depth is reached.
  depthLimit,

  /// The concept is already being helped further down the stack.
  cycle,

  /// The anchor belongs to a different learning context.
  contextMismatch,

  /// The rescue session is already on the stack.
  duplicateSession,
}

class AnchorPushResult {
  const AnchorPushResult._(this.stack, this.rejection);

  final ReturnAnchorStack? stack;
  final AnchorPushRejection? rejection;

  bool get isOk => stack != null;
}

enum AnchorStackDecodeIssue {
  notAnObject,
  unsupportedVersion,

  /// Saved under a different account or guest identity: never restored.
  otherOwner,
  invalidField,
  tooManyEntries,
  invalidAnchor,
}

class AnchorStackDecodeResult {
  const AnchorStackDecodeResult._(this.stack, this.issue, [this.index]);

  final ReturnAnchorStack? stack;
  final AnchorStackDecodeIssue? issue;

  /// Entry index for [AnchorStackDecodeIssue.invalidAnchor].
  final int? index;

  bool get isOk => stack != null;
}

/// Bounded, immutable stack of return anchors for nested help, e.g.
/// Excel formula → percentage change → fractions (master plan v2.6 §10.5).
///
/// It stops at [maxDepth] and on repeated concepts, so help can never loop.
/// All entries share one owner and one learning context.
class ReturnAnchorStack {
  ReturnAnchorStack._(this.ownerScope, this.maxDepth, List<AnchorStackEntry> e)
    : entries = List.unmodifiable(e);

  factory ReturnAnchorStack.empty({
    required String ownerScope,
    int maxDepth = defaultMaxDepth,
  }) {
    if (!SupportIdentifiers.isId(ownerScope)) {
      throw ArgumentError.value(ownerScope, 'ownerScope');
    }
    if (maxDepth < 1 || maxDepth > hardMaxDepth) {
      throw ArgumentError.value(maxDepth, 'maxDepth', '1..$hardMaxDepth');
    }
    return ReturnAnchorStack._(ownerScope, maxDepth, const []);
  }

  static const int currentVersion = 1;
  static const int defaultMaxDepth = 3;

  /// Absolute bound, also applied when decoding stored data.
  static const int hardMaxDepth = 8;

  /// Authenticated user ID or guest identity that owns this stack.
  final String ownerScope;
  final int maxDepth;

  /// Bottom (original activity) first.
  final List<AnchorStackEntry> entries;

  bool get isEmpty => entries.isEmpty;
  int get depth => entries.length;

  /// Where "Back" goes next, or `null` when there is no help open.
  ReturnAnchor? get top => entries.isEmpty ? null : entries.last.anchor;

  /// The learner's original activity: "Back to [original topic]".
  ReturnAnchor? get root => entries.isEmpty ? null : entries.first.anchor;

  AnchorPushResult push(ReturnAnchor anchor, {String? conceptId}) {
    AnchorPushResult reject(AnchorPushRejection r) =>
        AnchorPushResult._(null, r);

    if (entries.isNotEmpty &&
        anchor.learningContextId != entries.first.anchor.learningContextId) {
      return reject(AnchorPushRejection.contextMismatch);
    }
    if (entries.any(
      (e) => e.anchor.rescueSessionId == anchor.rescueSessionId,
    )) {
      return reject(AnchorPushRejection.duplicateSession);
    }
    if (conceptId != null && entries.any((e) => e.conceptId == conceptId)) {
      return reject(AnchorPushRejection.cycle);
    }
    if (entries.length >= maxDepth) {
      return reject(AnchorPushRejection.depthLimit);
    }
    return AnchorPushResult._(
      ReturnAnchorStack._(ownerScope, maxDepth, [
        ...entries,
        AnchorStackEntry(anchor, conceptId: conceptId),
      ]),
      null,
    );
  }

  /// Removes the top entry. Popping an empty stack returns it unchanged.
  ReturnAnchorStack pop() => entries.isEmpty
      ? this
      : ReturnAnchorStack._(
          ownerScope,
          maxDepth,
          entries.sublist(0, entries.length - 1),
        );

  /// Drops every nested step and keeps only the original activity.
  ReturnAnchorStack unwindToRoot() => entries.length <= 1
      ? this
      : ReturnAnchorStack._(ownerScope, maxDepth, [entries.first]);

  Map<String, Object> toJson() => {
    'anchor_stack_version': currentVersion,
    'owner_scope': ownerScope,
    'max_depth': maxDepth,
    'entries': [
      for (final e in entries)
        {'anchor': e.anchor.toJson(), 'concept_id': ?e.conceptId},
    ],
  };

  /// Decodes a stored stack for [expectedOwnerScope]. Data saved under a
  /// different owner is refused, never adopted.
  static AnchorStackDecodeResult decode(
    Object? json, {
    required String expectedOwnerScope,
  }) {
    AnchorStackDecodeResult fail(AnchorStackDecodeIssue i, [int? index]) =>
        AnchorStackDecodeResult._(null, i, index);

    if (json is! Map) return fail(AnchorStackDecodeIssue.notAnObject);
    final version = json['anchor_stack_version'];
    if (version is! int || version < 1) {
      return fail(AnchorStackDecodeIssue.invalidField);
    }
    if (version > currentVersion) {
      return fail(AnchorStackDecodeIssue.unsupportedVersion);
    }
    final owner = json['owner_scope'];
    if (owner is! String) return fail(AnchorStackDecodeIssue.invalidField);
    if (owner != expectedOwnerScope) {
      return fail(AnchorStackDecodeIssue.otherOwner);
    }
    final maxDepth = json['max_depth'];
    if (maxDepth is! int || maxDepth < 1 || maxDepth > hardMaxDepth) {
      return fail(AnchorStackDecodeIssue.invalidField);
    }
    final rawEntries = json['entries'];
    if (rawEntries is! List) return fail(AnchorStackDecodeIssue.invalidField);
    if (rawEntries.length > maxDepth) {
      return fail(AnchorStackDecodeIssue.tooManyEntries);
    }

    ReturnAnchorStack stack;
    try {
      stack = ReturnAnchorStack.empty(ownerScope: owner, maxDepth: maxDepth);
    } on ArgumentError {
      return fail(AnchorStackDecodeIssue.invalidField);
    }
    for (var i = 0; i < rawEntries.length; i++) {
      final raw = rawEntries[i];
      if (raw is! Map) return fail(AnchorStackDecodeIssue.invalidAnchor, i);
      final concept = raw['concept_id'];
      if (concept != null && !SupportIdentifiers.isId(concept)) {
        return fail(AnchorStackDecodeIssue.invalidAnchor, i);
      }
      final anchor = ReturnAnchor.decode(raw['anchor']);
      if (!anchor.isOk) return fail(AnchorStackDecodeIssue.invalidAnchor, i);
      // Re-apply the push rules so stored data cannot smuggle in a cycle.
      final pushed = stack.push(anchor.anchor!, conceptId: concept as String?);
      if (!pushed.isOk) return fail(AnchorStackDecodeIssue.invalidAnchor, i);
      stack = pushed.stack!;
    }
    return AnchorStackDecodeResult._(stack, null);
  }
}
