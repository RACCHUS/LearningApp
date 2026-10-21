import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';

/// Service providing client operations for ECO-00B Trust, Safety & Moderation.
class ModerationService {
  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  ModerationService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  /// Check whether the current authenticated user has moderator privileges.
  /// Calls the zero-argument public RPC wrapper `is_moderator()`.
  Future<bool> isModerator() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final response = await _supabase.rpc('is_moderator');
      return response == true;
    } catch (_) {
      return false;
    }
  }

  /// Check whether the current authenticated user has administrator privileges.
  /// Calls the zero-argument public RPC wrapper `is_admin()`.
  Future<bool> isAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final response = await _supabase.rpc('is_admin');
      return response == true;
    } catch (_) {
      return false;
    }
  }

  /// Submit a moderation report against any supported platform entity.
  /// Enforces rate-limiting and duplicate prevention via `submit_moderation_report`.
  Future<String> submitReport({
    required ModerationTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? description,
  }) async {
    final response = await _supabase.rpc(
      'submit_moderation_report',
      params: {
        'p_target_type': targetType.dbValue,
        'p_target_id': targetId,
        'p_reason': reason.dbValue,
        'p_description': description,
      },
    );

    if (response == null) {
      throw const PostgrestException(
        message: 'Failed to create moderation report: empty response',
      );
    }
    return response.toString();
  }

  /// Fetch moderation reports for review, ordered newest first.
  /// Accessible only to authenticated users with the moderator or admin role.
  Future<List<ModerationReport>> fetchReports({
    ReportStatus? statusFilter,
    int limit = 50,
  }) async {
    var query = _supabase.from('moderation_reports').select();

    if (statusFilter != null) {
      query = query.eq('status', statusFilter.dbValue);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);

    final list = response as List<dynamic>;
    return list
        .map((row) => ModerationReport.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Apply an atomic moderation action to a report and its target entity.
  /// Transitions the report status and inserts an audit log entry atomically.
  Future<void> applyModerationAction({
    required String reportId,
    required ModerationActionType action,
    required String reason,
    String? notes,
  }) async {
    await _supabase.rpc(
      'apply_moderation_action',
      params: {
        'p_report_id': reportId,
        'p_action': action.dbValue,
        'p_reason': reason,
        'p_notes': notes,
      },
    );
  }

  /// Fetch past moderation actions for audit and history review.
  Future<List<ModerationAction>> fetchActionHistory({
    String? reportId,
    String? targetId,
    int limit = 50,
  }) async {
    var query = _supabase.from('moderation_actions').select();

    if (reportId != null) {
      query = query.eq('report_id', reportId);
    }
    if (targetId != null) {
      query = query.eq('target_id', targetId);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);

    final list = response as List<dynamic>;
    return list
        .map((row) => ModerationAction.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }
}
