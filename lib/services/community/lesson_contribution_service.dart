import 'package:supabase_flutter/supabase_flutter.dart';

/// Open licences a contributor may choose (server enforces the same list).
enum ContributionLicense {
  ccBy('CC-BY-4.0', 'CC BY 4.0', 'Others may reuse it with credit.'),
  ccBySa(
    'CC-BY-SA-4.0',
    'CC BY-SA 4.0',
    'Others may reuse it with credit and must share alike.',
  ),
  cc0('CC0-1.0', 'CC0', 'No rights reserved.');

  const ContributionLicense(this.wire, this.label, this.summary);
  final String wire;
  final String label;
  final String summary;
}

class ContributionStatus {
  const ContributionStatus({
    required this.id,
    required this.version,
    required this.status,
    this.issues = const [],
    this.reviewNote,
  });

  factory ContributionStatus.fromJson(Map<String, dynamic> j) =>
      ContributionStatus(
        id: j['id'] as String,
        version: (j['version'] as num).toInt(),
        status: j['status'] as String,
        issues: [
          for (final i in (j['issues'] ?? j['check_issues'] ?? []) as List)
            if (i is Map) '${i['code']}',
        ],
        reviewNote: j['review_note'] as String?,
      );

  final String id;
  final int version;

  /// `submitted`, `checks_failed`, `ready_for_publication`, `rejected`,
  /// `published`, `withdrawn` or `superseded`.
  final String status;

  /// Automated check codes when [status] is `checks_failed`.
  final List<String> issues;
  final String? reviewNote;

  bool get isOpen =>
      status == 'submitted' ||
      status == 'checks_failed' ||
      status == 'ready_for_publication';

  bool get canWithdraw => isOpen || status == 'published';
}

/// A refusal from the server, with a plain-language message.
class ContributionException implements Exception {
  ContributionException(this.code);

  final String code;

  String get message => switch (code) {
    'feature_disabled' => 'Sharing with the community is not available now.',
    'rights_attestation_required' =>
      'Please confirm you have the right to share this lesson.',
    'unsupported_license' => 'Please choose one of the offered licences.',
    'lesson_not_owned' => 'You can only share lessons you created.',
    'curriculum_lessons_not_contributable' =>
      'Course lessons from official curricula cannot be shared this way.',
    'rate_limited' => 'You have shared a lot today. Please try again tomorrow.',
    'contribution_already_open' => 'This lesson is already waiting for review.',
    'authentication_required' => 'Please sign in to share lessons.',
    'moderator_required' => 'Only moderators can do this.',
    'admin_required' => 'Only admins can publish.',
    'cannot_review_own_contribution' => 'You cannot review your own lesson.',
    'cannot_publish_own_contribution' => 'You cannot publish your own lesson.',
    'rejection_reason_required' => 'Please give a reason for rejecting.',
    'takedown_reason_required' => 'Please give a reason for the takedown.',
    'invalid_state_transition' =>
      'This contribution changed meanwhile. Refresh and try again.',
    'not_published' => 'Only published contributions can be taken down.',
    _ => 'Something went wrong. Your lesson was not changed.',
  };

  @override
  String toString() => code;
}

/// Calls the governed contribution RPCs (migration 20261112070000). The
/// server enforces the feature gate, ownership, licence, rights, checks and
/// rate limits; this client never decides any of them.
class LessonContributionService {
  LessonContributionService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const _knownCodes = {
    'feature_disabled',
    'rights_attestation_required',
    'unsupported_license',
    'lesson_not_owned',
    'curriculum_lessons_not_contributable',
    'rate_limited',
    'contribution_already_open',
    'authentication_required',
    'moderator_required',
    'admin_required',
    'cannot_review_own_contribution',
    'cannot_publish_own_contribution',
    'rejection_reason_required',
    'takedown_reason_required',
    'invalid_state_transition',
    'not_published',
  };

