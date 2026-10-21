import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assessment/diagnostic_assessment.dart';
import '../services/assessment/diagnostic_assessment_service.dart';
import 'learning_context_provider.dart';

final diagnosticAssessmentServiceProvider =
    Provider<DiagnosticAssessmentService>((ref) {
  return DiagnosticAssessmentService();
});

typedef DiagnosticTargetKey = ({
  String targetId,
  String targetVersionId,
});

final diagnosticAvailabilityProvider = FutureProvider.autoDispose
    .family<DiagnosticAvailability, DiagnosticTargetKey>(
  (ref, key) async {
    final service = ref.watch(diagnosticAssessmentServiceProvider);
    return service.getAvailability(
      targetId: key.targetId,
      targetVersionId: key.targetVersionId,
    );
  },
);

final diagnosticItemsProvider = FutureProvider.autoDispose
    .family<List<DiagnosticAssessmentItem>, DiagnosticTargetKey>(
  (ref, key) async {
    final service = ref.watch(diagnosticAssessmentServiceProvider);
    return service.generatePreAssessment(
      targetId: key.targetId,
      targetVersionId: key.targetVersionId,
    );
  },
);

typedef DiagnosticSessionKey = ({
  String targetId,
  String targetVersionId,
});

class DiagnosticSessionState {
  final String targetId;
  final String targetVersionId;
  /// Null is intentionally target-wide. Scoped sessions keep exact identity.
  final String? examPartKey;
  final String? learnerId;
  final int currentIndex;
  final List<DiagnosticAssessmentItem> items;
  final Map<String, dynamic> responses;
  final bool isSubmitting;
  final DiagnosticAssessmentReport? report;

  const DiagnosticSessionState({
    required this.targetId,
    required this.targetVersionId,
    this.examPartKey,
    this.learnerId,
    this.currentIndex = 0,
    this.items = const [],
    this.responses = const {},
    this.isSubmitting = false,
    this.report,
  });

  bool get isCompleted =>
      items.isNotEmpty &&
      items.every((entry) => responses.containsKey(entry.item.id));

  DiagnosticSessionState copyWith({
    int? currentIndex,
    List<DiagnosticAssessmentItem>? items,
    Map<String, dynamic>? responses,
    bool? isSubmitting,
    DiagnosticAssessmentReport? report,
  }) {
    return DiagnosticSessionState(
      targetId: targetId,
      targetVersionId: targetVersionId,
      examPartKey: examPartKey,
      learnerId: learnerId,
      currentIndex: currentIndex ?? this.currentIndex,
      items: items ?? this.items,
      responses: responses ?? this.responses,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      report: report ?? this.report,
    );
  }
}

