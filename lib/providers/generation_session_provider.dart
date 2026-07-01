import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/generation_session.dart';
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

/// Manages the multi-prompt generation session, producing the right prompt
/// for each phase and accepting the AI's JSON response to advance the pipeline.
class GenerationSessionNotifier extends StateNotifier<GenerationSession?> {
  GenerationSessionNotifier() : super(null);

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Save current session to SharedPreferences.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state == null) {
        await prefs.remove(_sessionStorageKey);
      } else {
        await prefs.setString(_sessionStorageKey, state!.toJsonString());
      }
    } catch (e) {
      debugPrint('Failed to persist generation session: $e');
    }
  }

  /// Try to load a previously saved session. Returns true if restored.
  Future<bool> tryRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_sessionStorageKey);
      if (json != null && json.isNotEmpty) {
        state = GenerationSession.fromJsonString(json);
        return true;
      }
    } catch (e) {
      debugPrint('Failed to restore generation session: $e');
    }
    return false;
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
