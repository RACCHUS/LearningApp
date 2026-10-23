import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';

/// Service managing educator identities, subject associations, and verification claims (ECO-04).
///
/// Implements Phase 2 (W2) Educator Architecture:
/// - "Teacher does not own the subject or course."
/// - Separation of self-declared claims from platform-vetted and licensed regulatory credentials.
/// - Gate 2 launch gate: educator profiles remain private/preview-only until Gate 2 clearance.
class EducatorService {
  final _logger = AppLogger('EducatorService');

  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  EducatorService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  /// Returns current authenticated user ID, or null if unauthenticated.
  String? get currentUserId {
    try {
      return _supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Broadcast stream of authentication state changes.
  Stream<AuthState>? get authStateChanges {
    try {
      return _supabase.auth.onAuthStateChange;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the educator profile for the current authenticated user.
  Future<EducatorProfile?> fetchMyProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return fetchProfile(uid);
  }

  /// Fetches an educator profile by ID.
  Future<EducatorProfile?> fetchProfile(String educatorId) async {
    try {
      final res = await _supabase
          .from('educator_profiles')
          .select()
          .eq('id', educatorId)
          .maybeSingle();

      if (res == null) return null;
      return EducatorProfile.fromJson(res);
    } catch (e, stack) {
      _logger.error('Failed to fetch educator profile for $educatorId', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Upserts current user's educator profile using the hardened RPC.
  Future<EducatorProfile?> upsertMyProfile({
    required String displayName,
    String? headline,
    String? bio,
    String? avatarUrl,
    List<String> languages = const ['en'],
    bool isAcceptingQuestions = true,
    String status = 'draft',
  }) async {
    try {
      final res = await _supabase.rpc('upsert_my_educator_profile', params: {
        'p_display_name': displayName,
        'p_headline': headline,
        'p_bio': bio,
        'p_avatar_url': avatarUrl,
        'p_languages': languages,
        'p_is_accepting_questions': isAcceptingQuestions,
        'p_status': status,
      });

      if (res is Map<String, dynamic>) {
        return EducatorProfile.fromJson(res);
      }
      // If RPC returns single row data
      return await fetchMyProfile();
    } catch (e, stack) {
      _logger.error('Failed to upsert educator profile', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Fetches all subject associations for an educator.
  Future<List<EducatorSubject>> fetchSubjects(String educatorId) async {
    try {
      final res = await _supabase
          .from('educator_subjects')
          .select()
          .eq('educator_id', educatorId)
          .eq('status', 'active')
          .order('created_at');

      return (res as List)
          .map((row) => EducatorSubject.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.error('Failed to fetch educator subjects for $educatorId', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Adds a subject association for the current educator.
  Future<EducatorSubject?> addSubject({
    required String subjectId,
    required String subjectName,
    String? experienceSummary,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Authentication required to add subject association');
    }

    try {
      final res = await _supabase
          .from('educator_subjects')
          .insert({
            'educator_id': uid,
            'subject_id': subjectId,
            'subject_name': subjectName,
            'experience_summary': experienceSummary,
            'status': 'active',
          })
          .select()
          .single();

      return EducatorSubject.fromJson(res);
    } catch (e, stack) {
      _logger.error('Failed to add educator subject $subjectId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Removes a subject association by ID.
  Future<bool> removeSubject(String subjectAssociationId) async {
    try {
      await _supabase
          .from('educator_subjects')
          .delete()
          .eq('id', subjectAssociationId);
      return true;
    } catch (e, stack) {
      _logger.error('Failed to remove subject association $subjectAssociationId', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Fetches verification claims and credentials for an educator.
  Future<List<EducatorVerification>> fetchVerifications(String educatorId) async {
    try {
      final res = await _supabase
          .from('educator_verifications')
          .select()
          .eq('educator_id', educatorId)
          .order('created_at', ascending: false);

      return (res as List)
          .map((row) => EducatorVerification.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.error('Failed to fetch educator verifications for $educatorId', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Submits a credential or experience claim.
  Future<EducatorVerification?> submitVerificationClaim({
    required String verificationType,
    String? subjectId,
    String? jurisdiction,
    String? issuer,
    String? credentialReference,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Authentication required to submit verification claim');
    }

    try {
      final res = await _supabase
          .from('educator_verifications')
          .insert({
            'educator_id': uid,
            'verification_type': verificationType,
            'subject_id': subjectId,
            'jurisdiction': jurisdiction,
            'issuer': issuer,
            'credential_reference': credentialReference,
            'status': verificationType == 'self_declared' ? 'unverified' : 'pending',
          })
          .select()
          .single();

      return EducatorVerification.fromJson(res);
    } catch (e, stack) {
      _logger.error('Failed to submit verification claim', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Follows an educator.
  Future<bool> followEducator(String educatorId) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Authentication required to follow educator');
    }
    if (uid == educatorId) {
      throw ArgumentError('Cannot follow oneself');
    }

    try {
      await _supabase.from('educator_follows').insert({
        'follower_id': uid,
        'educator_id': educatorId,
      });
      return true;
    } catch (e, stack) {
      _logger.error('Failed to follow educator $educatorId', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Unfollows an educator.
  Future<bool> unfollowEducator(String educatorId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      await _supabase
          .from('educator_follows')
          .delete()
          .eq('follower_id', uid)
          .eq('educator_id', educatorId);
      return true;
    } catch (e, stack) {
      _logger.error('Failed to unfollow educator $educatorId', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Checks if the current user is following an educator.
  Future<bool> isFollowing(String educatorId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      final res = await _supabase
          .from('educator_follows')
          .select('id')
          .eq('follower_id', uid)
          .eq('educator_id', educatorId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// Moderator verification of a credential claim.
  Future<Map<String, dynamic>> verifyCredential({
    required String verificationId,
    required String status,
    DateTime? expiresAt,
    String? notes,
  }) async {
    try {
      final res = await _supabase.rpc(
        'verify_educator_credential',
        params: {
          'p_verification_id': verificationId,
          'p_status': status,
          if (expiresAt != null) 'p_expires_at': expiresAt.toIso8601String(),
          if (notes != null) 'p_notes': notes,
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e, stack) {
      _logger.error('Failed to verify credential $verificationId', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