class DiagnosticSessionNotifier
    extends StateNotifier<DiagnosticSessionState> {
  final DiagnosticAssessmentService _service;

  DiagnosticSessionNotifier(
    this._service,
    DiagnosticSessionKey key, {
    String? examPartKey,
    String? learnerId,
  }) : super(
          DiagnosticSessionState(
            targetId: key.targetId,
            targetVersionId: key.targetVersionId,
            examPartKey: examPartKey,
            learnerId: learnerId,
          ),
        );

  void initialize(List<DiagnosticAssessmentItem> items) {
    if (state.isSubmitting || state.report != null) return;
    state = DiagnosticSessionState(
      targetId: state.targetId,
      targetVersionId: state.targetVersionId,
      examPartKey: state.examPartKey,
      learnerId: state.learnerId,
      currentIndex: 0,
      items: items,
      responses: const {},
      isSubmitting: false,
    );
  }

  void recordResponse(String itemId, dynamic response) {
    if (state.isSubmitting || state.report != null) return;
    if (state.examPartKey != null &&
        !state.items.any((item) => item.item.id == itemId)) {
      return;
    }
    final updated = Map<String, dynamic>.from(state.responses);
    if (!_hasMeaningfulResponse(response)) {
      updated.remove(itemId);
    } else {
      updated[itemId] = response;
    }
    state = state.copyWith(responses: updated);
  }

  bool _hasMeaningfulResponse(dynamic response) {
    if (response == null) return false;
    if (response is String) return response.trim().isNotEmpty;
    if (response is Iterable) return response.isNotEmpty;
    if (response is Map) return response.isNotEmpty;
    return true;
  }

  void nextQuestion() {
    if (state.currentIndex < state.items.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void previousQuestion() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void goToQuestion(int index) {
    if (index >= 0 && index < state.items.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  Future<DiagnosticAssessmentReport> submitAssessment({
    required String userId,
    required String targetTitle,
  }) async {
    if (state.isSubmitting || state.report != null) {
      throw StateError('This diagnostic has already been submitted.');
    }
    if (!state.isCompleted) {
      throw StateError('Answer every diagnostic item before submitting.');
    }
    if (state.learnerId != null && state.learnerId != userId) {
      throw StateError('Diagnostic belongs to a different learner session.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final submissions = state.items
          .map(
            (entry) => DiagnosticAnswerSubmission(
              itemId: entry.item.id,
              response: state.responses[entry.item.id],
            ),
          )
          .toList();

      final requestedPart = state.examPartKey;
      final report = requestedPart == null
          ? await _service.evaluateDiagnosticSession(
              userId: userId,
              targetId: state.targetId,
              targetTitle: targetTitle,
              targetVersionId: state.targetVersionId,
              items: state.items,
              submissions: submissions,
            )
          : await _service.evaluatePartDiagnosticSession(
              userId: userId,
              targetId: state.targetId,
              targetTitle: targetTitle,
              targetVersionId: state.targetVersionId,
              examPartKey: requestedPart,
              items: state.items,
              submissions: submissions,
            );

      // Async responses from an invalidated user-scoped provider may not
      // repopulate any new account's on-screen private diagnostic state.
      if (!mounted) {
        throw StateError('Diagnostic session is no longer active.');
      }
      if (requestedPart != null &&
          (report.examPartKey != requestedPart ||
              report.learnerId != userId)) {
        throw StateError('Diagnostic result has mismatched part or learner.');
      }

      state = state.copyWith(
        isSubmitting: false,
        report: report,
      );
      return report;
    } catch (_) {
      if (mounted) state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<DiagnosticAssessmentReport> createRemedialSet({
    DiagnosticAssessmentReport? reportOverride,
  }) async {
    final activeReport = reportOverride ?? state.report;
    if (activeReport == null) {
      throw StateError('No active diagnostic report.');
    }

    if (state.examPartKey != null &&
        (activeReport.examPartKey != state.examPartKey ||
            activeReport.learnerId != state.learnerId)) {
      throw StateError('Remedial report does not match selected learner/part.');
    }
    final updated =
        await _service.generateRemedialStudySet(report: activeReport);
    if (!mounted) {
      throw StateError('Diagnostic session is no longer active.');
    }
    state = state.copyWith(report: updated);
    return updated;
  }
}

final diagnosticSessionProvider = StateNotifierProvider.autoDispose.family<
    DiagnosticSessionNotifier,
    DiagnosticSessionState,
    DiagnosticSessionKey>((ref, key) {
  final service = ref.watch(diagnosticAssessmentServiceProvider);
  return DiagnosticSessionNotifier(service, key);
});

/// Separate scoped providers avoid accidental reuse of whole-target caches.
/// These are not wired to learner launch until part-specific review gates pass.
typedef ExamPartDiagnosticKey = ({
  String targetId,
  String targetVersionId,
  String examPartKey,
});

final examPartDiagnosticAvailabilityProvider = FutureProvider.autoDispose
    .family<DiagnosticAvailability, ExamPartDiagnosticKey>((ref, key) async {
  return ref.watch(diagnosticAssessmentServiceProvider).getAvailability(
    targetId: key.targetId,
    targetVersionId: key.targetVersionId,
    examPartKey: key.examPartKey,
  );
});

final examPartDiagnosticItemsProvider = FutureProvider.autoDispose
    .family<List<DiagnosticAssessmentItem>, ExamPartDiagnosticKey>((ref, key) async {
  return ref.watch(diagnosticAssessmentServiceProvider).generatePreAssessment(
    targetId: key.targetId,
    targetVersionId: key.targetVersionId,
    examPartKey: key.examPartKey,
  );
});

/// An explicit selected part must also be keyed by learner so that responses,
/// reports and in-flight submissions do not carry across a shared-device
/// account switch. This provider does not infer a part from Learn focus.
typedef ScopedDiagnosticSessionKey = ({
  String targetId,
  String targetVersionId,
  String examPartKey,
  String learnerId,
});

final scopedDiagnosticSessionProvider = StateNotifierProvider.autoDispose.family<
    DiagnosticSessionNotifier,
    DiagnosticSessionState,
    ScopedDiagnosticSessionKey>((ref, key) {
  final currentLearner = ref.watch(learnerIdProvider);
  // No cross-owner session can be opened with a stale UI key.
  if (key.learnerId != currentLearner) {
    throw StateError('Cannot open a diagnostic session for another learner.');
  }
  return DiagnosticSessionNotifier(
    ref.watch(diagnosticAssessmentServiceProvider),
    (targetId: key.targetId, targetVersionId: key.targetVersionId),
    examPartKey: key.examPartKey,
    learnerId: key.learnerId,
  );
});
