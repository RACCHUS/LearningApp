import 'package:supabase_flutter/supabase_flutter.dart';

/// Exact owner-scoped inventory only. This is NOT a retention policy.
class ReferencePracticeErasurePreview {
  final String ownerId;
  final int events;
  final int grades;
  final int editions;
  final String fingerprint;

  const ReferencePracticeErasurePreview({
    required this.ownerId,
    required this.events,
    required this.grades,
    required this.editions,
    required this.fingerprint,
  });

  factory ReferencePracticeErasurePreview.parse(
    Map<String, dynamic> value, String ownerId,
  ) {
    const expected = {
      'scope', 'owner_auth_uid', 'event_count', 'graded_count',
      'edition_count', 'snapshot_fingerprint',
    };
    final events = value['event_count'];
    final grades = value['graded_count'];
    final editions = value['edition_count'];
    final fingerprint = value['snapshot_fingerprint'];
    if (value.length != expected.length ||
        value.keys.toSet().difference(expected).isNotEmpty ||
        value['scope'] != 'reference-practice-all-editions' ||
        value['owner_auth_uid'] != ownerId ||
        events is! int || events < 0 || events > 5000 ||
        grades is! int || grades < 0 || grades > events ||
        editions is! int || editions < 0 || editions > events ||
        (events == 0 && (grades != 0 || editions != 0)) ||
        fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(fingerprint)) {
      throw const FormatException('Invalid owner erasure preview');
    }
    return ReferencePracticeErasurePreview(
      ownerId: ownerId,
      events: events,
      grades: grades,
      editions: editions,
      fingerprint: fingerprint,
    );
  }
}

class ReferencePracticeErasureReceipt {
  final int deleted;
  final int remaining;

  const ReferencePracticeErasureReceipt({
    required this.deleted,
    required this.remaining,
  });

  factory ReferencePracticeErasureReceipt.parse(
    Map<String, dynamic> value, String ownerId,
    ReferencePracticeErasurePreview preview,
  ) {
    const expected = {
      'scope', 'owner_auth_uid', 'deleted_events', 'remaining_events',
    };
    final deleted = value['deleted_events'];
    final remaining = value['remaining_events'];
    if (value.length != expected.length ||
        value.keys.toSet().difference(expected).isNotEmpty ||
        value['scope'] != 'reference-practice-all-editions' ||
        value['owner_auth_uid'] != ownerId ||
        deleted is! int || deleted != preview.events ||
        remaining is! int || remaining < 0) {
      throw const FormatException('Invalid erasure receipt');
    }
    return ReferencePracticeErasureReceipt(
      deleted: deleted, remaining: remaining,
    );
  }
}

/// Direct client calls run as an owner with explicit RLS; never service_role.
/// The user must first preview the exact event set, then type an exact phrase.
class ExamReferencePracticeErasureService {
  static const confirmationPhrase = 'DELETE REFERENCE PRACTICE';

  final SupabaseClient _client;
  final Future<dynamic> Function()? _testPreview;
  final Future<dynamic> Function(int count, String fingerprint, String phrase)?
      _testErase;

  ExamReferencePracticeErasureService({
    SupabaseClient? client,
    Future<dynamic> Function()? testPreview,
    Future<dynamic> Function(int count, String fingerprint, String phrase)?
        testErase,
  }) : _client = client ?? Supabase.instance.client,
       _testPreview = testPreview, _testErase = testErase;

  void _requireOwner(String ownerId) {
    final user = _client.auth.currentUser;
    if (ownerId.isEmpty || user == null || user.isAnonymous ||
        user.id != ownerId) {
      throw StateError('Reference practice ownership changed');
    }
  }

  Future<ReferencePracticeErasurePreview> preview({
    required String expectedOwnerId,
  }) async {
    _requireOwner(expectedOwnerId);
    final dynamic data = _testPreview != null
        ? await _testPreview()
        : await _client.rpc('exam_reference_drill_erasure_preview');
    _requireOwner(expectedOwnerId);
    if (data is! Map) {
      throw const FormatException('Invalid erasure inventory');
    }
    return ReferencePracticeErasurePreview.parse(
      Map<String, dynamic>.from(data), expectedOwnerId,
    );
  }

  Future<ReferencePracticeErasureReceipt> deletePreviewed({
    required String expectedOwnerId,
    required ReferencePracticeErasurePreview preview,
    required String exactConfirmation,
  }) async {
    _requireOwner(expectedOwnerId);
    if (preview.ownerId != expectedOwnerId || preview.events < 1 ||
        exactConfirmation != confirmationPhrase) {
      throw StateError('Fresh preview and exact confirmation are required');
    }
    // The server independently compares its locked owner rowset against
    // the preview count/fingerprint; stale previews cannot delete new rows.
    final dynamic data = _testErase != null
        ? await _testErase(preview.events, preview.fingerprint, exactConfirmation)
        : await _client.rpc('exam_reference_drill_erase_owned', params: {
            'p_expected_count': preview.events,
            'p_expected_fingerprint': preview.fingerprint,
            'p_confirmation': exactConfirmation,
          });
    _requireOwner(expectedOwnerId);
    if (data is! Map) {
      throw const FormatException('Invalid erasure result');
    }
    return ReferencePracticeErasureReceipt.parse(
      Map<String, dynamic>.from(data), expectedOwnerId, preview,
    );
  }
}
