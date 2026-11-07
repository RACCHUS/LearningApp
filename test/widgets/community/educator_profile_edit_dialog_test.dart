import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/services/community/educator_service.dart';
import 'package:learning_pwa/widgets/community/educator_profile_edit_dialog.dart';

class _FakeEducatorService extends EducatorService {
  String? upsertedDisplayName;
  String? upsertedHeadline;
  String? upsertedBio;
  bool? upsertedAcceptingQuestions;
  final List<String> addedSubjectIds = [];
  String? submittedClaimType;
  String? submittedIssuer;

  @override
  String? get currentUserId => 'mock_user_1';

  @override
  Future<EducatorProfile?> upsertMyProfile({
    required String displayName,
    String? headline,
    String? bio,
    String? avatarUrl,
    List<String> languages = const ['en'],
    bool isAcceptingQuestions = true,
    String status = 'draft',
  }) async {
    upsertedDisplayName = displayName;
    upsertedHeadline = headline;
    upsertedBio = bio;
    upsertedAcceptingQuestions = isAcceptingQuestions;

    return EducatorProfile(
      id: 'mock_user_1',
      displayName: displayName,
      headline: headline,
      bio: bio,
      avatarUrl: avatarUrl,
      languages: languages,
      isAcceptingQuestions: isAcceptingQuestions,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<EducatorSubject?> addSubject({
    required String subjectId,
    required String subjectName,
    String? experienceSummary,
  }) async {
    addedSubjectIds.add(subjectId);
    return EducatorSubject(
      id: 'sub_$subjectId',
      educatorId: 'mock_user_1',
      subjectId: subjectId,
      subjectName: subjectName,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<EducatorVerification?> submitVerificationClaim({
    required String verificationType,
    String? subjectId,
    String? jurisdiction,
    String? issuer,
    String? credentialReference,
  }) async {
    submittedClaimType = verificationType;
    submittedIssuer = issuer;
    return EducatorVerification(
      id: 'ver_claim_1',
      educatorId: 'mock_user_1',
      verificationType: verificationType,
      issuer: issuer,
      jurisdiction: jurisdiction,
      credentialReference: credentialReference,
      status: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('EducatorProfileEditDialog', () {
    late _FakeEducatorService fakeService;

    setUp(() {
      fakeService = _FakeEducatorService();
    });

    testWidgets('loads initial profile data into form fields', (tester) async {
      final initialProfile = EducatorProfile(
        id: 'mock_user_1',
        displayName: 'James Taylor',
        headline: 'Florida Licensure Expert',
        bio: 'Over 15 years in Florida exam prep and career training.',
        isAcceptingQuestions: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final initialSubjects = [
        EducatorSubject(
          id: 'sub_fl',
          educatorId: 'mock_user_1',
          subjectId: 'fl_licensure',
          subjectName: 'Florida Licensure',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildApp(EducatorProfileEditDialog(
        initialProfile: initialProfile,
        initialSubjects: initialSubjects,
        service: fakeService,
      )));

      expect(find.text('James Taylor'), findsOneWidget);
      expect(find.text('Florida Licensure Expert'), findsOneWidget);
      expect(find.textContaining('Over 15 years in Florida exam prep'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('validates required display name length', (tester) async {
      await tester.pumpWidget(buildApp(EducatorProfileEditDialog(
        service: fakeService,
      )));

      // Enter single character
      await tester.enterText(find.byKey(const Key('educator_display_name_field')), 'A');
      await tester.tap(find.byKey(const Key('save_educator_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Display name must be at least 2 characters'), findsOneWidget);
      expect(fakeService.upsertedDisplayName, isNull);
    });

    testWidgets('saves updated profile and adds new subjects', (tester) async {
      bool onSavedCalled = false;

      await tester.pumpWidget(buildApp(EducatorProfileEditDialog(
        service: fakeService,
        onSaved: () => onSavedCalled = true,
      )));

      // Fill in valid details
      await tester.enterText(find.byKey(const Key('educator_display_name_field')), 'Dr. Brenda Vance');
      await tester.enterText(find.byKey(const Key('educator_headline_field')), 'Workplace Safety Specialist');
      await tester.enterText(find.byKey(const Key('educator_bio_field')), 'Certified trainer specializing in OSHA compliance.');

      // Select workplace_safety chip
      await tester.ensureVisible(find.text('Workplace Safety & OSHA Compliance'));
      await tester.tap(find.text('Workplace Safety & OSHA Compliance'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('save_educator_profile_button')));
      await tester.pumpAndSettle();

      expect(fakeService.upsertedDisplayName, 'Dr. Brenda Vance');
      expect(fakeService.upsertedHeadline, 'Workplace Safety Specialist');
      expect(fakeService.upsertedBio, 'Certified trainer specializing in OSHA compliance.');
      expect(fakeService.addedSubjectIds, contains('workplace_safety'));
      expect(onSavedCalled, isTrue);
    });
  });
}
