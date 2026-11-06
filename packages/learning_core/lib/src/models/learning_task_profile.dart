/// Canonical Task Profile and Timing Regimes defined in
/// docs/learning_science/02_LEARNING_TASK_TAXONOMY.md.
enum LearningTaskTrack {
  sublexicalOrthographic,
  lexicalSemantic,
  conceptualRelational,
  referenceLookupSpeed,
  closedBookTimedMcq,
  proceduralExecution,
  openSynthesis;

  static LearningTaskTrack fromString(String val) {
    switch (val) {
      case 'sublexical_orthographic':
        return LearningTaskTrack.sublexicalOrthographic;
      case 'lexical_semantic':
        return LearningTaskTrack.lexicalSemantic;
      case 'conceptual_relational':
        return LearningTaskTrack.conceptualRelational;
      case 'reference_lookup_speed':
        return LearningTaskTrack.referenceLookupSpeed;
      case 'closed_book_timed_mcq':
        return LearningTaskTrack.closedBookTimedMcq;
      case 'procedural_execution':
        return LearningTaskTrack.proceduralExecution;
      case 'open_synthesis':
        return LearningTaskTrack.openSynthesis;
      default:
        return LearningTaskTrack.conceptualRelational;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case LearningTaskTrack.sublexicalOrthographic:
        return 'sublexical_orthographic';
      case LearningTaskTrack.lexicalSemantic:
        return 'lexical_semantic';
      case LearningTaskTrack.conceptualRelational:
        return 'conceptual_relational';
      case LearningTaskTrack.referenceLookupSpeed:
        return 'reference_lookup_speed';
      case LearningTaskTrack.closedBookTimedMcq:
        return 'closed_book_timed_mcq';
      case LearningTaskTrack.proceduralExecution:
        return 'procedural_execution';
      case LearningTaskTrack.openSynthesis:
        return 'open_synthesis';
    }
  }
}

enum TimingRegime {
  untimedMastery,
  relaxedFluency,
  examTimedStrict,
  referenceLookupRace;

  static TimingRegime fromString(String val) {
    switch (val) {
      case 'untimed_mastery':
        return TimingRegime.untimedMastery;
      case 'relaxed_fluency':
        return TimingRegime.relaxedFluency;
      case 'exam_timed_strict':
        return TimingRegime.examTimedStrict;
      case 'reference_lookup_race':
        return TimingRegime.referenceLookupRace;
      default:
        return TimingRegime.untimedMastery;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case TimingRegime.untimedMastery:
        return 'untimed_mastery';
      case TimingRegime.relaxedFluency:
        return 'relaxed_fluency';
      case TimingRegime.examTimedStrict:
        return 'exam_timed_strict';
      case TimingRegime.referenceLookupRace:
        return 'reference_lookup_race';
    }
  }
}

class LearningTaskProfile {
  final LearningTaskTrack track;
  final TimingRegime timingRegime;
  final bool allowsReferenceMaterials;
  final int defaultEstimatedSeconds;

  const LearningTaskProfile({
    required this.track,
    required this.timingRegime,
    this.allowsReferenceMaterials = false,
    this.defaultEstimatedSeconds = 60,
  });

  factory LearningTaskProfile.fromJson(Map<String, dynamic> json) {
    return LearningTaskProfile(
      track: LearningTaskTrack.fromString(json['track'] as String? ?? ''),
      timingRegime: TimingRegime.fromString(json['timing_regime'] as String? ?? ''),
      allowsReferenceMaterials:
          json['allows_reference_materials'] as bool? ?? false,
      defaultEstimatedSeconds: json['default_estimated_seconds'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track': track.toSnakeCase(),
      'timing_regime': timingRegime.toSnakeCase(),
      'allows_reference_materials': allowsReferenceMaterials,
      'default_estimated_seconds': defaultEstimatedSeconds,
    };
  }
}

