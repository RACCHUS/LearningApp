import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/community/family_abe_pilot.dart';

/// Service orchestrating the Family & Adult Basic Education (ABE) Field Pilot (ECO-08, Phase 3).
///
/// Tracks participant cohort enrollments, session milestones, and accessibility accommodations.
class FieldPilotService extends ChangeNotifier {
  static const String _enrollmentKeyPrefix = 'pilot_enrollment_';
  static const String _sessionsKeyPrefix = 'pilot_sessions_';

  final SharedPreferences? _prefs;

  FieldPilotService({SharedPreferences? prefs}) : _prefs = prefs;

  /// Retrieves the standard curated pilot cohorts.
  List<PilotCohort> getAvailableCohorts() {
    return PilotCohort.standardCohorts;
  }

  /// Retrieves a cohort by ID.
  PilotCohort? getCohortById(String cohortId) {
    try {
      return PilotCohort.standardCohorts.firstWhere((c) => c.id == cohortId);
    } catch (_) {
      return null;
    }
  }

  /// Enrolls a learner/family into a pilot cohort track.
  Future<void> enrollParticipant({
    required String participantId,
    required String cohortId,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('$_enrollmentKeyPrefix$participantId', cohortId);
    notifyListeners();
  }

  /// Retrieves the active cohort ID for a participant.
  Future<String?> getParticipantCohortId(String participantId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString('$_enrollmentKeyPrefix$participantId');
  }

  /// Starts a new pilot learning session.
  Future<PilotParticipantSession> startSession({
    required String participantId,
    required String cohortId,
    bool audioGuidance = true,
    double speechRate = 0.85,
    bool tactileTracingCompleted = false,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final existingSessions = await getParticipantSessions(participantId);
    final sessionIndex = existingSessions.length + 1;
    final now = DateTime.now();

    final session = PilotParticipantSession(
      id: 'session_${now.millisecondsSinceEpoch}_$participantId',
      participantId: participantId,
      cohortId: cohortId,
      sessionIndex: sessionIndex,
      audioGuidanceEnabled: audioGuidance,
      speechRate: speechRate,
      tactileTracingCompleted: tactileTracingCompleted,
      startedAt: now,
    );

    existingSessions.insert(0, session);
    await _saveParticipantSessions(prefs, participantId, existingSessions);
    notifyListeners();
    return session;
  }

  /// Records that a learner completed a milestone during a pilot session.
  Future<PilotParticipantSession> recordMilestoneCompleted({
    required String participantId,
    required String sessionId,
    required String milestone,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final sessions = await getParticipantSessions(participantId);
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final current = sessions[idx];
    if (current.milestonesCompleted.contains(milestone)) {
      return current;
    }

    final updatedMilestones = [...current.milestonesCompleted, milestone];
    final updatedSession = PilotParticipantSession(
      id: current.id,
      participantId: current.participantId,
      cohortId: current.cohortId,
      sessionIndex: current.sessionIndex,
      audioGuidanceEnabled: current.audioGuidanceEnabled,
      speechRate: current.speechRate,
      tactileTracingCompleted: current.tactileTracingCompleted,
      milestonesCompleted: updatedMilestones,
      startedAt: current.startedAt,
      completedAt: current.completedAt,
      durationSeconds: current.durationSeconds,
      notes: current.notes,
    );

    sessions[idx] = updatedSession;
    await _saveParticipantSessions(prefs, participantId, sessions);
    notifyListeners();
    return updatedSession;
  }

  /// Completes an active pilot session.
  Future<PilotParticipantSession> completeSession({
    required String participantId,
    required String sessionId,
    int durationSeconds = 0,
    String? notes,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final sessions = await getParticipantSessions(participantId);
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final current = sessions[idx];
    final updatedSession = PilotParticipantSession(
      id: current.id,
      participantId: current.participantId,
      cohortId: current.cohortId,
      sessionIndex: current.sessionIndex,
      audioGuidanceEnabled: current.audioGuidanceEnabled,
      speechRate: current.speechRate,
      tactileTracingCompleted: current.tactileTracingCompleted,
      milestonesCompleted: current.milestonesCompleted,
      startedAt: current.startedAt,
      completedAt: DateTime.now(),
      durationSeconds: durationSeconds > 0
          ? durationSeconds
          : DateTime.now().difference(current.startedAt).inSeconds,
      notes: notes ?? current.notes,
    );

    sessions[idx] = updatedSession;
    await _saveParticipantSessions(prefs, participantId, sessions);
    notifyListeners();
    return updatedSession;
  }

  /// Retrieves all sessions for a participant.
  Future<List<PilotParticipantSession>> getParticipantSessions(
      String participantId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_sessionsKeyPrefix$participantId');
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) =>
              PilotParticipantSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing participant sessions: $e');
      return [];
    }
  }

  Future<void> _saveParticipantSessions(
    SharedPreferences prefs,
    String participantId,
    List<PilotParticipantSession> sessions,
  ) async {
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(
        '$_sessionsKeyPrefix$participantId', jsonEncode(jsonList));
  }

  /// Computes aggregate statistics for a pilot cohort.
  Future<Map<String, dynamic>> getCohortAggregateSummary(String cohortId) async {
    final cohort = getCohortById(cohortId);
    return {
      'cohort_id': cohortId,
      'cohort_name': cohort?.name ?? cohortId,
      'target_milestone': cohort?.targetMilestone ?? '',
      'target_skills_count': cohort?.targetSkills.length ?? 0,
      'standard_speech_rate': cohort?.recommendedSpeechRate ?? 0.85,
    };
  }
}

