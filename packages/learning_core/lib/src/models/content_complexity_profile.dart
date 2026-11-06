/// Cold-start content complexity (Haladyna & Reading Demand).
///
/// Content Complexity Profile != Psychometric Item Difficulty (b_i) != FSRS-6 state.
/// This distinction is strictly enforced per Learning Science §4.
class ContentComplexityProfile {
  final double estimatedReadingGrade;
  final int technicalTermCount;
  final String complexityAssessmentStatus;

  const ContentComplexityProfile({
    required this.estimatedReadingGrade,
    required this.technicalTermCount,
    this.complexityAssessmentStatus = 'unassessed',
  });

  factory ContentComplexityProfile.fromJson(Map<String, dynamic> json) {
    return ContentComplexityProfile(
      estimatedReadingGrade:
          (json['estimated_reading_grade'] as num?)?.toDouble() ?? 6.0,
      technicalTermCount: json['technical_term_count'] as int? ?? 0,
      complexityAssessmentStatus:
          json['complexity_assessment_status'] as String? ?? 'unassessed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated_reading_grade': estimatedReadingGrade,
      'technical_term_count': technicalTermCount,
      'complexity_assessment_status': complexityAssessmentStatus,
    };
  }
}

