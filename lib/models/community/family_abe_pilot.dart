import 'package:learning_core/learning_core.dart';

/// Predefined pilot cohort tracks combining Adult Basic Education (ABE) tools with vocational credential targets (ECO-08).
enum PilotCohortType {
  adultLiteracyDriverLicense,
  familySafetyOsha,
  abeReadingHealthFood;

  String toDbString() {
    switch (this) {
      case PilotCohortType.adultLiteracyDriverLicense:
        return 'adult_literacy_driver_license';
      case PilotCohortType.familySafetyOsha:
        return 'family_safety_osha';
      case PilotCohortType.abeReadingHealthFood:
        return 'abe_reading_health_food';
    }
  }

  static PilotCohortType fromDbString(String? val) {
    switch (val) {
      case 'family_safety_osha':
        return PilotCohortType.familySafetyOsha;
      case 'abe_reading_health_food':
        return PilotCohortType.abeReadingHealthFood;
      case 'adult_literacy_driver_license':
      default:
        return PilotCohortType.adultLiteracyDriverLicense;
    }
  }

  String get title {
    switch (this) {
      case PilotCohortType.adultLiteracyDriverLicense:
        return 'Adult Basic Literacy & Florida Driver\'s License';
      case PilotCohortType.familySafetyOsha:
        return 'Family Co-Learning & OSHA Workplace Safety';
      case PilotCohortType.abeReadingHealthFood:
        return 'ABE Reading Bridge & Healthcare / Food Safety';
    }
  }

  String get shortTag {
    switch (this) {
      case PilotCohortType.adultLiteracyDriverLicense:
        return 'Cohort A (Literacy + DMV)';
      case PilotCohortType.familySafetyOsha:
        return 'Cohort B (Family + OSHA)';
      case PilotCohortType.abeReadingHealthFood:
        return 'Cohort C (ABE + Health/Food)';
    }
  }
}

/// A structured pilot cohort combining adult literacy tools with credential milestones.
class PilotCohort {
  final String id;
  final PilotCohortType type;
  final String name;
  final String description;
  final String primarySubject;
  final String targetMilestone;
  final int estimatedSessions;
  final double recommendedSpeechRate;
  final List<String> targetSkills;

  String get shortTag => type.shortTag;

  const PilotCohort({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.primarySubject,
    required this.targetMilestone,
    this.estimatedSessions = 5,
    this.recommendedSpeechRate = 0.85,
    this.targetSkills = const [],
  });

