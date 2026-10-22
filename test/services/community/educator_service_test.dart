import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/services/community/educator_service.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  group('ECO-04: Educator Domain Models', () {
    test('EducatorProfile serialization and state flags', () {
      final now = DateTime.utc(2026, 11, 1, 12, 0, 0);
      final profile = EducatorProfile(
        id: 'edu-001',
        displayName: 'Dr. Jane Smith',
        headline: 'Florida Certified Literacy Specialist',
        bio: 'Passionate about structured literacy and evidence-based reading interventions.',
        avatarUrl: 'https://example.com/avatar.png',
        languages: const ['en', 'es'],
        isAcceptingQuestions: true,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.isActive, isTrue);
      expect(profile.isDraft, isFalse);
      expect(profile.displayName, 'Dr. Jane Smith');
      expect(profile.languages, ['en', 'es']);

      final json = profile.toJson();
      final revived = EducatorProfile.fromJson(json);

      expect(revived.id, 'edu-001');
      expect(revived.displayName, 'Dr. Jane Smith');
      expect(revived.headline, 'Florida Certified Literacy Specialist');
      expect(revived.bio, contains('structured literacy'));
      expect(revived.avatarUrl, 'https://example.com/avatar.png');
      expect(revived.languages, ['en', 'es']);
      expect(revived.isAcceptingQuestions, isTrue);
      expect(revived.status, 'active');
      expect(revived.createdAt, now);
      expect(revived.updatedAt, now);
      expect(revived, equals(profile));
      expect(revived.hashCode, equals(profile.hashCode));
    });

    test('EducatorProfile copyWith and equality with defaults', () {
      final now = DateTime.utc(2026, 11, 1, 12, 0, 0);
      final profile = EducatorProfile(
        id: 'edu-002',
        displayName: 'Instructor Bob',
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.isDraft, isTrue);
      expect(profile.isActive, isFalse);
      expect(profile.languages, ['en']);
      expect(profile.isAcceptingQuestions, isTrue);

      final updated = profile.copyWith(
        status: 'active',
        headline: 'Cosmetology Lead Instructor',
        languages: ['en', 'fr'],
      );

      expect(updated.id, 'edu-002');
      expect(updated.status, 'active');
      expect(updated.isActive, isTrue);
      expect(updated.headline, 'Cosmetology Lead Instructor');
      expect(updated.languages, ['en', 'fr']);
      expect(updated.displayName, 'Instructor Bob');
      expect(updated, isNot(equals(profile)));
    });

    test('EducatorSubject encapsulates "Teacher does not own the subject"', () {
      final now = DateTime.utc(2026, 11, 1, 12, 0, 0);
      final subject = EducatorSubject(
        id: 'es-001',
        educatorId: 'edu-001',
        subjectId: 'target-reading-k2',
        subjectName: 'Early Reading & Phonics',
        experienceSummary: '10 years teaching primary grade phonics.',
        status: 'active',
        createdAt: now,
      );

      expect(subject.isActive, isTrue);
      expect(subject.subjectName, 'Early Reading & Phonics');

      final json = subject.toJson();
      final revived = EducatorSubject.fromJson(json);

      expect(revived.id, 'es-001');
      expect(revived.educatorId, 'edu-001');
      expect(revived.subjectId, 'target-reading-k2');
      expect(revived.subjectName, 'Early Reading & Phonics');
      expect(revived.experienceSummary, contains('10 years'));
      expect(revived.status, 'active');
      expect(revived, equals(subject));
      expect(revived.hashCode, equals(subject.hashCode));

      final inactive = subject.copyWith(status: 'inactive');
      expect(inactive.isActive, isFalse);
      expect(inactive.id, 'es-001');
      expect(inactive, isNot(equals(subject)));
    });

    test('EducatorVerification strictly distinguishes claim types', () {
      final now = DateTime.utc(2026, 11, 1, 12, 0, 0);
      final claim = EducatorVerification(
        id: 'ev-001',
        educatorId: 'edu-001',
        verificationType: 'licensed_credential',
        subjectId: 'licensure.cosmetology',
        jurisdiction: 'US-FL',
        issuer: 'Florida DBPR',
        credentialReference: 'CL1234567',
        status: 'verified',
        verifiedAt: now,
        expiresAt: now.add(const Duration(days: 365)),
        createdAt: now,
        updatedAt: now,
      );

      expect(claim.isLicensed, isTrue);
      expect(claim.isPlatformVetted, isFalse);
      expect(claim.isSelfDeclared, isFalse);
      expect(claim.isVerified, isTrue);
      expect(claim.isPending, isFalse);

      final json = claim.toJson();
      final revived = EducatorVerification.fromJson(json);

      expect(revived.id, 'ev-001');
      expect(revived.jurisdiction, 'US-FL');
      expect(revived.issuer, 'Florida DBPR');
      expect(revived.credentialReference, 'CL1234567');
      expect(revived.isVerified, isTrue);
      expect(revived.verifiedAt, now);
      expect(revived, equals(claim));
      expect(revived.hashCode, equals(claim.hashCode));

      final selfClaim = claim.copyWith(
        verificationType: 'self_declared',
        status: 'unverified',
        issuer: null,
      );
      expect(selfClaim.isSelfDeclared, isTrue);
      expect(selfClaim.isLicensed, isFalse);
      expect(selfClaim.isVerified, isFalse);
    });
  });

  group('ECO-04: EducatorService Tests', () {
    late FakeSupabaseClient fakeClient;
    late EducatorService service;

    final testUser = User(
      id: 'usr-edu-42',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

    setUp(() {
      fakeClient = FakeSupabaseClient();
      service = EducatorService(supabase: fakeClient);
    });

    test('currentUserId returns null when unauthenticated', () {
      fakeClient.auth.currentUser = null;
      expect(service.currentUserId, isNull);
    });

    test('currentUserId returns user id when authenticated', () {
      fakeClient.auth.currentUser = testUser;
      expect(service.currentUserId, 'usr-edu-42');
    });

    test('fetchMyProfile returns null when unauthenticated without database query', () async {
      fakeClient.auth.currentUser = null;
      final profile = await service.fetchMyProfile();
      expect(profile, isNull);
    });

    test('fetchProfile returns EducatorProfile on found record', () async {
      fakeClient.setTableData('educator_profiles', [
        {
          'id': 'usr-edu-42',
          'display_name': 'Prof. Charles Xavier',
          'headline': 'Dean of Genetics',
          'bio': 'Pioneer in mutant genetics and developmental psychology.',
          'avatar_url': null,
          'languages': ['en'],
          'is_accepting_questions': true,
          'status': 'active',
          'created_at': '2026-11-01T12:00:00Z',
          'updated_at': '2026-11-01T12:00:00Z',
        },
      ]);

      final profile = await service.fetchProfile('usr-edu-42');
      expect(profile, isNotNull);
      expect(profile!.id, 'usr-edu-42');
      expect(profile.displayName, 'Prof. Charles Xavier');
      expect(profile.isActive, isTrue);
    });

    test('fetchProfile returns null when record not found', () async {
      fakeClient.setTableData('educator_profiles', []);
      final profile = await service.fetchProfile('nonexistent-id');
      expect(profile, isNull);
    });

    test('upsertMyProfile invokes hardened RPC with expected parameters', () async {
      final returnedData = {
        'id': 'usr-edu-42',
        'display_name': 'Dr. Jean Grey',
        'headline': 'Cognitive Science Lead',
        'bio': 'Specialist in mind-brain interactions.',
        'avatar_url': 'https://example.com/jg.jpg',
        'languages': ['en', 'fr'],
        'is_accepting_questions': true,
        'status': 'active',
        'created_at': '2026-11-01T12:00:00Z',
        'updated_at': '2026-11-01T12:00:00Z',
      };

      String? capturedFn;
      Map<String, dynamic>? capturedParams;

      fakeClient.rpcHandler = (fn, {params}) {
        capturedFn = fn;
        capturedParams = params;
        return returnedData;
      };

      final profile = await service.upsertMyProfile(
        displayName: 'Dr. Jean Grey',
        headline: 'Cognitive Science Lead',
        bio: 'Specialist in mind-brain interactions.',
        avatarUrl: 'https://example.com/jg.jpg',
        languages: ['en', 'fr'],
        isAcceptingQuestions: true,
        status: 'active',
      );

      expect(capturedFn, 'upsert_my_educator_profile');
      expect(capturedParams?['p_display_name'], 'Dr. Jean Grey');
      expect(capturedParams?['p_headline'], 'Cognitive Science Lead');
      expect(capturedParams?['p_languages'], ['en', 'fr']);
      expect(capturedParams?['p_status'], 'active');

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Dr. Jean Grey');
      expect(profile.languages, ['en', 'fr']);
      expect(profile.isActive, isTrue);
    });

    test('fetchSubjects retrieves active subject associations', () async {
      fakeClient.setTableData('educator_subjects', [
        {
          'id': 'es-001',
          'educator_id': 'usr-edu-42',
          'subject_id': 'genetics-101',
          'subject_name': 'Genetics & Heredity',
          'experience_summary': '15 years research.',
          'status': 'active',
          'created_at': '2026-11-01T12:00:00Z',
        },
      ]);

      final subjects = await service.fetchSubjects('usr-edu-42');
      expect(subjects.length, 1);
      expect(subjects.first.subjectId, 'genetics-101');
      expect(subjects.first.subjectName, 'Genetics & Heredity');
    });

    test('addSubject enforces authentication and inserts record', () async {
      fakeClient.auth.currentUser = testUser;

      final result = await service.addSubject(
        subjectId: 'sub-ethics',
        subjectName: 'Bioethics',
        experienceSummary: 'Ethics board advisor.',
      );

      expect(result, isNotNull);
      expect(result!.subjectId, 'sub-ethics');
      expect(result.subjectName, 'Bioethics');
      expect(result.experienceSummary, 'Ethics board advisor.');
      expect(fakeClient.insertedRecords.length, 1);
      expect(fakeClient.insertedRecords.first['educator_id'], 'usr-edu-42');
    });

    test('addSubject throws StateError when unauthenticated', () async {
      fakeClient.auth.currentUser = null;

      expect(
        () => service.addSubject(subjectId: 'sub-ethics', subjectName: 'Bioethics'),
        throwsA(isA<StateError>()),
      );
    });

    test('removeSubject deletes subject association by ID', () async {
      fakeClient.setTableData('educator_subjects', [
        {
          'id': 'es-remove-1',
          'educator_id': 'usr-edu-42',
          'subject_id': 'sub-ethics',
          'subject_name': 'Bioethics',
          'status': 'active',
        },
      ]);

      final success = await service.removeSubject('es-remove-1');
      expect(success, isTrue);
      expect(fakeClient.deletedIds.contains('es-remove-1'), isTrue);
    });

    test('fetchVerifications retrieves credential claims ordered by created_at', () async {
      fakeClient.setTableData('educator_verifications', [
        {
          'id': 'ev-001',
          'educator_id': 'usr-edu-42',
          'verification_type': 'licensed_credential',
          'subject_id': 'licensure.med',
          'jurisdiction': 'US-FL',
          'issuer': 'FL Board of Medicine',
          'credential_reference': 'ME123456',
          'status': 'verified',
          'verified_at': '2026-11-01T12:00:00Z',
          'expires_at': '2027-11-01T12:00:00Z',
          'created_at': '2026-11-01T12:00:00Z',
          'updated_at': '2026-11-01T12:00:00Z',
        },
      ]);

      final verifications = await service.fetchVerifications('usr-edu-42');
      expect(verifications.length, 1);
      expect(verifications.first.verificationType, 'licensed_credential');
      expect(verifications.first.issuer, 'FL Board of Medicine');
      expect(verifications.first.isVerified, isTrue);
    });

    test('submitVerificationClaim assigns default unverified status to self-declared claims', () async {
      fakeClient.auth.currentUser = testUser;

      final claim = await service.submitVerificationClaim(
        verificationType: 'self_declared',
        subjectId: 'math-101',
        credentialReference: 'Self-taught calculus tutor for 3 years',
      );

      expect(claim, isNotNull);
      expect(claim!.status, 'unverified');
      expect(claim.isSelfDeclared, isTrue);
      expect(claim.credentialReference, 'Self-taught calculus tutor for 3 years');
      expect(fakeClient.insertedRecords.first['status'], 'unverified');
    });

    test('submitVerificationClaim assigns default pending status to licensed credentials', () async {
      fakeClient.auth.currentUser = testUser;

      final claim = await service.submitVerificationClaim(
        verificationType: 'licensed_credential',
        jurisdiction: 'US-FL',
        issuer: 'Florida DBPR',
        credentialReference: 'CL9876543',
      );

      expect(claim, isNotNull);
      expect(claim!.status, 'pending');
      expect(claim.isLicensed, isTrue);
      expect(fakeClient.insertedRecords.first['status'], 'pending');
    });

    test('followEducator prevents following oneself', () async {
      fakeClient.auth.currentUser = testUser;

      expect(
        () => service.followEducator('usr-edu-42'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('followEducator succeeds for other educators', () async {
      fakeClient.auth.currentUser = testUser;

      final success = await service.followEducator('other-educator-99');
      expect(success, isTrue);
      expect(fakeClient.insertedRecords.length, 1);
      expect(fakeClient.insertedRecords.first['follower_id'], 'usr-edu-42');
      expect(fakeClient.insertedRecords.first['educator_id'], 'other-educator-99');
    });

    test('unfollowEducator deletes follow relation', () async {
      fakeClient.auth.currentUser = testUser;

      final success = await service.unfollowEducator('other-educator-99');
      expect(success, isTrue);
    });

    test('unfollowEducator returns false when unauthenticated', () async {
      fakeClient.auth.currentUser = null;
      final success = await service.unfollowEducator('other-educator-99');
      expect(success, isFalse);
    });

    test('isFollowing returns true when follow relation exists', () async {
      fakeClient.auth.currentUser = testUser;
      fakeClient.setTableData('educator_follows', [
        {
          'id': 'fol-101',
          'follower_id': 'usr-edu-42',
          'educator_id': 'other-educator-99',
        },
      ]);

      final following = await service.isFollowing('other-educator-99');
      expect(following, isTrue);
    });

    test('isFollowing returns false when unauthenticated', () async {
      fakeClient.auth.currentUser = null;
      final following = await service.isFollowing('other-educator-99');
      expect(following, isFalse);
    });
  });
}