  static ContributionException _map(Object e) {
    final text = e is PostgrestException ? e.message : '$e';
    for (final code in _knownCodes) {
      if (text.contains(code)) return ContributionException(code);
    }
    return ContributionException('unknown');
  }

  Future<ContributionStatus> submit({
    required String lessonId,
    required ContributionLicense license,
    required bool rightsAttested,
    required bool aiAssisted,
  }) async {
    try {
      final raw = await _db.rpc(
        'submit_lesson_contribution',
        params: {
          'p_lesson_id': lessonId,
          'p_license': license.wire,
          'p_rights_attested': rightsAttested,
          'p_ai_assisted': aiAssisted,
        },
      );
      return ContributionStatus.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (e) {
      throw _map(e);
    }
  }

  /// The caller's most recent contribution for [lessonId], if any.
  Future<ContributionStatus?> latestFor(String lessonId) async {
    try {
      final rows = await _db
          .from('content_contributions')
          .select('id, version, status, check_issues, review_note')
          .eq('lesson_id', lessonId)
          .order('version', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return ContributionStatus.fromJson(Map<String, dynamic>.from(rows.first));
    } catch (_) {
      return null;
    }
  }

  /// Moderator queue (row-level security returns rows only to moderators).
  Future<List<ContributionQueueItem>> fetchQueue(List<String> statuses) async {
    final rows = await _db
        .from('content_contributions')
        .select(
          'id, version, status, license, ai_assisted, trust_tier, snapshot, '
          'check_issues, review_note, created_at, published_at',
        )
        .inFilter('status', statuses)
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final r in rows)
        ContributionQueueItem.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  Future<void> review(String id, {required bool approve, String? note}) =>
      _call('review_lesson_contribution', {
        'p_id': id,
        'p_decision': approve ? 'approve' : 'reject',
        'p_note': note,
      });

  Future<void> publish(String id) =>
      _call('publish_lesson_contribution', {'p_id': id});

  Future<void> takedown(String id, String reason) =>
      _call('takedown_lesson_contribution', {'p_id': id, 'p_reason': reason});

  Future<void> _call(String fn, Map<String, dynamic> params) async {
    try {
      await _db.rpc(fn, params: params);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> withdraw(String contributionId) async {
    try {
      await _db.rpc(
        'withdraw_lesson_contribution',
        params: {'p_id': contributionId},
      );
    } catch (e) {
      throw _map(e);
    }
  }
}

/// One row in the moderator queue, with the frozen snapshot to review.
class ContributionQueueItem {
  const ContributionQueueItem({
    required this.id,
    required this.version,
    required this.status,
    required this.license,
    required this.aiAssisted,
    required this.snapshot,
    required this.createdAt,
    this.issues = const [],
    this.reviewNote,
  });

  factory ContributionQueueItem.fromJson(Map<String, dynamic> j) =>
      ContributionQueueItem(
        id: j['id'] as String,
        version: (j['version'] as num).toInt(),
        status: j['status'] as String,
        license: j['license'] as String,
        aiAssisted: j['ai_assisted'] == true,
        snapshot: Map<String, dynamic>.from(j['snapshot'] as Map),
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime(1970),
        issues: [
          for (final i in (j['check_issues'] ?? []) as List)
            if (i is Map) '${i['code']}',
        ],
        reviewNote: j['review_note'] as String?,
      );

  final String id;
  final int version;
  final String status;
  final String license;
  final bool aiAssisted;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final List<String> issues;
  final String? reviewNote;

  String get title => '${snapshot['title'] ?? '(untitled)'}';

  List<Map<String, dynamic>> _list(String key) => [
    for (final e in (snapshot[key] as List?) ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];

  List<Map<String, dynamic>> get terms => _list('terms');
  List<Map<String, dynamic>> get concepts => _list('concepts');
  List<Map<String, dynamic>> get questions => _list('questions');
}
