import '../assessment_item.dart';
import 'mock_exam_blueprint.dart';

enum ExamSessionStatus {
  notStarted,
  inProgress,
  paused,
  completed,
  expired;

  bool get isActive => this == ExamSessionStatus.inProgress;
  bool get isFinished => this == ExamSessionStatus.completed || this == ExamSessionStatus.expired;
}

/// Represents an instantiated mock exam with live session state.
class MockExamSession {
  final String id;
  final MockExamBlueprint blueprint;
  final List<AssessmentItem> items;
  final Map<String, String> itemDomainMap; // itemId -> domainCode
  final Map<String, List<String>> itemConceptMap; // itemId -> conceptIds
  final Map<String, dynamic> userResponses; // itemId -> user answer payload
  final Set<String> flaggedItemIds;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration timeLimit;
  final int elapsedSeconds;
  final ExamSessionStatus status;

  const MockExamSession({
    required this.id,
    required this.blueprint,
    required this.items,
    this.itemDomainMap = const {},
    this.itemConceptMap = const {},
    this.userResponses = const {},
    this.flaggedItemIds = const {},
    required this.startedAt,
    this.completedAt,
    required this.timeLimit,
    this.elapsedSeconds = 0,
    this.status = ExamSessionStatus.inProgress,
  });

  int get totalQuestions => items.length;
  int get answeredCount => userResponses.length;
  int get flaggedCount => flaggedItemIds.length;
  int get unansweredCount => totalQuestions - answeredCount;

  Duration get remainingDuration {
    final remainingSecs = timeLimit.inSeconds - elapsedSeconds;
    return remainingSecs > 0 ? Duration(seconds: remainingSecs) : Duration.zero;
  }

  bool get isTimeExpired => elapsedSeconds >= timeLimit.inSeconds;
  bool get isCompleted => status.isFinished;

  double get progressRatio => totalQuestions > 0 ? (answeredCount / totalQuestions).clamp(0.0, 1.0) : 0.0;

  bool isItemAnswered(String itemId) => userResponses.containsKey(itemId);
  bool isItemFlagged(String itemId) => flaggedItemIds.contains(itemId);

  MockExamSession copyWith({
    String? id,
    MockExamBlueprint? blueprint,
    List<AssessmentItem>? items,
    Map<String, String>? itemDomainMap,
    Map<String, List<String>>? itemConceptMap,
    Map<String, dynamic>? userResponses,
    Set<String>? flaggedItemIds,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? timeLimit,
    int? elapsedSeconds,
    ExamSessionStatus? status,
  }) {
    return MockExamSession(
      id: id ?? this.id,
      blueprint: blueprint ?? this.blueprint,
      items: items ?? this.items,
      itemDomainMap: itemDomainMap ?? this.itemDomainMap,
      itemConceptMap: itemConceptMap ?? this.itemConceptMap,
      userResponses: userResponses ?? this.userResponses,
      flaggedItemIds: flaggedItemIds ?? this.flaggedItemIds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      timeLimit: timeLimit ?? this.timeLimit,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      status: status ?? this.status,
    );
  }
}
