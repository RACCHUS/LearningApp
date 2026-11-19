import 'package:supabase_flutter/supabase_flutter.dart';

/// One need on the public board. [votes] is `null` below the server's
/// small-cohort floor (shown as "a few learners").
class WantedNeed {
  const WantedNeed({
    required this.id,
    required this.title,
    this.details,
    this.subjectTag,
    this.votes,
    this.hasVoted = false,
    this.linked = 0,
    this.status = 'open',
  });

  factory WantedNeed.fromJson(Map<String, dynamic> j) => WantedNeed(
    id: j['id'] as String,
    title: j['title'] as String,
    details: j['details'] as String?,
    subjectTag: j['subject_tag'] as String?,
    votes: (j['votes'] as num?)?.toInt(),
    hasVoted: j['has_voted'] == true,
    linked: (j['linked'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? 'open',
  );

  final String id;
  final String title;
  final String? details;
  final String? subjectTag;
  final int? votes;
  final bool hasVoted;
  final int linked;

  /// `proposed`, `open`, `fulfilled`, `closed` or `rejected`.
  final String status;

  String get demand =>
      votes == null ? 'Wanted by a few learners' : 'Wanted by $votes learners';
}

/// A contribution that can be linked to a need.
class LinkableContribution {
  const LinkableContribution(this.id, this.title, this.status);

  final String id;
  final String title;
  final String status;

  bool get isPublished => status == 'published';
}

/// A link a moderator sees when deciding whether a need is fulfilled.
class NeedLink {
  const NeedLink(this.needId, this.contribution);

  final String needId;
  final LinkableContribution contribution;
}

/// A server refusal with a plain-language message.
class WantedBoardException implements Exception {
  WantedBoardException(this.code);

  final String code;

  static const codes = [
    'feature_disabled',
    'authentication_required',
    'rate_limited',
    'invalid_need',
    'need_not_open',
    'need_not_found',
    'contribution_not_owned',
    'moderator_required',
    'cannot_review_own_need',
    'rejection_reason_required',
    'published_link_required',
    'invalid_state_transition',
    'note_too_long',
  ];

  static WantedBoardException from(Object e) {
    final text = e is PostgrestException ? e.message : '$e';
    for (final c in codes) {
      if (text.contains(c)) return WantedBoardException(c);
    }
    return WantedBoardException('unknown');
  }

  String get message => switch (code) {
    'feature_disabled' => 'The Wanted Board is not available right now.',
    'authentication_required' => 'Please sign in to use the Wanted Board.',
    'rate_limited' => 'You have done a lot today. Please try again tomorrow.',
    'invalid_need' =>
      'Please give a short title (5–120 characters) and a simple tag such '
          'as "excel".',
    'need_not_open' => 'This request is no longer open.',
    'need_not_found' => 'This request no longer exists.',
    'contribution_not_owned' =>
      'You can link only lessons you shared yourself.',
    'moderator_required' => 'Only moderators can do this.',
    'cannot_review_own_need' => 'Another moderator must review your request.',
    'rejection_reason_required' => 'Please give a reason for rejecting.',
    'published_link_required' =>
      'Choose a linked lesson that has been published.',
    'invalid_state_transition' =>
      'This request changed meanwhile. Refresh and try again.',
    'note_too_long' => 'Please keep the note under 1000 characters.',
    _ => 'Something went wrong. Nothing was changed.',
  };

  @override
  String toString() => code;
}

/// Calls the Wanted Board RPCs (migration 20261119010000). The server checks
/// the gate, sign-in, roles, ownership, formats and rate limits.
class WantedBoardService {
  WantedBoardService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw WantedBoardException.from(e);
    }
  }

  /// Open needs, most wanted first.
  Future<List<WantedNeed>> board() => _guard(() async {
    final rows = await _db.rpc('wanted_board') as List;
    return [
      for (final r in rows) WantedNeed.fromJson(Map<String, dynamic>.from(r)),
    ];
  });

  Future<void> propose(String title, {String? details, String? tag}) => _guard(
    () => _db.rpc(
      'propose_wanted_need',
      params: {'p_title': title, 'p_details': details, 'p_subject_tag': tag},
    ),
  );

  Future<void> vote(String needId, bool vote) => _guard(
    () => _db.rpc('vote_wanted_need', params: {'p_id': needId, 'p_vote': vote}),
  );

  /// The caller's own contributions that may be linked.
  Future<List<LinkableContribution>> myContributions() => _guard(() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _db
        .from('content_contributions')
        .select('id, status, snapshot')
        .eq('contributor_id', uid)
        .inFilter('status', [
          'submitted',
          'checks_failed',
          'ready_for_publication',
          'published',
        ])
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) _linkable(r)];
  });

  static LinkableContribution _linkable(Map<String, dynamic> r) {
    final snapshot = r['snapshot'];
    final title = snapshot is Map ? '${snapshot['title'] ?? 'Untitled'}' : '';
    return LinkableContribution(
      r['id'] as String,
      title.isEmpty ? 'Untitled' : title,
      r['status'] as String,
    );
  }

  Future<void> link(String needId, String contributionId) => _guard(
    () => _db.rpc(
      'link_contribution_to_need',
      params: {'p_need_id': needId, 'p_contribution_id': contributionId},
    ),
  );

  /// Moderators: needs in [status] (RLS shows moderators every row).
  Future<List<WantedNeed>> needsWithStatus(String status) => _guard(() async {
    final rows = await _db
        .from('content_wanted_needs')
        .select('id, title, details, subject_tag, status')
        .eq('status', status)
        .order('created_at')
        .limit(200);
    return [for (final r in rows) WantedNeed.fromJson(r)];
  });

  /// Moderators: contributions linked to [needIds].
  Future<List<NeedLink>> linksFor(List<String> needIds) => _guard(() async {
    if (needIds.isEmpty) return const [];
    final rows = await _db
        .from('content_wanted_links')
        .select('need_id, content_contributions(id, status, snapshot)')
        .inFilter('need_id', needIds);
    return [
      for (final r in rows)
        if (r['content_contributions'] is Map)
          NeedLink(
            r['need_id'] as String,
            _linkable(
              Map<String, dynamic>.from(r['content_contributions'] as Map),
            ),
          ),
    ];
  });

  Future<void> review(String needId, {required bool approve, String? note}) =>
      _guard(
        () => _db.rpc(
          'review_wanted_need',
          params: {'p_id': needId, 'p_approve': approve, 'p_note': note},
        ),
      );

  Future<void> setStatus(
    String needId,
    String status, {
    String? contributionId,
    String? note,
  }) => _guard(
    () => _db.rpc(
      'set_wanted_need_status',
      params: {
        'p_id': needId,
        'p_status': status,
        'p_contribution_id': contributionId,
        'p_note': note,
      },
    ),
  );
}
