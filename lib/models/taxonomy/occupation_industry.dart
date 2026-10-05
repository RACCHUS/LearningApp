/// Occupation Industry model
/// Represents the BLS National Employment Matrix capturing occupation employment by NAICS industry sector.
class OccupationIndustry {
  final String occupationId;
  final String naicsCode;
  final String industryTitle;
  final int? employmentCount;
  final double? industryShare; // 0.0 to 1.0
  final int dataYear;
  final String? sourceReleaseId;

  const OccupationIndustry({
    required this.occupationId,
    required this.naicsCode,
    required this.industryTitle,
    this.employmentCount,
    this.industryShare,
    required this.dataYear,
    this.sourceReleaseId,
  });

  factory OccupationIndustry.fromJson(Map<String, dynamic> json) {
    return OccupationIndustry(
      occupationId: json['occupation_id'] as String,
      naicsCode: json['naics_code'] as String,
      industryTitle: json['industry_title'] as String,
      employmentCount: (json['employment_count'] as num?)?.toInt(),
      industryShare: (json['industry_share'] as num?)?.toDouble(),
      dataYear: (json['data_year'] as num).toInt(),
      sourceReleaseId: json['source_release_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'occupation_id': occupationId,
        'naics_code': naicsCode,
        'industry_title': industryTitle,
        'employment_count': employmentCount,
        'industry_share': industryShare,
        'data_year': dataYear,
        'source_release_id': sourceReleaseId,
      };
}
