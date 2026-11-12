import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/generation_session.dart';
import '../models/generation_session_codec.dart';
import '../services/ai_prompt_service.dart';
import '../services/prompt_context_compressor.dart';

/// Maximum items per prompt to avoid quality degradation.
const int _maxTermsPerBatch = 8;
const int _maxConceptsPerBatch = 4;
const int _maxMcqsPerBatch = 5;

/// SharedPreferences key for persisted session.
const String _sessionStorageKey = 'generation_session_v1';

/// Riverpod provider for the guided generation wizard.
/// NOT autoDispose — session survives navigation. Cleared on import or discard.
final generationSessionProvider = StateNotifierProvider<
    GenerationSessionNotifier, GenerationSession?>(
  (ref) => GenerationSessionNotifier(),
);

/// Why a stored session could not be opened normally.
enum SessionRecoveryReason {
  /// The saved bytes are not a readable session (bad JSON, missing or
  /// wrongly typed required field, invalid date).
  unreadable,

  /// Saved by a newer app version this build cannot read.
  newerVersion,

  /// Contradictory or malformed version markers.
  conflictingVersion,

  /// Saved while a different account was signed in on this device. It is
  /// neither restored nor exported here.
  otherAccount,
}

/// A stored session that is being protected instead of opened.
@immutable
class SessionRecoveryInfo {
  const SessionRecoveryInfo({
    required this.reason,
    this.field,
    this.detail,
  });

  final SessionRecoveryReason reason;

  /// The field that made the session unreadable, when known.
  final String? field;

  /// Developer-facing detail (not shown verbatim to learners).
  final String? detail;

  /// Another account's draft is never exported to the current user.
  bool get canExport => reason != SessionRecoveryReason.otherAccount;
}

/// Manages the multi-prompt generation session, producing the right prompt
/// for each phase and accepting the AI's JSON response to advance the pipeline.
///
/// Persistence follows master plan v2.6 §12.5 / Appendix D.4 / G.5: the
/// legacy key `generation_session_v1` is never overwritten or removed while
/// it holds a session this build cannot open ("recovery pending"). New work
/// in that state is saved under [recoveryWorkKey] until the learner
/// explicitly exports or discards the protected session.
class GenerationSessionNotifier extends StateNotifier<GenerationSession?> {
  GenerationSessionNotifier() : super(null);

  static const _uuid = Uuid();

  /// SharedPreferences key holding the raw text of an unreadable session.
  static const corruptSessionBackupKey = '${_sessionStorageKey}_unreadable_raw';

  /// Where new work is saved while the legacy key is protected.
  static const recoveryWorkKey = '${_sessionStorageKey}_while_recovering';

  SessionRecoveryInfo? _recovery;
  String? _ownerScope;
  Future<void> _writes = Future<void>.value();

  /// Non-null while a stored session is protected instead of opened.
  SessionRecoveryInfo? get recovery => _recovery;

  /// Account that new sessions are saved for (null for signed-out use).
  /// Recorded as `owner_scope` so a shared device never restores one
  /// account's draft for another.
  set ownerScope(String? value) =>
      _ownerScope = (value == null || value.isEmpty) ? null : value;

