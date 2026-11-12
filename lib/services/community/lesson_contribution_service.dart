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
