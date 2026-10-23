import 'package:flutter/foundation.dart';

/// Represents a verification claim or credential for an educator.
///
/// Strictly distinguishes:
/// - 'self_declared': User-entered statement of teaching/practical experience.
/// - 'platform_vetted': Reviewed and verified by platform editorial staff.
/// - 'licensed_credential': Independently verified official/state licensure (e.g., FL DBPR, CNA, CPA, EPA).
@immutable
class EducatorVerification {
  final String id;
  final String educatorId;
  final String verificationType; // 'self_declared', 'platform_vetted', 'licensed_credential'
  final String? subjectId;
  final String? jurisdiction;
  final String? issuer;
  final String? credentialReference;
  final String status; // 'unverified', 'pending', 'verified', 'rejected', 'expired'
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EducatorVerification({
    required this.id,
    required this.educatorId,
    required this.verificationType,
    this.subjectId,
    this.jurisdiction,
    this.issuer,
    this.credentialReference,
    this.status = 'unverified',
    this.verifiedAt,
    this.verifiedBy,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVerified => status == 'verified';
  bool get isPending => status == 'pending';
  bool get isLicensed => verificationType == 'licensed_credential';
  bool get isPlatformVetted => verificationType == 'platform_vetted';
  bool get isSelfDeclared => verificationType == 'self_declared';

  factory EducatorVerification.fromJson(Map<String, dynamic> json) {
    return EducatorVerification(
      id: json['id'] as String,
      educatorId: json['educator_id'] as String,
      verificationType: json['verification_type'] as String? ?? 'self_declared',
      subjectId: json['subject_id'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      issuer: json['issuer'] as String?,
      credentialReference: json['credential_reference'] as String?,
      status: json['status'] as String? ?? 'unverified',
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      verifiedBy: json['verified_by'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
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
      'educator_id': educatorId,
      'verification_type': verificationType,
      'subject_id': subjectId,
      'jurisdiction': jurisdiction,
      'issuer': issuer,
      'credential_reference': credentialReference,
      'status': status,
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by': verifiedBy,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EducatorVerification copyWith({
    String? id,
    String? educatorId,
    String? verificationType,
    String? subjectId,
    String? jurisdiction,
    String? issuer,
    String? credentialReference,
    String? status,
    DateTime? verifiedAt,
    String? verifiedBy,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EducatorVerification(
      id: id ?? this.id,
      educatorId: educatorId ?? this.educatorId,
      verificationType: verificationType ?? this.verificationType,
      subjectId: subjectId ?? this.subjectId,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      issuer: issuer ?? this.issuer,
      credentialReference: credentialReference ?? this.credentialReference,
      status: status ?? this.status,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EducatorVerification &&
        other.id == id &&
        other.educatorId == educatorId &&
        other.verificationType == verificationType &&
        other.subjectId == subjectId &&
        other.jurisdiction == jurisdiction &&
        other.issuer == issuer &&
        other.credentialReference == credentialReference &&
        other.status == status &&
        other.verifiedAt == verifiedAt &&
        other.verifiedBy == verifiedBy &&
        other.expiresAt == expiresAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        educatorId,
        verificationType,
        subjectId,
        jurisdiction,
        issuer,
        credentialReference,
        status,
        verifiedAt,
        verifiedBy,
        expiresAt,
        createdAt,
        updatedAt,
      );
}