  factory PilotCohort.fromJson(Map<String, dynamic> json) {
    return PilotCohort(
      id: json['id'] as String? ?? '',
      type: PilotCohortType.fromDbString(json['type'] as String?),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      primarySubject: json['primary_subject'] as String? ?? '',
      targetMilestone: json['target_milestone'] as String? ?? '',
      estimatedSessions: json['estimated_sessions'] as int? ?? 5,
      recommendedSpeechRate:
          (json['recommended_speech_rate'] as num?)?.toDouble() ?? 0.85,
      targetSkills: (json['target_skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toDbString(),
        'name': name,
        'description': description,
        'primary_subject': primarySubject,
        'target_milestone': targetMilestone,
        'estimated_sessions': estimatedSessions,
        'recommended_speech_rate': recommendedSpeechRate,
        'target_skills': targetSkills,
      };

  /// Canonical curated pilot cohorts.
  static const List<PilotCohort> standardCohorts = [
    PilotCohort(
      id: 'cohort_a_literacy_dmv',
      type: PilotCohortType.adultLiteracyDriverLicense,
      name: 'Adult Basic Literacy & Florida Driver\'s License',
      description:
          'Combines Orton-Gillingham phonics and survival sight words with Florida FLHSMV road sign and rules exam preparation.',
      primarySubject: 'Foundational Literacy',
      targetMilestone: 'FLHSMV Class E Driver Knowledge Exam',
      estimatedSessions: 6,
      recommendedSpeechRate: 0.80,
      targetSkills: [
        'Phonemic Awareness',
        'MUTCD Regulatory Signs',
        'Right-of-Way Rules',
        'Decodable CVC Blending',
      ],
    ),
    PilotCohort(
      id: 'cohort_b_family_osha',
      type: PilotCohortType.familySafetyOsha,
      name: 'Family Co-Learning & OSHA Workplace Safety',
      description:
          'Dual-track adult and youth safety education covering OSHA 10-Hour General Industry hazard recognition, PPE, and GHS pictograms.',
      primarySubject: 'Workplace Safety',
      targetMilestone: 'OSHA 10 General Industry Hazard Awareness',
      estimatedSessions: 5,
      recommendedSpeechRate: 0.85,
      targetSkills: [
        'OSHA Hazard Recognition',
        'GHS Hazard Pictograms',
        'Personal Protective Equipment (PPE)',
        'Lockout / Tagout (LOTO)',
      ],
    ),
    PilotCohort(
      id: 'cohort_c_abe_health_food',
      type: PilotCohortType.abeReadingHealthFood,
      name: 'ABE Reading Bridge & Healthcare / Food Safety',
      description:
          'Synchronized line reading for adult basic education paired with FDA Food Code temperature rules and prescription label comprehension.',
      primarySubject: 'Life Domains & Health',
      targetMilestone: 'FDA Food Safety & Rx Medication Literacy',
      estimatedSessions: 5,
      recommendedSpeechRate: 0.85,
      targetSkills: [
        'Prescription Label Literacy',
        'Emergency 911 Call Simulation',
        'FDA Food Danger Zone Temps',
        'Big 9 Allergen Identification',
      ],
    ),
  ];
}

/// Participant session record in a field pilot (ECO-08).
class PilotParticipantSession {
  final String id;
  final String participantId;
  final String cohortId;
  final int sessionIndex;
  final bool audioGuidanceEnabled;
  final double speechRate;
  final bool tactileTracingCompleted;
  final List<String> milestonesCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final String? notes;

  const PilotParticipantSession({
    required this.id,
    required this.participantId,
    required this.cohortId,
    required this.sessionIndex,
    this.audioGuidanceEnabled = true,
    this.speechRate = 0.85,
    this.tactileTracingCompleted = false,
    this.milestonesCompleted = const [],
    required this.startedAt,
    this.completedAt,
    this.durationSeconds = 0,
    this.notes,
  });

  factory PilotParticipantSession.fromJson(Map<String, dynamic> json) {
    return PilotParticipantSession(
      id: json['id'] as String? ?? '',
      participantId: json['participant_id'] as String? ?? '',
      cohortId: json['cohort_id'] as String? ?? '',
      sessionIndex: json['session_index'] as int? ?? 1,
      audioGuidanceEnabled: json['audio_guidance_enabled'] as bool? ?? true,
      speechRate: (json['speech_rate'] as num?)?.toDouble() ?? 0.85,
      tactileTracingCompleted:
          json['tactile_tracing_completed'] as bool? ?? false,
      milestonesCompleted: (json['milestones_completed'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'cohort_id': cohortId,
        'session_index': sessionIndex,
        'audio_guidance_enabled': audioGuidanceEnabled,
        'speech_rate': speechRate,
        'tactile_tracing_completed': tactileTracingCompleted,
        'milestones_completed': milestonesCompleted,
        'started_at': startedAt.toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        'duration_seconds': durationSeconds,
        if (notes != null) 'notes': notes,
      };
}

/// An assessment question used in diagnostic pre-tests or post-tests.
class DiagnosticQuestion {
  final String id;
  final String prompt;
  final String? audioPrompt;
  final List<String> options;
  final int correctIndex;
  final String conceptKey;
  final String explanation;

  const DiagnosticQuestion({
    required this.id,
    required this.prompt,
    this.audioPrompt,
    required this.options,
    required this.correctIndex,
    required this.conceptKey,
    required this.explanation,
  });

  factory DiagnosticQuestion.fromJson(Map<String, dynamic> json) {
    return DiagnosticQuestion(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      audioPrompt: json['audio_prompt'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      correctIndex: json['correct_index'] as int? ?? 0,
      conceptKey: json['concept_key'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        if (audioPrompt != null) 'audio_prompt': audioPrompt,
        'options': options,
        'correct_index': correctIndex,
        'concept_key': conceptKey,
        'explanation': explanation,
      };
}

/// Verified outcome record comparing pre-study baseline diagnostic to post-study assessment (ECO-09, Hake g).
class AssessmentOutcomeRecord {
  final String id;
  final String participantId;
  final String cohortId;
  final String topic;
  final double preScore;
  final double postScore;
  final double normalizedGain;
  final LearningGainCategory gainCategory;
  final int clarityRating; // 1-5 scale
  final String pacingFeedback; // 'too_slow', 'just_right', 'too_fast'
  final int audioHelpfulnessRating; // 1-5 scale
  final int confidenceRating; // 1-5 scale
  final DateTime evaluatedAt;
  final bool isVerified;
  final double? retentionScore;

  const AssessmentOutcomeRecord({
    required this.id,
    required this.participantId,
    required this.cohortId,
    required this.topic,
    required this.preScore,
    required this.postScore,
    required this.normalizedGain,
    required this.gainCategory,
    this.clarityRating = 5,
    this.pacingFeedback = 'just_right',
    this.audioHelpfulnessRating = 5,
    this.confidenceRating = 5,
    required this.evaluatedAt,
    this.isVerified = true,
    this.retentionScore,
  });

  factory AssessmentOutcomeRecord.fromScores({
    required String id,
    required String participantId,
    required String cohortId,
    required String topic,
    required double preScore,
    required double postScore,
    int clarityRating = 5,
    String pacingFeedback = 'just_right',
    int audioHelpfulnessRating = 5,
    int confidenceRating = 5,
    DateTime? evaluatedAt,
    bool isVerified = true,
    double? retentionScore,
  }) {
    final result = LearningGainCalculator.evaluate(
      preScore: preScore,
      postScore: postScore,
    );
    return AssessmentOutcomeRecord(
      id: id,
      participantId: participantId,
      cohortId: cohortId,
      topic: topic,
      preScore: preScore,
      postScore: postScore,
      normalizedGain: result.normalizedGain,
      gainCategory: result.category,
      clarityRating: clarityRating,
      pacingFeedback: pacingFeedback,
      audioHelpfulnessRating: audioHelpfulnessRating,
      confidenceRating: confidenceRating,
      evaluatedAt: evaluatedAt ?? DateTime.now(),
      isVerified: isVerified,
      retentionScore: retentionScore,
    );
  }

  factory AssessmentOutcomeRecord.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['gain_category'] as String?;
    LearningGainCategory cat;
    switch (categoryStr) {
      case 'high':
        cat = LearningGainCategory.high;
        break;
      case 'medium':
        cat = LearningGainCategory.medium;
        break;
      case 'low':
        cat = LearningGainCategory.low;
        break;
      case 'loss':
      default:
        cat = LearningGainCategory.loss;
        break;
    }

    return AssessmentOutcomeRecord(
      id: json['id'] as String? ?? '',
      participantId: json['participant_id'] as String? ?? '',
      cohortId: json['cohort_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      preScore: (json['pre_score'] as num?)?.toDouble() ?? 0.0,
      postScore: (json['post_score'] as num?)?.toDouble() ?? 0.0,
      normalizedGain: (json['normalized_gain'] as num?)?.toDouble() ?? 0.0,
      gainCategory: cat,
      clarityRating: json['clarity_rating'] as int? ?? 5,
      pacingFeedback: json['pacing_feedback'] as String? ?? 'just_right',
      audioHelpfulnessRating:
          json['audio_helpfulness_rating'] as int? ?? 5,
      confidenceRating: json['confidence_rating'] as int? ?? 5,
      evaluatedAt: json['evaluated_at'] != null
          ? DateTime.tryParse(json['evaluated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isVerified: json['is_verified'] as bool? ?? true,
      retentionScore: (json['retention_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'cohort_id': cohortId,
        'topic': topic,
        'pre_score': preScore,
        'post_score': postScore,
        'normalized_gain': normalizedGain,
        'gain_category': gainCategory.toDbString(),
        'clarity_rating': clarityRating,
        'pacing_feedback': pacingFeedback,
        'audio_helpfulness_rating': audioHelpfulnessRating,
        'confidence_rating': confidenceRating,
        'evaluated_at': evaluatedAt.toIso8601String(),
        'is_verified': isVerified,
        if (retentionScore != null) 'retention_score': retentionScore,
      };
}

