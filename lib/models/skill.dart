/// Skill - individual competency that can be assessed
class Skill {
  final String id;
  final String name;
  final String slug;
  final String? category;
  final String? description;
  final String? iconUrl;
  final DateTime createdAt;

  const Skill({
    required this.id,
    required this.name,
    required this.slug,
    this.category,
    this.description,
    this.iconUrl,
    required this.createdAt,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      category: json['category'] as String?,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'category': category,
        'description': description,
        'icon_url': iconUrl,
        'created_at': createdAt.toIso8601String(),
      };

  Skill copyWith({
    String? id,
    String? name,
    String? slug,
    String? category,
    String? description,
    String? iconUrl,
    DateTime? createdAt,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Skill && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// User's stats for a specific skill
class UserSkillStats {
  final String id;
  final String userId;
  final String skillId;
  final int level; // 0-100
  final int totalAssessments;
  final int bestScore;
  final double averageScore;
  final DateTime? lastAssessedAt;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated from joins
  final Skill? skill;

  const UserSkillStats({
    required this.id,
    required this.userId,
    required this.skillId,
    this.level = 0,
    this.totalAssessments = 0,
    this.bestScore = 0,
    this.averageScore = 0,
    this.lastAssessedAt,
    this.isVerified = true,
    required this.createdAt,
    required this.updatedAt,
    this.skill,
  });

  factory UserSkillStats.fromJson(Map<String, dynamic> json) {
    return UserSkillStats(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      skillId: json['skill_id'] as String,
      level: json['level'] as int? ?? 0,
      totalAssessments: json['total_assessments'] as int? ?? 0,
      bestScore: json['best_score'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0,
      lastAssessedAt: json['last_assessed_at'] != null
          ? DateTime.parse(json['last_assessed_at'] as String)
          : null,
      isVerified: json['is_verified'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      skill: json['skills'] != null ? Skill.fromJson(json['skills']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'skill_id': skillId,
        'level': level,
        'total_assessments': totalAssessments,
        'best_score': bestScore,
        'average_score': averageScore,
        'last_assessed_at': lastAssessedAt?.toIso8601String(),
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Get tier name from level (0-100)
  SkillTier get tier => SkillTier.fromLevel(level);

  /// Progress within current tier (0.0 to 1.0)
  double get tierProgress {
    final tierStart = tier.minLevel;
    final tierEnd = tier.maxLevel;
    if (tierEnd == tierStart) return 1.0;
    return (level - tierStart) / (tierEnd - tierStart);
  }

  UserSkillStats copyWith({
    String? id,
    String? userId,
    String? skillId,
    int? level,
    int? totalAssessments,
    int? bestScore,
    double? averageScore,
    DateTime? lastAssessedAt,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    Skill? skill,
  }) {
    return UserSkillStats(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      skillId: skillId ?? this.skillId,
      level: level ?? this.level,
      totalAssessments: totalAssessments ?? this.totalAssessments,
      bestScore: bestScore ?? this.bestScore,
      averageScore: averageScore ?? this.averageScore,
      lastAssessedAt: lastAssessedAt ?? this.lastAssessedAt,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      skill: skill ?? this.skill,
    );
  }
}

/// Skill tier based on level
enum SkillTier {
  novice(0, 20, 'Novice', '🌱'),
  beginner(21, 40, 'Beginner', '🌿'),
  intermediate(41, 60, 'Intermediate', '🌳'),
  advanced(61, 80, 'Advanced', '⭐'),
  expert(81, 100, 'Expert', '🏆');

  final int minLevel;
  final int maxLevel;
  final String displayName;
  final String emoji;

  const SkillTier(this.minLevel, this.maxLevel, this.displayName, this.emoji);

  static SkillTier fromLevel(int level) {
    if (level <= 20) return SkillTier.novice;
    if (level <= 40) return SkillTier.beginner;
    if (level <= 60) return SkillTier.intermediate;
    if (level <= 80) return SkillTier.advanced;
    return SkillTier.expert;
  }

  String get fullDisplayName => '$emoji $displayName';
}

/// Skill categories
class SkillCategory {
  static const String programming = 'Programming';
  static const String data = 'Data';
  static const String design = 'Design';
  static const String business = 'Business';
  static const String softSkills = 'Soft Skills';
  static const String other = 'Other';

  static List<String> get all => [
        programming,
        data,
        design,
        business,
        softSkills,
        other,
      ];
}
