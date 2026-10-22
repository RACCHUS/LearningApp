import 'package:flutter/foundation.dart';

/// Represents an educator's subject association.
///
/// Encapsulates the principle: "Teacher does not own the subject or course."
/// Allows an educator to declare expertise and answer questions in a canonical
/// subject without being the monolithic author of the course or target.
@immutable
class EducatorSubject {
  final String id;
  final String educatorId;
  final String subjectId;
  final String subjectName;
  final String? experienceSummary;
  final String status; // 'active', 'inactive'
  final DateTime createdAt;

  const EducatorSubject({
    required this.id,
    required this.educatorId,
    required this.subjectId,
    required this.subjectName,
    this.experienceSummary,
    this.status = 'active',
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory EducatorSubject.fromJson(Map<String, dynamic> json) {
    return EducatorSubject(
      id: json['id'] as String,
      educatorId: json['educator_id'] as String,
      subjectId: json['subject_id'] as String,
      subjectName: json['subject_name'] as String? ?? 'Subject',
      experienceSummary: json['experience_summary'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'educator_id': educatorId,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'experience_summary': experienceSummary,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  EducatorSubject copyWith({
    String? id,
    String? educatorId,
    String? subjectId,
    String? subjectName,
    String? experienceSummary,
    String? status,
    DateTime? createdAt,
  }) {
    return EducatorSubject(
      id: id ?? this.id,
      educatorId: educatorId ?? this.educatorId,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      experienceSummary: experienceSummary ?? this.experienceSummary,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EducatorSubject &&
        other.id == id &&
        other.educatorId == educatorId &&
        other.subjectId == subjectId &&
        other.subjectName == subjectName &&
        other.experienceSummary == experienceSummary &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        educatorId,
        subjectId,
        subjectName,
        experienceSummary,
        status,
        createdAt,
      );
}
