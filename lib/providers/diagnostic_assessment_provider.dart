import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assessment/diagnostic_assessment.dart';
import '../services/assessment/diagnostic_assessment_service.dart';

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
  final int currentIndex;
  final List<DiagnosticAssessmentItem> items;
  final Map<String, dynamic> responses;
  final bool isSubmitting;
  final DiagnosticAssessmentReport? report;

  const DiagnosticSessionState({
    required this.targetId,
    required this.targetVersionId,
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
    DiagnosticSessionKey key,
  ) : super(
          DiagnosticSessionState(
            targetId: key.targetId,
            targetVersionId: key.targetVersionId,
          ),
        );

  void initialize(List<DiagnosticAssessmentItem> items) {
    state = DiagnosticSessionState(
      targetId: state.targetId,
      targetVersionId: state.targetVersionId,
      currentIndex: 0,
      items: items,
      responses: const {},
      isSubmitting: false,
    );
  }

  void recordResponse(String itemId, dynamic response) {
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
    if (!state.isCompleted) {
      throw StateError('Answer every diagnostic item before submitting.');
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

      final report = await _service.evaluateDiagnosticSession(
        userId: userId,
        targetId: state.targetId,
        targetTitle: targetTitle,
        targetVersionId: state.targetVersionId,
        items: state.items,
        submissions: submissions,
      );

      state = state.copyWith(
        isSubmitting: false,
        report: report,
      );
      return report;
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
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

    final updated =
        await _service.generateRemedialStudySet(report: activeReport);
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
