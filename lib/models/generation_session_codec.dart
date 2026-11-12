import 'dart:convert';

import 'package:learning_pwa/models/generation_session.dart';

/// Outcome of reading a stored guided-generation session.
enum SessionDecodeKind {
  /// A readable legacy (unversioned or `schema_version: 1`) session.
  v1,

  /// Bytes exist but are not a readable V1 session (bad JSON, missing or
  /// wrongly typed required field, invalid date).
  unreadable,

  /// A newer `schema_version` this build cannot read. Read-only/export.
  unsupportedVersion,

  /// `schema_version` and `schemaVersion` disagree, or the version is not
  /// an integer. Never downgraded or coerced.
  conflictingVersion,
}

/// Result of [GenerationSessionCodec.decode]. The original [raw] text is
/// always carried so callers can preserve and export it byte-for-byte.
class SessionDecodeResult {
  const SessionDecodeResult._({
    required this.kind,
    required this.raw,
    this.session,
    this.ownerScope,
    this.version,
    this.field,
    this.reason,
  });

  final SessionDecodeKind kind;
  final String raw;

  /// The parsed session; non-null only for [SessionDecodeKind.v1].
  final GenerationSession? session;

  /// Account that saved the session, when recorded (`owner_scope`).
  final String? ownerScope;

  /// Declared schema version, when one was present.
  final Object? version;

  /// The field that made the payload unreadable, when known.
  final String? field;

  /// Developer-facing reason; UI copy is chosen by the caller.
  final String? reason;

  bool get isReadable => kind == SessionDecodeKind.v1;

  @override
  String toString() =>
      'SessionDecodeResult(${kind.name}'
      '${field != null ? ', field: $field' : ''}'
      '${reason != null ? ', $reason' : ''})';
}

/// Version-aware reader/writer for the guided-generation session stored at
/// SharedPreferences `generation_session_v1` (master plan v2.6 §12.5,
/// Appendix D.4, G.5).
///
/// * A missing version means V1. `schema_version` is canonical;
///   `schemaVersion` is accepted only when the canonical key is absent.
/// * V1 required fields keep their real semantics: missing or wrongly typed
///   values are errors, never invented defaults. The only shipped fallback
///   is an absent/unknown `current_phase`, which still means `planning`.
/// * Content lists that are present but not lists are reported instead of
///   silently becoming empty (the legacy reader would drop that content).
/// * This build writes V1. Any higher version is read-only/export.
class GenerationSessionCodec {
  const GenerationSessionCodec._();

  /// Highest schema version this build can read and write.
  static const int currentVersion = 1;

  static const _requiredStrings = [
    'id',
    'created_at',
    'subject',
    'target_audience',
    'difficulty',
    'content_focus',
  ];

  static SessionDecodeResult decode(String raw) {
    SessionDecodeResult unreadable(String reason, {String? field}) =>
        SessionDecodeResult._(
          kind: SessionDecodeKind.unreadable,
          raw: raw,
          field: field,
          reason: reason,
        );

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      return unreadable('Malformed JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      return unreadable('Session must be a JSON object');
    }
    final json = decoded;
    final ownerScope = json['owner_scope'] is String
        ? json['owner_scope'] as String
        : null;

    // --- Version discriminator ---------------------------------------
    final hasCanonical = json.containsKey('schema_version');
    final hasAlias = json.containsKey('schemaVersion');
    final canonical = json['schema_version'];
    final alias = json['schemaVersion'];
    if (hasCanonical && hasAlias && canonical != alias) {
      return SessionDecodeResult._(
        kind: SessionDecodeKind.conflictingVersion,
        raw: raw,
        ownerScope: ownerScope,
        version: canonical,
        reason:
            'schema_version ($canonical) and schemaVersion ($alias) '
            'disagree',
      );
    }
    final Object? version = hasCanonical ? canonical : alias;
    if (version != null) {
      if (version is! int || version < 1) {
        return SessionDecodeResult._(
          kind: SessionDecodeKind.conflictingVersion,
          raw: raw,
          ownerScope: ownerScope,
          version: version,
          reason: 'schema_version must be a positive integer',
        );
      }
      if (version > currentVersion) {
        return SessionDecodeResult._(
          kind: SessionDecodeKind.unsupportedVersion,
          raw: raw,
          ownerScope: ownerScope,
          version: version,
          reason: 'schema_version $version is newer than this app supports',
        );
      }
    }

    // --- V1 adapter: actual required-field semantics ------------------
    for (final field in _requiredStrings) {
      if (!json.containsKey(field) || json[field] == null) {
        return unreadable('Missing required field', field: field);
      }
      if (json[field] is! String) {
        return unreadable('Expected a string', field: field);
      }
    }
    if (!json.containsKey('duration_minutes') ||
        json['duration_minutes'] == null) {
      return unreadable('Missing required field', field: 'duration_minutes');
    }
    if (json['duration_minutes'] is! int) {
      return unreadable('Expected an integer', field: 'duration_minutes');
    }
    if (DateTime.tryParse(json['created_at'] as String) == null) {
      return unreadable('Invalid date', field: 'created_at');
    }
    for (final field in const ['lesson_plan', 'review_result']) {
      final value = json[field];
      if (value != null && value is! Map) {
        return unreadable('Expected an object', field: field);
      }
    }
    for (final field in const ['terms', 'concepts', 'mcqs']) {
      final value = json[field];
      if (value == null) continue;
      if (value is! List) {
        return unreadable('Expected a list', field: field);
      }
      for (var i = 0; i < value.length; i++) {
        if (value[i] is! Map) {
          return unreadable('Expected an object', field: '$field[$i]');
        }
      }
    }

    try {
      return SessionDecodeResult._(
        kind: SessionDecodeKind.v1,
        raw: raw,
        session: GenerationSession.fromJson(json),
        ownerScope: ownerScope,
        version: version,
      );
    } catch (e) {
      // Defensive: any remaining legacy parse failure is still recoverable.
      return unreadable('Legacy reader failed: $e');
    }
  }

  /// Encodes [session] in the V1 shape the legacy reader understands,
  /// adding `owner_scope` (ignored by older builds) when known.
  static String encode(GenerationSession session, {String? ownerScope}) {
    final json = session.toJson();
    if (ownerScope != null) json['owner_scope'] = ownerScope;
    return jsonEncode(json);
  }
}
