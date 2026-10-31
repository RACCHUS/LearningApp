import 'package:flutter/foundation.dart';

/// Represents an educator profile in the community learning system.
///
/// Designed under the invariant: "Teacher does not own the subject or course."
/// Allows knowledgeable individuals to establish a contributor identity, share expertise,
/// and answer learner questions.
@immutable
class EducatorProfile {
  final String id;
  final String displayName;
  final String? headline;
  final String? bio;
  final String? avatarUrl;
  final List<String> languages;
  final bool isAcceptingQuestions;
  final String status; // 'draft', 'active', 'paused', 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;

  const EducatorProfile({
    required this.id,
    required this.displayName,
    this.headline,
    this.bio,
    this.avatarUrl,
    this.languages = const ['en'],
    this.isAcceptingQuestions = true,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isDraft => status == 'draft';

  factory EducatorProfile.fromJson(Map<String, dynamic> json) {
    return EducatorProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Educator',
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['en'],
      isAcceptingQuestions: json['is_accepting_questions'] as bool? ?? true,
      status: json['status'] as String? ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'headline': headline,
      'bio': bio,
      'avatar_url': avatarUrl,
      'languages': languages,
      'is_accepting_questions': isAcceptingQuestions,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EducatorProfile copyWith({
    String? id,
    String? displayName,
    String? headline,
    String? bio,
    String? avatarUrl,
    List<String>? languages,
    bool? isAcceptingQuestions,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EducatorProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      headline: headline ?? this.headline,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      languages: languages ?? this.languages,
      isAcceptingQuestions: isAcceptingQuestions ?? this.isAcceptingQuestions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EducatorProfile &&
        other.id == id &&
        other.displayName == displayName &&
        other.headline == headline &&
        other.bio == bio &&
        other.avatarUrl == avatarUrl &&
        listEquals(other.languages, languages) &&
        other.isAcceptingQuestions == isAcceptingQuestions &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        headline,
        bio,
        avatarUrl,
        Object.hashAll(languages),
        isAcceptingQuestions,
        status,
        createdAt,
        updatedAt,
      );
}
