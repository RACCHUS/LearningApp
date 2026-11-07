import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/services/community/educator_service.dart';
import 'package:learning_pwa/services/community/educator_reputation_service.dart';
import 'package:learning_pwa/screens/community/educator_profile_screen.dart';

class _MockEducatorService extends EducatorService {
  final EducatorProfile profile;
  final List<EducatorSubject> subjects;
  final List<EducatorVerification> verifications;
  bool isFollowingResult = false;
  bool followCalled = false;
  bool unfollowCalled = false;
  final String? mockUserId;

  _MockEducatorService({
    required this.profile,
    required this.subjects,
    required this.verifications,
    this.mockUserId = 'viewer_user',
  });

  @override
  String? get currentUserId => mockUserId;

  @override
  Future<EducatorProfile?> fetchProfile(String educatorId) async => profile;

  @override
  Future<List<EducatorSubject>> fetchSubjects(String educatorId) async => subjects;

  @override
  Future<List<EducatorVerification>> fetchPublicVerifications(String educatorId) async => verifications;

  @override
  Future<List<EducatorVerification>> fetchVerifications(String educatorId) async => verifications;

  @override
  Future<bool> isFollowing(String educatorId) async => isFollowingResult;

  @override
  Future<bool> followEducator(String educatorId) async {
    followCalled = true;
    isFollowingResult = true;
    return true;
  }

  @override
  Future<bool> unfollowEducator(String educatorId) async {
    unfollowCalled = true;
    isFollowingResult = false;
    return true;
  }
}

class _MockReputationService extends EducatorReputationService {
  final EducatorReputation reputation;

  _MockReputationService({required this.reputation});

  @override
  Future<EducatorReputation> fetchReputation(String educatorId) async => reputation;
}

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('EducatorProfileScreen', () {
    late EducatorProfile profile;
    late List<EducatorSubject> subjects;
    late List<EducatorVerification> verifications;
    late EducatorReputation reputation;
    late _MockEducatorService educatorService;
    late _MockReputationService reputationService;

    setUp(() {
      profile = EducatorProfile(
        id: 'edu_555',
        displayName: 'Arthur Pendelton',
        headline: 'Master Electrician & ABE Instructor',
        bio: 'Providing vocational literacy and technical training for adult learners.',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      subjects = [
        EducatorSubject(
          id: 'sub_elec',
          educatorId: 'edu_555',
          subjectId: 'workplace_safety',
          subjectName: 'Electrical Safety',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      verifications = [
        EducatorVerification(
          id: 'ver_licensed',
          educatorId: 'edu_555',
          verificationType: 'licensed_credential',
          issuer: 'Florida Electrical Contractors Licensing Board',
          jurisdiction: 'FL',
          status: 'verified',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      reputation = EducatorReputation.compute(
        educatorId: 'edu_555',
        upvotesCount: 30,
        acceptedAnswersCount: 12,
        totalAnswersCount: 14,
        verifications: verifications,
      );

      educatorService = _MockEducatorService(
        profile: profile,
        subjects: subjects,
        verifications: verifications,
      );

      reputationService = _MockReputationService(reputation: reputation);
    });

    testWidgets('renders full educator profile, credentials, and reputation breakdown', (tester) async {
      await tester.pumpWidget(buildApp(EducatorProfileScreen(
        educatorId: 'edu_555',
        service: educatorService,
        reputationService: reputationService,
      )));

      await tester.pumpAndSettle();

      // Top card info
      expect(find.text('Arthur Pendelton'), findsAtLeast(1));
      expect(find.text('Master Electrician & ABE Instructor'), findsOneWidget);
      expect(find.textContaining('Providing vocational literacy'), findsOneWidget);
      expect(find.text('Electrical Safety'), findsOneWidget);

      // Verified credentials section
      expect(find.text('Verified Credentials & Experience'), findsOneWidget);
      expect(find.text('Florida Electrical Contractors Licensing Board'), findsOneWidget);

      // Reputation metrics
      expect(find.text('Contributor Evidence & Reputation'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // accepted answers
      expect(find.text('30'), findsOneWidget); // upvotes
      expect(find.textContaining('Master Contributor'), findsAtLeast(1));
    });

    testWidgets('toggles follow status', (tester) async {
      await tester.pumpWidget(buildApp(EducatorProfileScreen(
        educatorId: 'edu_555',
        service: educatorService,
        reputationService: reputationService,
      )));

      await tester.pumpAndSettle();

      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      expect(educatorService.followCalled, isTrue);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('shows edit button when current user is profile owner', (tester) async {
      final ownerService = _MockEducatorService(
        profile: profile,
        subjects: subjects,
        verifications: verifications,
        mockUserId: 'edu_555', // same as educatorId
      );

      await tester.pumpWidget(buildApp(EducatorProfileScreen(
        educatorId: 'edu_555',
        service: ownerService,
        reputationService: reputationService,
      )));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_profile_icon_button')), findsOneWidget);
    });
  });
}

