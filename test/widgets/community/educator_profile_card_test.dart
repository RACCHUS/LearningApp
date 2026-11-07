import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/widgets/community/educator_profile_card.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('EducatorProfileCard', () {
    late EducatorProfile profile;
    late List<EducatorSubject> subjects;
    late List<EducatorVerification> verifications;
    late EducatorReputation reputation;

    setUp(() {
      profile = EducatorProfile(
        id: 'edu_123',
        displayName: 'Maria Santos',
        headline: 'Licensed Cosmetologist & Safety Instructor',
        bio: 'Passionate about workforce training and Florida licensure exam preparation.',
        languages: const ['en', 'es'],
        isAcceptingQuestions: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      subjects = [
        EducatorSubject(
          id: 'sub_1',
          educatorId: 'edu_123',
          subjectId: 'fl_licensure',
          subjectName: 'Florida Licensure',
          createdAt: DateTime(2026, 1, 1),
        ),
        EducatorSubject(
          id: 'sub_2',
          educatorId: 'edu_123',
          subjectId: 'workplace_safety',
          subjectName: 'Workplace Safety',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      verifications = [
        EducatorVerification(
          id: 'ver_1',
          educatorId: 'edu_123',
          verificationType: 'licensed_credential',
          issuer: 'FL DBPR',
          jurisdiction: 'FL',
          status: 'verified',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      reputation = EducatorReputation.compute(
        educatorId: 'edu_123',
        upvotesCount: 25,
        acceptedAnswersCount: 6,
        totalAnswersCount: 8,
        verifications: verifications,
      );
    });

    testWidgets('renders educator information, badges, and subjects', (tester) async {
      await tester.pumpWidget(buildApp(EducatorProfileCard(
        profile: profile,
        subjects: subjects,
        verifications: verifications,
        reputation: reputation,
      )));

      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget); // avatar initials
      expect(find.text('Licensed Cosmetologist & Safety Instructor'), findsOneWidget);
      expect(find.textContaining('Passionate about workforce training'), findsOneWidget);

      // Subjects
      expect(find.text('Florida Licensure'), findsOneWidget);
      expect(find.text('Workplace Safety'), findsOneWidget);

      // Badges
      expect(find.text('State Licensed • FL'), findsOneWidget);
      expect(find.textContaining('Master Contributor'), findsOneWidget);
    });

    testWidgets('triggers follow and unfollow toggles', (tester) async {
      bool? toggledState;

      await tester.pumpWidget(buildApp(EducatorProfileCard(
        profile: profile,
        isFollowing: false,
        onFollowToggle: (state) => toggledState = state,
      )));

      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.byKey(const Key('follow_button_edu_123')));
      expect(toggledState, isTrue);

      // Rebuild with following = true
      await tester.pumpWidget(buildApp(EducatorProfileCard(
        profile: profile,
        isFollowing: true,
        onFollowToggle: (state) => toggledState = state,
      )));

      expect(find.text('Following'), findsOneWidget);
      await tester.tap(find.byKey(const Key('follow_button_edu_123')));
      expect(toggledState, isFalse);
    });

    testWidgets('compact mode omits bio and shows compact padding', (tester) async {
      await tester.pumpWidget(buildApp(EducatorProfileCard(
        profile: profile,
        isCompact: true,
      )));

      expect(find.text('Maria Santos'), findsOneWidget);
      // In compact mode, bio is omitted
      expect(find.textContaining('Passionate about workforce training'), findsNothing);
    });
  });
}