  String get _writeKey =>
      _recovery == null ? _sessionStorageKey : recoveryWorkKey;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Save current session. Writes are serialized so an older snapshot can
  /// never land after a newer one.
  Future<void> _persist() {
    final snapshot = state;
    final key = _writeKey;
    final owner = _ownerScope;
    _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (snapshot == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(
            key,
            GenerationSessionCodec.encode(snapshot, ownerScope: owner),
          );
        }
      } catch (e) {
        debugPrint('Failed to persist generation session: $e');
      }
    });
    return _writes;
  }

  /// Completes when all queued saves have finished.
  Future<void> flushPersistence() => _writes;

  /// Try to load a previously saved session. Returns true if restored.
  ///
  /// When the saved session cannot be opened (unreadable, newer version,
  /// conflicting version, or another account's), its bytes are preserved,
  /// [recovery] is set, and the legacy key is protected from overwrite. Any
  /// work saved during an earlier recovery is restored instead.
  Future<bool> tryRestore({String? ownerScope}) async {
    this.ownerScope = ownerScope;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Failed to open session storage: $e');
      return false;
    }
    final raw = prefs.getString(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      _recovery = null;
      return false;
    }

    final result = GenerationSessionCodec.decode(raw);
    if (result.isReadable &&
        (result.ownerScope == null || result.ownerScope == _ownerScope)) {
      _recovery = null;
      state = result.session;
      return true;
    }

    _recovery = SessionRecoveryInfo(
      reason: switch (result.kind) {
        SessionDecodeKind.v1 => SessionRecoveryReason.otherAccount,
        SessionDecodeKind.unreadable => SessionRecoveryReason.unreadable,
        SessionDecodeKind.unsupportedVersion =>
          SessionRecoveryReason.newerVersion,
        SessionDecodeKind.conflictingVersion =>
          SessionRecoveryReason.conflictingVersion,
      },
      field: result.field,
      detail: result.reason,
    );
    debugPrint('Generation session protected for recovery: $result');
    if (_recovery!.canExport) await _preserveCorruptSession(raw);

    // Resume work saved during an earlier recovery, if it is ours.
    final work = prefs.getString(recoveryWorkKey);
    if (work != null && work.isNotEmpty) {
      final workResult = GenerationSessionCodec.decode(work);
      if (workResult.isReadable &&
          (workResult.ownerScope == null ||
              workResult.ownerScope == _ownerScope)) {
        state = workResult.session;
        return true;
      }
    }
    return false;
  }

  Future<void> _preserveCorruptSession(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep the first preserved copy; a later failure must not replace it.
      if (prefs.getString(corruptSessionBackupKey) == null) {
        await prefs.setString(corruptSessionBackupKey, raw);
      }
    } catch (e) {
      debugPrint('Failed to preserve unreadable generation session: $e');
    }
  }

  /// Raw text of a preserved unreadable session, for export/recovery.
  static Future<String?> readCorruptSessionBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(corruptSessionBackupKey);
  }

  /// The protected session's original text, byte-for-byte, for the learner
  /// to copy or save. Null when nothing is protected or it belongs to
  /// another account.
  Future<String?> exportProtectedSession() async {
    final recovery = _recovery;
    if (recovery == null || !recovery.canExport) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionStorageKey) ??
        prefs.getString(corruptSessionBackupKey);
  }

  /// Permanently removes the protected session after the learner confirms.
  /// Any work saved meanwhile becomes the normal saved session; it is read
  /// back before the temporary copy is removed.
  ///
  /// Returns false (leaving the temporary copy in place) if read-back fails.
  Future<bool> discardProtectedSession() async {
    if (_recovery == null) return true;
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final work = prefs.getString(recoveryWorkKey);
    if (work != null && work.isNotEmpty) {
      await prefs.setString(_sessionStorageKey, work);
      if (prefs.getString(_sessionStorageKey) != work) return false;
      await prefs.remove(recoveryWorkKey);
    } else {
      await prefs.remove(_sessionStorageKey);
    }
    await prefs.remove(corruptSessionBackupKey);
    _recovery = null;
    return true;
  }

  /// Check if a saved session exists without loading it.
  static Future<bool> hasSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_sessionStorageKey);
    return json != null && json.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Start a new generation session from user-supplied parameters.
  void startSession({
    required String subject,
    required String targetAudience,
    required int durationMinutes,
    required String difficulty,
    required String contentFocus,
  }) {
    state = GenerationSession(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      subject: subject,
      targetAudience: targetAudience,
      durationMinutes: durationMinutes,
      difficulty: difficulty,
      contentFocus: contentFocus,
    );
    _persist();
  }

  /// Restore a previously saved session (e.g. from local storage).
  void restoreSession(GenerationSession session) {
    state = session;
  }

  /// Discard the current session and clear storage.
  void clearSession() {
    state = null;
    _persist();
  }

  // ---------------------------------------------------------------------------
  // Prompt generation — returns the prompt text for the CURRENT phase.
  // ---------------------------------------------------------------------------

  /// Produces the prompt string the user should copy (or the app should
  /// send to an API) for the current phase of the session.
  ///
  /// Returns `null` if the session is complete or not started.
  String? getNextPrompt() {
    final s = state;
    if (s == null) return null;

    switch (s.currentPhase) {
      case GenerationPhase.planning:
        return AiPromptService.generateCurriculumPlanPrompt(
          subject: s.subject,
          targetAudience: s.targetAudience,
          durationMinutes: s.durationMinutes,
          difficulty: s.difficulty,
          contentFocus: s.contentFocus,
        );

      case GenerationPhase.generatingTerms:
        return AiPromptService.generateTermsPrompt(
          lessonPlan: s.lessonPlan!,
          batchStart: s.terms.length,
          batchSize: _batchSize(s.expectedTermCount - s.terms.length, _maxTermsPerBatch),
          difficulty: s.difficulty,
        );

      case GenerationPhase.generatingConcepts:
        return AiPromptService.generateConceptsPrompt(
          lessonPlan: s.lessonPlan!,
          generatedTerms: s.terms,
          batchStart: s.concepts.length,
          batchSize: _batchSize(s.expectedConceptCount - s.concepts.length, _maxConceptsPerBatch),
          difficulty: s.difficulty,
          compressedContext: PromptContextCompressor.buildContext(
            session: s,
            forPhase: GenerationPhase.generatingConcepts,
          ),
        );

      case GenerationPhase.generatingMcqs:
        return AiPromptService.generateMcqsPrompt(
          lessonPlan: s.lessonPlan!,
          generatedTerms: s.terms,
          generatedConcepts: s.concepts,
          batchStart: s.mcqs.length,
          batchSize: _batchSize(s.expectedMcqCount - s.mcqs.length, _maxMcqsPerBatch),
          compressedContext: PromptContextCompressor.buildContext(
            session: s,
            forPhase: GenerationPhase.generatingMcqs,
          ),
        );

      case GenerationPhase.reviewing:
        return AiPromptService.generateSelfReviewPrompt(
          lessonPlan: s.lessonPlan!,
          allContent: s.allContent,
        );

      case GenerationPhase.complete:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Response handling — user pastes the AI's JSON here.
  // ---------------------------------------------------------------------------

  /// Parse the raw AI response for the current phase and advance the session.
  /// Returns an error message if the JSON is invalid, or `null` on success.
  String? handleResponse(String rawJson) {
    final s = state;
    if (s == null) return 'No active session';

    try {
      final dynamic parsed = jsonDecode(rawJson);

      switch (s.currentPhase) {
        case GenerationPhase.planning:
          return _handlePlanResponse(s, parsed);
        case GenerationPhase.generatingTerms:
          return _handleContentBatch(s, parsed, 'terms');
        case GenerationPhase.generatingConcepts:
          return _handleContentBatch(s, parsed, 'concepts');
        case GenerationPhase.generatingMcqs:
          return _handleContentBatch(s, parsed, 'mcqs');
        case GenerationPhase.reviewing:
          return _handleReviewResponse(s, parsed);
        case GenerationPhase.complete:
          return 'Session is already complete';
      }
    } on FormatException catch (e) {
      state = s.copyWith(errorMessage: 'Invalid JSON: ${e.message}');
      return 'Invalid JSON: ${e.message}';
    }
  }

  /// Skip the review phase and go straight to complete.
  void skipReview() {
    final s = state;
    if (s == null || s.currentPhase != GenerationPhase.reviewing) return;
    state = s.copyWith(currentPhase: GenerationPhase.complete);
    _persist();
  }

  /// Get the assembled final lesson JSON (for import).
  Map<String, dynamic>? getAssembledLesson() => state?.assemble();

  // ---------------------------------------------------------------------------
  // Internal phase handlers
  // ---------------------------------------------------------------------------

  String? _handlePlanResponse(GenerationSession s, dynamic parsed) {
    if (parsed is! Map<String, dynamic>) {
      return 'Expected a JSON object with lesson_plan and content_manifest';
    }

    if (parsed['lesson_plan'] == null || parsed['content_manifest'] == null) {
      return 'Response missing required fields: lesson_plan, content_manifest';
    }

    state = s.copyWith(
      lessonPlan: parsed,
      currentPhase: GenerationPhase.generatingTerms,
      errorMessage: null,
    );
    _persist();
    return null;
  }

  String? _handleContentBatch(GenerationSession s, dynamic parsed, String type) {
    List<Map<String, dynamic>> items;

    if (parsed is List) {
      items = parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (parsed is Map<String, dynamic> && parsed[type] is List) {
      items = (parsed[type] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      return 'Expected a JSON array of $type items. '
          'Make sure you copied the entire response including the [ ] brackets.';
    }

    if (items.isEmpty) {
      return 'No items found in response';
    }

    // Validate required fields per content type
    final errors = _validateBatchSchema(items, type);
    if (errors.isNotEmpty) {
      final msg = 'Validation errors:\n${errors.join('\n')}';
      state = s.copyWith(errorMessage: msg);
      return msg;
    }

    switch (type) {
      case 'terms':
        final updated = [...s.terms, ...items];
        final nextPhase = updated.length >= s.expectedTermCount
            ? GenerationPhase.generatingConcepts
            : GenerationPhase.generatingTerms;
        state = s.copyWith(terms: updated, currentPhase: nextPhase, errorMessage: null);
      case 'concepts':
        final updated = [...s.concepts, ...items];
        final nextPhase = updated.length >= s.expectedConceptCount
            ? GenerationPhase.generatingMcqs
            : GenerationPhase.generatingConcepts;
        state = s.copyWith(concepts: updated, currentPhase: nextPhase, errorMessage: null);
      case 'mcqs':
        final updated = [...s.mcqs, ...items];
        final nextPhase = updated.length >= s.expectedMcqCount
            ? GenerationPhase.reviewing
            : GenerationPhase.generatingMcqs;
        state = s.copyWith(mcqs: updated, currentPhase: nextPhase, errorMessage: null);
    }

    _persist();
    return null;
  }

  /// Validate that each item in a batch has the required fields for its type.
  List<String> _validateBatchSchema(
      List<Map<String, dynamic>> items, String type) {
    final errors = <String>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final label = '${type.substring(0, type.length - 1)} ${i + 1}';
      switch (type) {
        case 'terms':
          if (_isBlank(item['title']) && _isBlank(item['term'])) {
            errors.add('$label: missing "title"');
          }
          if (_isBlank(item['content']) && _isBlank(item['definition'])) {
            errors.add('$label: missing "content"');
          }
        case 'concepts':
          if (_isBlank(item['title']) && _isBlank(item['concept_text'])) {
            errors.add('$label: missing "title"');
          }
          if (_isBlank(item['content']) && _isBlank(item['example_text'])) {
            errors.add('$label: missing "content"');
          }
        case 'mcqs':
          if (_isBlank(item['question']) && _isBlank(item['question_text'])) {
            errors.add('$label: missing "question"');
          }
          if (item['options'] is! List ||
              (item['options'] as List).length < 2) {
            errors.add('$label: missing or insufficient "options" (need at least 2)');
          }
          if (_isBlank(item['correct_answer'])) {
            errors.add('$label: missing "correct_answer"');
          }
      }
    }
    return errors;
  }

  static bool _isBlank(dynamic value) =>
      value == null || value.toString().trim().isEmpty;

  String? _handleReviewResponse(GenerationSession s, dynamic parsed) {
    if (parsed is! Map<String, dynamic>) {
      return 'Expected a JSON object with review_summary';
    }

    state = s.copyWith(
      reviewResult: parsed,
      currentPhase: GenerationPhase.complete,
      errorMessage: null,
    );
    _persist();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static int _batchSize(int remaining, int max) => min(remaining, max).clamp(1, max);
}
