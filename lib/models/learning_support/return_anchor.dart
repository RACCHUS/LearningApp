import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

/// What the learner's original activity hangs from.
enum ReturnAnchorRootType {
  target('target'),
  course('course'),
  lesson('lesson'),
  studySet('study_set'),
  concept('concept');

  const ReturnAnchorRootType(this.wire);
  final String wire;

  static ReturnAnchorRootType? fromWire(Object? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// Why an anchor could not be decoded.
enum ReturnAnchorIssue {
  /// Not a JSON object.
  notAnObject,

  /// `return_anchor_version` is newer than this app understands.
  unsupportedVersion,

  /// A required field is absent.
  missingField,

  /// A field has the wrong type or fails sanitization.
  invalidField,
}

class ReturnAnchorDecodeResult {
  const ReturnAnchorDecodeResult._(this.anchor, this.issue, this.field);

  final ReturnAnchor? anchor;
  final ReturnAnchorIssue? issue;

  /// The offending field, when [issue] concerns one.
  final String? field;

  bool get isOk => anchor != null;
}

/// Versioned pointer back to the exact activity a learner left to get help
/// (master plan v2.6 §10.5). Captured *before* help opens.
///
/// It holds identifiers and short cursors only. It never stores answer
/// keys, item content, user-typed text, AI chat or URL query strings, and
/// decoding drops any field not listed here.
///
/// [rescueSessionId] is unique per anchor and doubles as its ID.
class ReturnAnchor {
  ReturnAnchor({
    required this.learningContextId,
    required this.rootType,
    required this.rootId,
    required this.originRoute,
    required this.activeLearningStrategy,
    required this.originActivityStateRevision,
    required this.rescueSessionId,
    required DateTime createdAt,
    this.targetVersionId,
    this.lessonId,
    this.assetVersionId,
    this.blockId,
    this.assessmentItemId,
    this.intraBlockAnchor,
    this.pageOrScrollAnchor,
  }) : createdAt = createdAt.toUtc() {
    void id(String name, String? v, {bool required = false}) {
      if (v == null && !required) return;
      if (!SupportIdentifiers.isId(v)) {
        throw ArgumentError.value(v, name, 'not a safe identifier');
      }
    }

    void token(String name, String? v) {
      if (v != null && !SupportIdentifiers.isToken(v)) {
        throw ArgumentError.value(v, name, 'not a safe cursor token');
      }
    }

    id('learningContextId', learningContextId, required: true);
    id('rootId', rootId, required: true);
    id('rescueSessionId', rescueSessionId, required: true);
    id('targetVersionId', targetVersionId);
    id('lessonId', lessonId);
    id('assetVersionId', assetVersionId);
    id('blockId', blockId);
    id('assessmentItemId', assessmentItemId);
    token('intraBlockAnchor', intraBlockAnchor);
    token('pageOrScrollAnchor', pageOrScrollAnchor);
    if (!SupportIdentifiers.isRoute(originRoute)) {
      throw ArgumentError.value(originRoute, 'originRoute', 'not a safe route');
    }
    if (originActivityStateRevision < 0) {
      throw ArgumentError.value(
        originActivityStateRevision,
        'originActivityStateRevision',
        'must not be negative',
      );
    }
  }

  static const int currentVersion = 1;

  final String learningContextId;
  final ReturnAnchorRootType rootType;
  final String rootId;
  final String? targetVersionId;
  final String originRoute;
  final String? lessonId;
  final String? assetVersionId;
  final String? blockId;

  /// Identifier only; the item's content and answer key are never stored.
  final String? assessmentItemId;

  /// Stable cursor or step token inside [blockId].
  final String? intraBlockAnchor;

  /// Last-resort, non-sensitive position hint. Never an "exact" resume.
  final String? pageOrScrollAnchor;

  /// Restored as-is; returning never switches Standard/Fast.
  final PersistedLearningStrategy activeLearningStrategy;
  final int originActivityStateRevision;
  final String rescueSessionId;
  final DateTime createdAt;

  String get anchorId => rescueSessionId;

  Map<String, Object> toJson() => {
    'return_anchor_version': currentVersion,
    'learning_context_id': learningContextId,
    'root_type': rootType.wire,
    'root_id': rootId,
    'target_version_id': ?targetVersionId,
    'origin_route': originRoute,
    'lesson_id': ?lessonId,
    'asset_version_id': ?assetVersionId,
    'block_id': ?blockId,
    'assessment_item_id': ?assessmentItemId,
    'intra_block_anchor': ?intraBlockAnchor,
    'page_or_scroll_anchor': ?pageOrScrollAnchor,
    'active_learning_strategy': activeLearningStrategy.wireValue,
    'origin_activity_state_revision': originActivityStateRevision,
    'rescue_session_id': rescueSessionId,
    'created_at': createdAt.toIso8601String(),
  };

  /// Strict decode. A newer version is reported, never downgraded; an
  /// unknown strategy is invalid rather than silently becoming Standard.
  static ReturnAnchorDecodeResult decode(Object? json) {
    ReturnAnchorDecodeResult fail(ReturnAnchorIssue i, [String? f]) =>
        ReturnAnchorDecodeResult._(null, i, f);

    if (json is! Map) return fail(ReturnAnchorIssue.notAnObject);
    final version = json['return_anchor_version'];
    if (version == null) {
      return fail(ReturnAnchorIssue.missingField, 'return_anchor_version');
    }
    if (version is! int || version < 1) {
      return fail(ReturnAnchorIssue.invalidField, 'return_anchor_version');
    }
    if (version > currentVersion) {
      return fail(
        ReturnAnchorIssue.unsupportedVersion,
        'return_anchor_version',
      );
    }

    const required = [
      'learning_context_id',
      'root_type',
      'root_id',
      'origin_route',
      'active_learning_strategy',
      'origin_activity_state_revision',
      'rescue_session_id',
      'created_at',
    ];
    for (final f in required) {
      if (json[f] == null) return fail(ReturnAnchorIssue.missingField, f);
    }

    String? optionalString(String f) {
      final v = json[f];
      return v is String ? v : null;
    }

    for (final f in const [
      'learning_context_id',
      'root_id',
      'rescue_session_id',
      'origin_route',
      'created_at',
      'target_version_id',
      'lesson_id',
      'asset_version_id',
      'block_id',
      'assessment_item_id',
      'intra_block_anchor',
      'page_or_scroll_anchor',
    ]) {
      final v = json[f];
      if (v != null && v is! String) {
        return fail(ReturnAnchorIssue.invalidField, f);
      }
    }

    final rootType = ReturnAnchorRootType.fromWire(json['root_type']);
    if (rootType == null) {
      return fail(ReturnAnchorIssue.invalidField, 'root_type');
    }

    final strategyWire = json['active_learning_strategy'];
    PersistedLearningStrategy? strategy;
    for (final s in PersistedLearningStrategy.values) {
      if (s.wireValue == strategyWire) strategy = s;
    }
    if (strategy == null) {
      return fail(ReturnAnchorIssue.invalidField, 'active_learning_strategy');
    }

    final revision = json['origin_activity_state_revision'];
    if (revision is! int || revision < 0) {
      return fail(
        ReturnAnchorIssue.invalidField,
        'origin_activity_state_revision',
      );
    }

    final createdAt = DateTime.tryParse(json['created_at'] as String);
    if (createdAt == null) {
      return fail(ReturnAnchorIssue.invalidField, 'created_at');
    }

    try {
      return ReturnAnchorDecodeResult._(
        ReturnAnchor(
          learningContextId: json['learning_context_id'] as String,
          rootType: rootType,
          rootId: json['root_id'] as String,
          originRoute: json['origin_route'] as String,
          activeLearningStrategy: strategy,
          originActivityStateRevision: revision,
          rescueSessionId: json['rescue_session_id'] as String,
          createdAt: createdAt,
          targetVersionId: optionalString('target_version_id'),
          lessonId: optionalString('lesson_id'),
          assetVersionId: optionalString('asset_version_id'),
          blockId: optionalString('block_id'),
          assessmentItemId: optionalString('assessment_item_id'),
          intraBlockAnchor: optionalString('intra_block_anchor'),
          pageOrScrollAnchor: optionalString('page_or_scroll_anchor'),
        ),
        null,
        null,
      );
    } on ArgumentError catch (e) {
      return fail(ReturnAnchorIssue.invalidField, _jsonName(e.name));
    }
  }

  static String? _jsonName(String? dartName) {
    if (dartName == null) return null;
    return dartName.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    );
  }
}
