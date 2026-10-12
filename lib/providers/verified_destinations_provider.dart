import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_target.dart';
import 'auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A deliberately narrow issuer-verified destination. This is NOT a
/// course, credential award, exam eligibility determination or popularity rank.
class VerifiedDestination {
  final String sourceNamespace;
  final String sourceKey;
  final String title;
  final String issuerName;
  final String destinationType;
  final String jurisdiction;
  final Uri officialUrl;
  final String requirementsStatus;
  final String popularityStatus;
  final DateTime verifiedAt;

  const VerifiedDestination({
    required this.sourceNamespace,
    required this.sourceKey,
    required this.title,
    required this.issuerName,
    required this.destinationType,
    required this.jurisdiction,
    required this.officialUrl,
    required this.requirementsStatus,
    required this.popularityStatus,
    required this.verifiedAt,
  });

  factory VerifiedDestination.fromJson(Map<String, dynamic> value) {
    final uri = Uri.parse(value['official_url'] as String);
    if (uri.scheme != 'https' || !uri.hasAuthority) {
      throw const FormatException('Reviewed issuer URL must use HTTPS');
    }
    return VerifiedDestination(
      sourceNamespace: value['source_namespace'] as String,
      sourceKey: value['source_key'] as String,
      title: value['title'] as String,
      issuerName: value['issuer_name'] as String,
      destinationType: value['destination_type'] as String,
      jurisdiction: value['jurisdiction'] as String,
      officialUrl: uri,
      requirementsStatus: value['requirements_status'] as String,
      popularityStatus: value['popularity_status'] as String,
      verifiedAt: DateTime.parse(value['verified_at'] as String),
    );
  }

  /// A regulator-issued professional license is distinct from its exam.
  TargetType? get supportedPrivateGoalType {
    switch (destinationType) {
      case 'certification':
        return TargetType.certification;
      case 'professional_license':
        return TargetType.professionalLicense;
      case 'licensure_exam':
        return TargetType.licensureExam;
      case 'standardized_exam':
        return TargetType.standardizedExam;
      case 'academic_program':
        return TargetType.academicProgram;
      default:
        return null;
    }
  }

  String get displayType {
    switch (destinationType) {
      case 'certification':
        return 'Certification';
      case 'professional_license':
        return 'Professional license';
      case 'licensure_exam':
        return 'Licensure exam';
      case 'standardized_exam':
        return 'Standardized exam';
      case 'academic_program':
        return 'Program category';
      case 'training_course':
        return 'Training course';
      default:
        return 'Destination';
    }
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return title.toLowerCase().contains(normalized) ||
        issuerName.toLowerCase().contains(normalized) ||
        destinationType.toLowerCase().contains(normalized) ||
        jurisdiction.toLowerCase().contains(normalized);
  }
}

/// Public RLS policy returns *only* reviewed/published destination identity.
/// Admin-only intake and evidence tables are never queried by the client.
final verifiedDestinationsProvider =
    FutureProvider<List<VerifiedDestination>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client
      .from('catalog_verified_destinations')
      .select(
        'source_namespace,source_key,destination_type,title,issuer_name,'
        'jurisdiction,official_url,requirements_status,popularity_status,'
        'verified_at,publication_status,editorial_order',
      )
      .eq('publication_status', 'published')
      .order('editorial_order', ascending: true)
      .limit(100);
  return [
    for (final raw in response)
      VerifiedDestination.fromJson(Map<String, dynamic>.from(raw)),
  ];
});


/// Outbound, issuer-owned resources only. Not Learning App lessons or courses.
class OfficialPreparationLink {
  final String resourceKey;
  final String title;
  final String resourceKind;
  final Uri resourceUrl;
  final String publisher;

  const OfficialPreparationLink({
    required this.resourceKey,
    required this.title,
    required this.resourceKind,
    required this.resourceUrl,
    required this.publisher,
  });

  factory OfficialPreparationLink.fromJson(Map<String, dynamic> row) {
    final uri = Uri.parse(row['resource_url'] as String);
    if (uri.scheme != 'https' || !uri.hasAuthority) {
      throw const FormatException('Preparation URL must use HTTPS');
    }
    return OfficialPreparationLink(
      resourceKey: row['resource_key'] as String,
      title: row['title'] as String,
      resourceKind: row['resource_kind'] as String,
      resourceUrl: uri,
      publisher: row['source_publisher'] as String,
    );
  }

  String get resourceTypeLabel {
    switch (resourceKind) {
      case 'official_study_guide':
        return 'Official study guide';
      case 'issuer_training':
        return 'Issuer training';
      case 'official_exam_plan':
        return 'Official exam plan';
      case 'issuer_prep_directory':
        return 'Issuer preparation options';
      case 'regulator_license_checklist':
        return 'Regulator licensing checklist';
      default:
        return 'Issuer resource';
    }
  }
}

final officialPreparationLinksProvider = FutureProvider.family<
    List<OfficialPreparationLink>, ({String namespace, String key})>((ref, identity) async {
  final rows = await Supabase.instance.client
      .from('catalog_destination_resources')
      .select('resource_key,title,resource_kind,resource_url,source_publisher')
      .eq('source_namespace', identity.namespace)
      .eq('source_key', identity.key)
      .eq('status', 'published')
      .order('sort_order')
      .limit(30);
  return [
    for (final row in rows)
      OfficialPreparationLink.fromJson(Map<String, dynamic>.from(row)),
  ];
});


/// Only the signed-in owner can read a private goal-to-issuer source link.
/// No admin-only candidate data or restricted eligibility records are queried.
final reviewedIssuerForGoalProvider =
    FutureProvider.family<VerifiedDestination?, String>((ref, targetId) async {
  final auth = ref.watch(authProvider); // Invalidate when account changes.
  if (auth is! AuthSuccess) return null;
  final client = Supabase.instance.client;
  final identity = await client
      .from('catalog_destination_goal_links')
      .select('source_namespace,source_key')
      .eq('target_id', targetId)
      .maybeSingle();
  if (identity == null) return null;
  final published = await client
      .from('catalog_verified_destinations')
      .select('source_namespace,source_key,destination_type,title,issuer_name,'
          'jurisdiction,official_url,requirements_status,popularity_status,verified_at')
      .eq('source_namespace', identity['source_namespace'] as String)
      .eq('source_key', identity['source_key'] as String)
      .eq('publication_status', 'published')
      .maybeSingle();
  return published == null
      ? null
      : VerifiedDestination.fromJson(Map<String, dynamic>.from(published));
});
