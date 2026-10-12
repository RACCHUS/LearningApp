import 'package:flutter_riverpod/flutter_riverpod.dart';
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
